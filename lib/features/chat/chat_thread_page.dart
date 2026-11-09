import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart'
    show
        CupertinoActionSheet,
        CupertinoActionSheetAction,
        showCupertinoModalPopup;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fading_header_scaffold.dart';
import '../auth/widgets/logo_stroke_loader.dart';
import 'chat_api.dart';
import 'chat_glass.dart';
import 'chat_group_page.dart';
import 'chat_models.dart';
import 'chat_system.dart';
import 'chat_profile_page.dart';
import 'chat_socket.dart';
import 'chat_sounds.dart';
import 'chat_thread_controller.dart';
import 'chat_appearance_settings.dart';
import 'chat_attach.dart';
import 'chat_attach_android.dart';
import 'chat_media.dart';
import 'chat_mute_sheet.dart';
import 'chat_media_grid.dart';
import 'chat_media_preview.dart';
import 'chat_media_viewers.dart';
import 'chat_media_widgets.dart';
import 'chat_voice.dart';
import 'chat_voice_list.dart';
import 'chat_voice_widgets.dart';
import 'chat_widgets.dart';

/// A route without a transition: chat screens open and close at once, as in
/// Telegram.
Route<void> chatInstantRoute(WidgetBuilder builder) => PageRouteBuilder<void>(
  transitionDuration: Duration.zero,
  reverseTransitionDuration: Duration.zero,
  pageBuilder: (context, _, _) => builder(context),
);

/// A conversation with one person: messages (live), the input, "typing…".
///
/// It opens at once, also from a contact: the chat is opened on the server in
/// the background, and a message can be sent before that has finished.
class ChatThreadPage extends StatefulWidget {
  const ChatThreadPage({
    super.key,
    required this.api,
    required this.link,
    required this.peer,
    this.conversationId,
    this.sounds,
    this.onRead,
    this.mutedChats,
    this.isGroup = false,
  });

  /// The chat is a group: [peer] stands in for it ([ChatUser.groupStandIn]).
  final bool isGroup;

  final ChatRest api;
  final ChatLink link;
  final ChatUser peer;

  /// Known when opened from the chat list; null from the contacts.
  final int? conversationId;

  /// "Message sent" sound.
  final ChatSounds? sounds;

  /// Shared with the hub: ids of chats with notifications off.
  final Set<int>? mutedChats;

  /// The peer's messages were marked read (the unread total may have changed).
  final VoidCallback? onRead;

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  late final ChatThreadController _c = ChatThreadController(
    rest: widget.api,
    link: widget.link,
    peer: widget.peer,
    conversationId: widget.conversationId,
    onReadMarked: widget.onRead,
    isGroup: widget.isGroup,
  );
  bool _closing = false;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _hasText = false;

  /// "Go to message" (from the voice list of a profile): the message to scroll
  /// to, and the one flashing after the jump.
  int? _jumpId;
  bool _flash = false;
  final _jumpKey = GlobalKey();
  final _spy = _TouchSpy();
  final Map<String, GlobalKey> _albumKeys = {};

  /// The message being edited (the input holds its text), if any.
  ChatMessage? _editing;

  /// The message being answered (swipe or menu), if any.
  ChatMessage? _replying;

  /// The input bar floats over the messages (they scroll under its glass, as
  /// under the header), so the list needs to know how tall the bar is: it grows
  /// with the text.
  final _inputKey = GlobalKey();
  double _inputHeight = 76;

  void _measureInput() {
    final box = _inputKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final h = box.size.height;
    if ((h - _inputHeight).abs() > 0.5 && mounted) {
      setState(() => _inputHeight = h);
    }
  }

  @override
  void initState() {
    super.initState();
    ChatVoicePlayer.instance.nextResolver = _nextVoice;
    ChatAppearanceSettings.instance
      ..load()
      ..addListener(_appearanceChanged);
    ChatOpenThreads.add(_c);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureInput());
    _c.start();
    _scroll.addListener(() {
      // Reverse list: the "top" of the history is the max scroll extent.
      if (_scroll.hasClients &&
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        _c.loadMore();
      }
    });
    _input.addListener(() {
      if (_editing == null)
        _c.onTextChanged(_input.text); // no "typing…" while editing
      final has = _input.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  /// The next voice message after [m] in this chat (newer, in order), if any:
  /// it plays by itself when [m] has been heard to the end.
  ChatMessage? _nextVoice(ChatMessage m) {
    final all = _c.messages; // oldest first
    final key = ChatVoicePlayer.keyOf(m);
    final at = all.indexWhere((x) => ChatVoicePlayer.keyOf(x) == key);
    if (at < 0) return null;
    for (var i = at + 1; i < all.length; i++) {
      final x = all[i];
      if (x.isVoice && x.state != ChatSendState.failed) return x;
    }
    return null;
  }

  void _appearanceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ChatAppearanceSettings.instance.removeListener(_appearanceChanged);
    if (ChatVoicePlayer.instance.nextResolver == _nextVoice) {
      ChatVoicePlayer.instance.nextResolver = null;
    }
    ChatVoicePlayer.instance.stop(); // leaving the chat stops the voice
    ChatOpenThreads.remove(_c);
    _c.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _startEdit(ChatMessage m) {
    setState(() => _editing = m);
    _input.value = TextEditingValue(
      text: m.text,
      selection: TextSelection.collapsed(offset: m.text.length),
    );
  }

  void _cancelEdit() {
    final wasEditing = _editing != null;
    setState(() {
      _editing = null;
      _replying = null;
    });
    // Cancelling a reply keeps what was typed; cancelling an edit drops it.
    if (wasEditing) _input.clear();
  }

  void _startReply(ChatMessage m) {
    if (m.isLocal || m.state != ChatSendState.sent) return;
    setState(() {
      _editing = null;
      _replying = m;
    });
  }

  String _authorOf(int senderId, S s) {
    if (widget.isGroup) {
      if (senderId == widget.api.myId) return s.chatYou;
      return _c.names[senderId] ?? s.chatMemberFallback;
    }
    return senderId == widget.peer.id ? widget.peer.shortName : s.chatYou;
  }

  /// What sits under the name: connecting / who is typing / how many members
  /// (a group), or connecting / typing / online / last seen (a person).
  String _statusLine(S s) {
    if (!widget.link.connected.value) return s.chatConnecting;
    if (_c.syncing) return s.chatUpdating;
    if (widget.isGroup) {
      if (_c.peerTyping) {
        return s.chatTypingNames([
          for (final id in _c.typingIds)
            _shortOf(_c.names[id] ?? s.chatMemberFallback),
        ]);
      }
      final n = _c.group?.membersCount ?? 0;
      return n > 0 ? s.chatMembersCount(n) : '';
    }
    return _c.peerTyping
        ? s.chatTyping
        : _c.peerOnline
        ? s.chatOnline
        : s.chatLastSeen(_c.peerLastSeen);
  }

  /// "Surname N." of a full name, for a short line.
  static String _shortOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.length < 2 ? name.trim() : '${parts[0]} ${parts[1][0]}.';
  }

  Future<void> _saveEdit() async {
    final m = _editing;
    if (m == null) return;
    final text = _input.text;
    if (text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _editing = null);
    _input.clear();
    await _c.editMessage(m, text);
  }

  /// Long press on a bubble: a native popup menu with icons. "Delete" opens
  /// a second menu with the choice (for me / for everyone).
  List<AdaptivePopupMenuEntry> _menuFor(ChatMessage m, bool mine, S s) {
    final ios26 = PlatformInfo.isIOS26OrHigher();
    final stored = !m.isLocal && m.state == ChatSendState.sent;
    // A message that could not be sent can only be thrown away.
    if (m.isLocal && m.state == ChatSendState.failed) {
      return [
        AdaptivePopupMenuItem<_MsgAction>(
          label: s.chatMenuDelete,
          icon: ios26 ? 'trash' : Icons.delete_outline_rounded,
          isDestructive: true,
          value: _MsgAction.discard,
        ),
      ];
    }
    return [
      if (stored)
        AdaptivePopupMenuItem<_MsgAction>(
          label: s.chatMenuReply,
          icon: ios26 ? 'arrowshape.turn.up.left' : Icons.reply_rounded,
          value: _MsgAction.reply,
        ),
      if (!m.isVoice)
        AdaptivePopupMenuItem<_MsgAction>(
          label: s.chatMenuCopy,
          icon: ios26 ? 'doc.on.doc' : Icons.copy_rounded,
          value: _MsgAction.copy,
        ),
      if (mine && stored && !m.isVoice)
        AdaptivePopupMenuItem<_MsgAction>(
          label: s.chatMenuEdit,
          icon: ios26 ? 'pencil' : Icons.edit_rounded,
          value: _MsgAction.edit,
        ),
      if (stored)
        AdaptivePopupMenuItem<_MsgAction>(
          label: s.chatMenuDelete,
          icon: ios26 ? 'trash' : Icons.delete_outline_rounded,
          isDestructive: true,
          children: [
            AdaptivePopupMenuItem<_MsgAction>(
              label: s.chatMenuDeleteForMe,
              icon: ios26 ? 'person' : Icons.person_outline_rounded,
              isDestructive: true,
              value: _MsgAction.deleteForMe,
            ),
            // In a group "for everybody" is for the author and the admins.
            if (!widget.isGroup || mine || _c.isAdmin)
              AdaptivePopupMenuItem<_MsgAction>(
                label: s.chatMenuDeleteForAll,
                icon: ios26 ? 'person.2' : Icons.people_outline_rounded,
                isDestructive: true,
                value: _MsgAction.deleteForAll,
              ),
          ],
        ),
    ];
  }

  /// A tap on an album: which tile it fell on is worked out from the touch.
  void _openAlbumAt(List<ChatMessage> album) {
    final key = _albumKeys['${album.first.albumId}:${album.first.id}'];
    final box = key?.currentContext?.findRenderObject();
    final point = _spy.last;
    if (box is! RenderBox || !box.hasSize || point == null) return;
    final i = AlbumLayout.tileAt(
      box.size.width,
      album.length,
      box.globalToLocal(point),
    );
    if (i != null) _openMedia(album[i]);
  }

  void _onMenu(
    ChatMessage m,
    _MsgAction? action, {
    List<ChatMessage> album = const [],
  }) {
    // An album is one bubble: deleting it deletes all its photos.
    final all = album.isEmpty ? [m] : album;
    switch (action) {
      case _MsgAction.reply:
        _startReply(m);
      case _MsgAction.copy:
        Clipboard.setData(
          ClipboardData(
            text: all
                .firstWhere((x) => x.text.isNotEmpty, orElse: () => m)
                .text,
          ),
        );
        HapticFeedback.selectionClick();
      case _MsgAction.edit:
        _startEdit(m);
      case _MsgAction.discard:
        for (final x in all) {
          _c.discardLocal(x);
        }
      case _MsgAction.deleteForMe:
        for (final x in all) {
          _c.deleteMessage(x, forAll: false);
        }
      case _MsgAction.deleteForAll:
        for (final x in all) {
          _c.deleteMessage(x, forAll: true);
        }
      case null:
        break;
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
      );
  }

  /// The paperclip: a sheet with where the file comes from, then the picked
  /// photos / videos / documents are shrunk (a spinner meanwhile) and sent.
  Future<void> _attach() async {
    final s = S.of(context);
    HapticFeedback.selectionClick();

    // iOS: the native sheet, as in Telegram (it prepares the files itself).
    AttachResult? result;
    if (Platform.isIOS) {
      result = await ChatAttach.nativeSheet({
        'recents': s.chatRecents,
        'gallery': s.chatGalleryTab,
        'camera': s.chatCameraTab,
        'file': s.chatAttachFile,
        'send': s.chatSendMedia,
        'preparing': s.chatPreparing,
        'caption': s.chatCaptionHint,
        'denied': s.chatPhotosDenied,
        'settings': s.chatOpenSettings,
      });
      if (!mounted) return;
    }
    // Elsewhere (or no native sheet): a menu, then the pickers, and a preview
    // with captions (the native sheet has its own).
    final native = result != null;
    result ??= await _attachViaMenu(s);
    if (result == null || !mounted) return;
    var uploads = result.ready;
    if (!native && uploads.any((u) => u.kind != 'file')) {
      final files = uploads.where((u) => u.kind == 'file').toList();
      final media = uploads.where((u) => u.kind != 'file').toList();
      final edited = await Navigator.of(context).push<List<ChatUpload>>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => MediaPreviewPage(uploads: media),
        ),
      );
      if (edited == null || !mounted) return;
      uploads = [...edited, ...files];
    }

    if (result.problems.isNotEmpty) {
      final p = result.problems.first;
      _snack(
        p == AttachProblem.tooLarge
            ? s.chatAttachTooLarge
            : p == AttachProblem.badType
            ? s.chatAttachBadType
            : s.chatAttachFailed,
      );
    }
    if (uploads.isEmpty) return;
    HapticFeedback.lightImpact();
    widget.sounds?.sent();
    // Several photos / videos sent together are one album in the chat.
    final mediaCount = uploads.where((u) => u.kind != 'file').length;
    if (mediaCount >= 2) {
      final id = 'a${DateTime.now().microsecondsSinceEpoch}';
      uploads = [for (final u in uploads) u.kind == 'file' ? u : u.inAlbum(id)];
    }
    final reply = _replying;
    for (var i = 0; i < uploads.length; i++) {
      // Only the first of several carries the quote of an answer.
      _c.sendMedia(uploads[i], replyTo: i == 0 ? reply : null);
    }
    if (reply != null) setState(() => _replying = null);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Future<AttachResult?> _attachViaMenu(S s) async {
    // Android: the Telegram-style sheet (recent photos grid + sources).
    int? androidChoice;
    List<String>? androidPaths;
    if (Platform.isAndroid) {
      final picked = await showAttachSheetAndroid(context);
      if (picked == null || !mounted) return null;
      if (picked.action != null) {
        androidChoice = switch (picked.action!) {
          AttachAction.gallery => 0,
          AttachAction.camera => 1,
          AttachAction.video => 2,
          AttachAction.file => 3,
        };
      } else {
        androidPaths = picked.paths;
      }
    }
    final choice = Platform.isAndroid
        ? (androidChoice ?? -1)
        : await showCupertinoModalPopup<int>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 0),
            child: Text(s.chatAttachGallery),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 1),
            child: Text(s.chatAttachCamera),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 2),
            child: Text(s.chatAttachVideoCamera),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 3),
            child: Text(s.chatAttachFile),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: Text(s.chatCancel),
        ),
      ),
    );
    if (choice == null || !mounted) return null;

    var busy = false;
    void showBusy() {
      if (!mounted || busy) return;
      busy = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black38,
        useRootNavigator: true,
        builder: (_) => PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    s.chatPreparing,
                    style: const TextStyle(
                      fontSize: 15,
                      color: kChatInk,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final AttachResult result;
    switch (choice) {
      case -1:
        result = await ChatAttach.fromPaths(
          androidPaths ?? const [],
          onPicked: showBusy,
        );
      case 0:
        result = await ChatAttach.gallery(onPicked: showBusy);
      case 1:
        result = await ChatAttach.cameraPhoto(onPicked: showBusy);
      case 2:
        result = await ChatAttach.cameraVideo(onPicked: showBusy);
      default:
        result = await ChatAttach.files(onPicked: showBusy);
    }
    if (busy && mounted) Navigator.of(context, rootNavigator: true).pop();
    if (!mounted) return null;
    return result;
  }

  /// Who sent a photo / video, for the viewer's header: "You" for mine, else
  /// the person's "Surname Name" (in a group: the member's).
  String _senderLabel(ChatMessage m, S s) {
    if (_c.isMine(m)) return s.chatYou;
    if (widget.isGroup) {
      final full =
          _c.names[m.sender] ??
          (m.senderName.isNotEmpty ? m.senderName : s.chatMemberFallback);
      // "Surname Name" without the patronymic, as in the lists.
      return full.trim().split(RegExp(r'\s+')).take(2).join(' ');
    }
    return widget.peer.surnameName;
  }

  /// "08.11.2026 11:00": when it was sent, under the name in the viewer.
  String _sentAtLabel(ChatMessage m) {
    String two(int v) => v.toString().padLeft(2, '0');
    final t = m.createdAt;
    return '${two(t.day)}.${two(t.month)}.${t.year} ${two(t.hour)}:${two(t.minute)}';
  }

  /// A tap on a photo / video / document: opens it (fetching it first when it
  /// is not on this phone yet).
  Future<void> _openMedia(ChatMessage m) async {
    final s = S.of(context);
    final manager = ChatMediaManager.instance;
    await ChatMediaStore.init();
    final file = ChatMediaStore.fileOf(m);
    if (file == null) return;
    // A tap on the ring of a file that is going up / down stops it.
    if (manager.progressOf(m) != null) {
      HapticFeedback.selectionClick();
      if (m.isLocal) {
        _c.cancelUpload(m);
      } else {
        manager.cancelDownload(m);
      }
      return;
    }
    if (!file.existsSync()) {
      if (m.isLocal) return;
      final ok = await manager.download(m, widget.api);
      if (!ok) {
        if (mounted) {
          _snack(manager.isGone(m) ? s.chatFileGone : s.chatDownloadFailed);
        }
        return;
      }
    }
    if (!mounted) return;
    HapticFeedback.selectionClick();
    if (m.isImage) {
      if (Platform.isIOS) {
        try {
          await const MethodChannel(
            'uztexpro/native_sheet',
          ).invokeMethod('photoViewer', {
            'url': Uri.file(file.path).toString(),
            'title': _senderLabel(m, s),
            'subtitle': _sentAtLabel(m),
          });
          return;
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PhotoViewerPage(
            file: file,
            title: _senderLabel(m, s),
            subtitle: _sentAtLabel(m),
          ),
        ),
      );
    } else if (m.isVideo) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => VideoViewerPage(
            file: file,
            title: _senderLabel(m, s),
            subtitle: _sentAtLabel(m),
          ),
        ),
      );
    } else {
      await OpenFilex.open(file.path);
    }
  }

  void _sendVoice(VoiceClip clip) {
    HapticFeedback.lightImpact();
    widget.sounds?.sent();
    _c.sendVoice(clip.path, clip.durationMs, clip.waveform, replyTo: _replying);
    if (_replying != null) setState(() => _replying = null);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _send() {
    if (_editing != null) {
      _saveEdit();
      return;
    }
    final text = _input.text;
    if (text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    widget.sounds?.sent();
    _c.send(text, replyTo: _replying);
    if (_replying != null) setState(() => _replying = null);
    _input.clear();
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Future<bool> _toggleMuted() async {
    // Turning notifications off asks for how long; turning them on does not.
    int? hours;
    if (!_c.muted) {
      final picked = await askMuteDuration(context);
      if (picked == null || !mounted) return false;
      hours = picked == 0 ? null : picked;
    }
    final ok = await _c.toggleMuted(hours: hours);
    final id = _c.conversationId;
    if (ok && id != null) {
      final set = widget.mutedChats;
      if (set != null) _c.muted ? set.add(id) : set.remove(id);
    }
    return ok;
  }

  Future<bool> _deleteChat(bool forAll) async {
    final ok = await _c.deleteChat(forAll: forAll);
    if (ok) widget.onRead?.call(); // the list and the badge follow the server
    return ok;
  }

  /// "Write" in a member's card: their personal chat.
  void _writeTo(ChatUser user) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      chatInstantRoute(
        (_) => ChatThreadPage(
          api: widget.api,
          link: widget.link,
          peer: user,
          sounds: widget.sounds,
          mutedChats: widget.mutedChats,
          onRead: widget.onRead,
        ),
      ),
    );
  }

  /// What the "Voice" list of a profile needs from this chat.
  VoiceFeed? _voiceFeed(S s) {
    final id = _c.conversationId;
    if (id == null) return null;
    return VoiceFeed(
      load: (before) =>
          widget.api.messages(id, beforeId: before, limit: 30, kind: 'voice'),
      authorOf: (m) => _authorOfMessage(m, s),
      canDeleteForAll: (m) => !widget.isGroup || _c.isMine(m) || _c.isAdmin,
      delete: (m, {required forAll}) => _c.deleteMessage(m, forAll: forAll),
      goTo: _goToMessage,
    );
  }

  /// What the "Media" grid of a profile needs from this chat.
  MediaFeed? _mediaFeed() {
    final id = _c.conversationId;
    if (id == null) return null;
    return MediaFeed(
      load: (before) =>
          widget.api.messages(id, beforeId: before, limit: 45, kind: 'media'),
      canDeleteForAll: (m) => !widget.isGroup || _c.isMine(m) || _c.isAdmin,
      delete: (m, {required forAll}) => _c.deleteMessage(m, forAll: forAll),
      goTo: _goToMessage,
      open: _openMedia,
      api: widget.api,
    );
  }

  String _authorOfMessage(ChatMessage m, S s) {
    if (widget.isGroup || _c.isMine(m)) {
      return _authorOf(m.sender == 0 ? (widget.api.myId ?? 0) : m.sender, s);
    }
    return widget.peer.shortName;
  }

  /// Closes the profile on top and scrolls the chat to [target] (loading
  /// older pages first when it is far back), then makes it flash.
  Future<void> _goToMessage(ChatMessage target) async {
    final route = ModalRoute.of(context);
    Navigator.of(context).popUntil((r) => r == route);
    if (!await _c.loadUntil(target.id) || !mounted) return;
    setState(() {
      _jumpId = target.id;
      _flash = false;
    });
    for (var i = 0; i < 18 && mounted; i++) {
      await WidgetsBinding.instance.endOfFrame;
      final ctx = _jumpKey.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
        if (!mounted) return;
        setState(() => _flash = true);
        await Future<void>.delayed(const Duration(milliseconds: 1400));
        if (!mounted) return;
        setState(() => _flash = false);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (mounted) setState(() => _jumpId = null);
        return;
      }
      // Not built yet: jump to where it should be (a guess by the average
      // height) and look again.
      if (!_scroll.hasClients) return;
      final entries = _entries(_c.messages);
      final at = entries.indexWhere(
        (e) => e.album.any((x) => x.id == target.id),
      );
      if (at < 0) return;
      final fromBottom = entries.length - 1 - at;
      final pos = _scroll.position;
      final per =
          (pos.maxScrollExtent + pos.viewportDimension) / entries.length;
      _scroll.jumpTo((fromBottom * per).clamp(0.0, pos.maxScrollExtent));
    }
    if (mounted) setState(() => _jumpId = null);
  }

  /// The person's card: its own full screen page (photo, status, phone,
  /// department, position).
  void _openProfile(S s, String? status) {
    HapticFeedback.selectionClick();
    if (widget.isGroup) {
      Navigator.of(context).push(
        chatInstantRoute(
          (_) => ChatGroupPage(
            controller: _c,
            api: widget.api,
            link: widget.link,
            statusOf: () => _statusLine(s),
            onChanged: widget.onRead,
            onWrite: _writeTo,
            voiceFeed: _voiceFeed(s),
            mediaFeed: _mediaFeed(),
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      chatInstantRoute(
        (_) => ChatProfilePage(
          user: widget.peer,
          listenable: Listenable.merge([_c, widget.link.connected]),
          canManage: _c.conversationId != null,
          isMuted: () => _c.muted,
          onToggleMute: _toggleMuted,
          onDelete: _deleteChat,
          voiceFeed: _voiceFeed(s),
          mediaFeed: _mediaFeed(),
          statusOf: () => !widget.link.connected.value
              ? s.chatConnecting
              : _c.syncing
              ? s.chatUpdating
              : _c.peerTyping
              ? s.chatTyping
              : _c.peerOnline
              ? s.chatOnline
              : s.chatLastSeen(_c.peerLastSeen),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_c, widget.link.connected]),
      builder: (context, _) {
        // The name, and under it: connecting / typing / online / last seen.
        // Without a connection "typing…" is stale, so "Connecting…" wins.
        final line = _statusLine(s);
        final String? status = line.isEmpty ? null : line;
        // Removed from the group / the group was deleted: leave the screen.
        // This screen alone closes everything: the group card (and anything
        // above the chat) first, then the chat, so two screens never both pop
        // "the top route" and take the wrong one.
        final myRoute = ModalRoute.of(context);
        if (_c.removed && !_closing) {
          _closing = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final nav = Navigator.of(context);
            if (myRoute != null) nav.popUntil((r) => r == myRoute);
            widget.onRead?.call();
            if (nav.canPop()) nav.pop();
          });
        }
        return FadingHeaderScaffold(
          title: widget.peer.shortName,
          center: ChatNameCapsule(
            name: widget.peer.shortName,
            status: status,
            muted: _c.muted,
            onTap: () => _openProfile(s, status),
          ),
          trailing: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ChatAvatarButton(
                user: widget.peer,
                onTap: () => _openProfile(s, status),
              ),
            ),
          ],
          background: ChatAppearanceSettings.instance.wallpaperBase,
          // The wallpaper shows behind the glass controls: no plate.
          fade: false,
          body: (context, topInset) => Stack(
            children: [
              const Positioned.fill(child: ChatWallpaper()),
              // The messages fill the whole area, down to the screen edge, and
              // scroll under the glass of the header and of the input bar.
              Positioned.fill(child: _buildMessages(s, topInset)),
              // While a voice message plays: the player bar under the header.
              VoiceTopBarHost(
                top: topInset + 6,
                authorOf: (m) => widget.isGroup || _c.isMine(m)
                    ? _authorOf(
                        m.sender == 0 ? (widget.api.myId ?? 0) : m.sender,
                        s,
                      )
                    : widget.peer.shortName,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: NotificationListener<SizeChangedLayoutNotification>(
                  onNotification: (_) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _measureInput(),
                    );
                    return false;
                  },
                  child: SizeChangedLayoutNotifier(
                    child: KeyedSubtree(
                      key: _inputKey,
                      child: ChatInputBar(
                        controller: _input,
                        hint: s.chatInputHint,
                        canSend: _hasText,
                        onSend: _send,
                        editTitle: _editing != null
                            ? s.chatEditing
                            : _replying == null
                            ? null
                            : s.chatReplyTo(_authorOf(_replying!.sender, s)),
                        editText: _editing != null
                            ? _editing!.text
                            : _replying == null
                            ? null
                            : chatPreviewText(_replying!, s),
                        onCancelEdit: _cancelEdit,
                        onVoice: _sendVoice,
                        onAttach: _attach,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessages(S s, double topInset) {
    if (_c.loading && _c.messages.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topInset, bottom: _inputHeight),
        child: const Center(child: LogoStrokeLoader(size: 80)),
      );
    }
    if (_c.historyFailed && _c.messages.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topInset, bottom: _inputHeight),
        child: GestureDetector(
          onTap: _c.reload,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: ChatMessageBlock(
              icon: Icons.cloud_off_rounded,
              text: s.chatLoadError,
              color: const Color(0xFFD32F2F),
            ),
          ),
        ),
      );
    }
    final entries = _entries(_c.messages);
    if (entries.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topInset, bottom: _inputHeight),
        child: ChatEmptyState(text: s.chatNoMessages),
      );
    }
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      // Reverse list: padding.top is the visual top (under the header).
      // Reverse list: padding.bottom is the visual bottom, above the input bar.
      padding: EdgeInsets.fromLTRB(10, topInset + 8, 10, _inputHeight + 8),
      itemCount: entries.length + (_c.loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == entries.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final e = entries[entries.length - 1 - index];
        if (e.day != null) return _DayChip(label: _dayLabel(e.day!, s));
        if (e.message!.isSystem) {
          return _DayChip(label: _systemText(e.message!, s));
        }
        final bubble = _Bubble(
          message: e.message!,
          mine: _c.isMine(e.message!),
          senderLabel: widget.isGroup && !_c.isMine(e.message!) && e.firstInRun
              ? _authorOf(e.message!.sender, s)
              : null,
          tail: e.lastInRun,
          gapAbove: e.firstInRun,
          onRetry: () {
            for (final x in e.album) {
              _c.retry(x);
            }
          },
          notSentHint: s.chatNotSent,
          editedLabel: s.chatEdited,
          menu: _menuFor(e.message!, _c.isMine(e.message!), s),
          onMenu: (a) => _onMenu(e.message!, a, album: e.album),
          quoteAuthor: e.message!.reply == null
              ? null
              : _authorOf(e.message!.reply!.sender, s),
          onReply: () => _startReply(e.message!),
          onOpenMedia: () => _openMedia(e.message!),
          album: e.album,
          spy: _spy,
          albumKey: _albumKeys.putIfAbsent(
            '${e.message!.albumId}:${e.message!.id}',
            GlobalKey.new,
          ),
          onOpenAlbum: () => _openAlbumAt(e.album),
        );
        if (!e.album.any((x) => x.id == _jumpId)) return bubble;
        // The message "Go to message" leads to: found by its key, and it
        // flashes when the list has arrived.
        return KeyedSubtree(
          key: _jumpKey,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            decoration: BoxDecoration(
              color: _flash
                  ? AppColors.brandOrange.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: bubble,
          ),
        );
      },
    );
  }

  /// Messages (oldest first) with a day chip before the first of each day, and
  /// the runs of one sender marked, so that bubbles can be grouped.
  List<_Entry> _entries(List<ChatMessage> messages) {
    final out = <_Entry>[];
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final prev = i > 0 ? messages[i - 1] : null;
      final next = i + 1 < messages.length ? messages[i + 1] : null;
      final newDay = prev == null || !_sameDay(prev.createdAt, m.createdAt);
      if (newDay) out.add(_Entry.day(m.createdAt));
      final sameRunAsPrev =
          prev != null &&
          _sameDay(prev.createdAt, m.createdAt) &&
          _sameSender(prev, m);
      final sameRunAsNext =
          next != null &&
          _sameDay(m.createdAt, next.createdAt) &&
          _sameSender(next, m);
      // Photos / videos sent together: one bubble.
      if (m.albumId.isNotEmpty &&
          m.isMedia &&
          !m.isFile &&
          out.isNotEmpty &&
          out.last.message != null &&
          out.last.message!.albumId == m.albumId &&
          sameRunAsPrev) {
        out.last.album.add(m);
        out.last.lastInRun = !sameRunAsNext;
        continue;
      }
      out.add(
        _Entry.message(
          m,
          firstInRun: !sameRunAsPrev,
          lastInRun: !sameRunAsNext,
        ),
      );
    }
    return out;
  }

  /// Bubbles of one sender in a row are grouped. A service line breaks a run;
  /// in a group two people who are not me are told apart by id.
  bool _sameSender(ChatMessage a, ChatMessage b) {
    if (a.isSystem || b.isSystem) return false;
    final am = _c.isMine(a), bm = _c.isMine(b);
    if (am != bm) return false;
    return am || !widget.isGroup || a.sender == b.sender;
  }

  String _systemText(ChatMessage m, S s) =>
      chatSystemText(m, s, widget.api.myId);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime d, S s) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff == 0) return s.chatToday;
    if (diff == 1) return s.chatYesterday;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }
}

class _Entry {
  _Entry.day(this.day)
    : message = null,
      album = const [],
      firstInRun = false,
      lastInRun = false;
  _Entry.message(
    ChatMessage this.message, {
    required this.firstInRun,
    required this.lastInRun,
  }) : day = null,
       album = [message];

  final DateTime? day;
  final ChatMessage? message;

  /// The messages drawn in this bubble: one, or the photos / videos sent
  /// together (an album).
  final List<ChatMessage> album;
  final bool firstInRun;
  bool lastInRun;

  bool get isAlbum => album.length > 1;
}

/// The last place a finger touched the screen: the menu button around a bubble
/// takes the touches, so which tile of an album was tapped is worked out from
/// this point.
class _TouchSpy {
  Offset? last;
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kChatMuted,
            ),
          ),
        ),
      ),
    );
  }
}

enum _MsgAction { reply, copy, edit, deleteForMe, deleteForAll, discard }

/// How many emoji a message is made of when it is ONLY 1-3 emoji (shown big,
/// without a bubble, as in Telegram); null for anything else.
int? bigEmojiCount(String text) {
  final t = text.trim();
  if (t.isEmpty || t.length > 48) return null;
  final chars = t.characters;
  if (chars.length > 3) return null;
  final emoji = RegExp(
    r'^(?:\p{Extended_Pictographic}|[\u{1F1E6}-\u{1F1FF}]{2}|[\u{1F3FB}-\u{1F3FF}])'
    r'[\u{FE0F}\u{200D}\u{1F3FB}-\u{1F3FF}\u{E0020}-\u{E007F}\p{Extended_Pictographic}]*$',
    unicode: true,
  );
  for (final g in chars) {
    if (!emoji.hasMatch(g)) return null;
  }
  return chars.length;
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.tail,
    required this.gapAbove,
    required this.onRetry,
    required this.notSentHint,
    required this.editedLabel,
    required this.menu,
    required this.onMenu,
    required this.quoteAuthor,
    required this.onReply,
    required this.onOpenMedia,
    required this.album,
    required this.onOpenAlbum,
    required this.spy,
    required this.albumKey,
    this.senderLabel,
  });

  /// The photos / videos drawn in this bubble when they were sent together
  /// ([message] is the first); one message otherwise.
  final List<ChatMessage> album;
  final VoidCallback onOpenAlbum;
  final _TouchSpy spy;
  final GlobalKey albumKey;

  /// A tap on a photo / video / document.
  final VoidCallback onOpenMedia;

  /// In a group: who wrote it (the first bubble of a person's run).
  final String? senderLabel;
  final String? quoteAuthor;
  final VoidCallback onReply;
  final String editedLabel;
  final List<AdaptivePopupMenuEntry> menu;
  final void Function(_MsgAction? action) onMenu;
  final ChatMessage message;
  final bool mine;
  final bool tail;
  final bool gapAbove;
  final VoidCallback onRetry;
  final String notSentHint;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final isAlbum = album.length > 1;
    final failed = album.any((x) => x.state == ChatSendState.failed);
    // Telegram's palette: my messages light green, the peer's white.
    const fg = kChatInk;
    final meta = mine ? const Color(0xFF5DAA55) : kChatMuted;
    const big = Radius.circular(20);
    const small = Radius.circular(6);
    final radius = BorderRadius.only(
      topLeft: big,
      topRight: big,
      bottomLeft: (!mine && tail) ? small : big,
      bottomRight: (mine && tail) ? small : big,
    );
    String two(int v) => v.toString().padLeft(2, '0');
    final time = '${two(m.createdAt.hour)}:${two(m.createdAt.minute)}';

    // Only 1-3 emoji: big and without a bubble, as in Telegram.
    final bigCount = (!m.isMedia && !m.isVoice && !isAlbum && m.reply == null)
        ? bigEmojiCount(m.text)
        : null;

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.84,
      ),
      padding: bigCount != null
          ? const EdgeInsets.fromLTRB(4, 2, 4, 2)
          : m.isMedia
          ? const EdgeInsets.all(4)
          : const EdgeInsets.fromLTRB(14, 9, 12, 8),
      decoration: BoxDecoration(
        color: bigCount != null
            ? Colors.transparent
            : (mine ? const Color(0xFFE1FFC7) : Colors.white),
        borderRadius: radius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (senderLabel != null)
            Padding(
              padding: EdgeInsets.only(
                bottom: 2,
                left: m.isMedia ? 8 : 0,
                top: m.isMedia ? 4 : 0,
              ),
              child: Text(
                senderLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _senderColor(m.sender),
                ),
              ),
            ),
          if (m.reply != null && quoteAuthor != null)
            Padding(
              padding: m.isMedia
                  ? const EdgeInsets.fromLTRB(4, 4, 4, 0)
                  : EdgeInsets.zero,
              child: _Quote(
                author: quoteAuthor!,
                text: chatReplyText(m.reply!, S.of(context)),
                color: mine ? const Color(0xFF5DAA55) : AppColors.brandOrange,
              ),
            ),
          // The player itself lies over the bubble (see below): the menu
          // button covers its whole child with a native view that takes every
          // touch, so a control inside would never get a tap.
          if (m.isVoice)
            const SizedBox(width: kVoiceBodyWidth, height: kVoiceBodyHeight)
          else if (isAlbum) ...[
            AlbumBody(
              key: albumKey,
              messages: album,
              width: math.min(
                MediaQuery.of(context).size.width * 0.84 - 8,
                290,
              ),
              meta: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 3),
                    _Status(
                      message: album.firstWhere(
                        (x) => x.state == ChatSendState.failed,
                        orElse: () => album.firstWhere(
                          (x) => x.state == ChatSendState.sending,
                          orElse: () => album.last,
                        ),
                      ),
                      color: Colors.white,
                    ),
                  ],
                ],
              ),
            ),
            if (album.any((x) => x.text.trim().isNotEmpty))
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                child: Text(
                  album.firstWhere((x) => x.text.trim().isNotEmpty).text,
                  style: TextStyle(
                    fontSize: ChatAppearanceSettings.instance.textSize,
                    height: 1.28,
                    color: fg,
                  ),
                ),
              ),
          ] else if (m.isMedia) ...[
            MediaBubbleBody(
              message: m,
              accent: mine ? const Color(0xFF5DAA55) : AppColors.brandOrange,
              maxWidth: MediaQuery.of(context).size.width * 0.84 - 8,
              metaOf: (color) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time, style: TextStyle(fontSize: 12, color: color)),
                  if (mine) ...[
                    const SizedBox(width: 3),
                    _Status(message: m, color: color),
                  ],
                ],
              ),
            ),
            if (m.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                child: Text(
                  m.text,
                  style: TextStyle(
                    fontSize: ChatAppearanceSettings.instance.textSize,
                    height: 1.28,
                    color: fg,
                  ),
                ),
              ),
          ] else if (bigCount != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  m.text.trim(),
                  style: TextStyle(
                    fontSize: bigCount == 1
                        ? 72
                        : bigCount == 2
                        ? 58
                        : 48,
                    height: 1.15,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.edited ? '$editedLabel $time' : time,
                      style: const TextStyle(fontSize: 12, color: kChatMuted),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 3),
                      _Status(message: m, color: kChatMuted),
                    ],
                  ],
                ),
              ],
            )
          else
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 8,
              children: [
                Text(
                  m.text,
                  style: TextStyle(
                    fontSize: ChatAppearanceSettings.instance.textSize,
                    height: 1.28,
                    color: fg,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.edited ? '$editedLabel $time' : time,
                      style: TextStyle(fontSize: 12, color: meta),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 3),
                      _Status(message: m, color: meta),
                    ],
                  ],
                ),
              ],
            ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: gapAbove ? 8 : 2),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: _SwipeToReply(
              enabled: !album.any((x) => x.isLocal) && !failed,
              onReply: onReply,
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) => spy.last = e.position,
                child: Stack(
                  children: [
                    AdaptivePopupMenuButton.widget<_MsgAction>(
                      items: menu,
                      triggerOnLongPress: true,
                      onTap: failed
                          ? onRetry
                          : (isAlbum
                                ? onOpenAlbum
                                : (m.isMedia ? onOpenMedia : null)),
                      onSelected: (_, entry) => onMenu(entry.value),
                      child: bubble,
                    ),
                    if (m.isVoice)
                      Positioned(
                        left: 14,
                        bottom: 8,
                        width: kVoiceBodyWidth,
                        height: kVoiceBodyHeight,
                        child: VoiceBubbleBody(
                          message: m,
                          accent: mine
                              ? const Color(0xFF5DAA55)
                              : AppColors.brandOrange,
                          meta: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                time,
                                style: TextStyle(fontSize: 12, color: meta),
                              ),
                              if (mine) ...[
                                const SizedBox(width: 3),
                                _Status(message: m, color: meta),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (failed)
            GestureDetector(
              onTap: onRetry,
              child: Padding(
                padding: const EdgeInsets.only(top: 2, right: 4),
                child: Text(
                  notSentHint,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFD32F2F),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Clock while sending, one tick sent, two ticks read, red mark when failed.
class _Status extends StatelessWidget {
  const _Status({required this.message, required this.color});

  final ChatMessage message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    var c = color;
    switch (message.state) {
      case ChatSendState.sending:
        icon = Icons.schedule_rounded;
      case ChatSendState.failed:
        icon = Icons.error_rounded;
        c = const Color(0xFFD32F2F);
      case ChatSendState.sent:
        icon = message.read ? Icons.done_all_rounded : Icons.done_rounded;
    }
    return Icon(icon, size: 16, color: c);
  }
}

/// The quoted message above an answer (a coloured bar, the author, the text).
class _Quote extends StatelessWidget {
  const _Quote({required this.author, required this.text, required this.color});

  final String author;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.2,
            ),
          ),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: kChatInk, height: 1.2),
          ),
        ],
      ),
    );
  }
}

/// Drag a message to the left to answer it: the bubble follows the finger, an
/// arrow shows up, a tick tells that letting go will answer.
class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({
    required this.child,
    required this.onReply,
    required this.enabled,
  });

  final Widget child;
  final VoidCallback onReply;
  final bool enabled;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  static const _trigger = 56.0;
  static const _max = 80.0;

  double _dx = 0;
  bool _dragging = false;
  bool _armed = false;

  void _update(DragUpdateDetails d) {
    final next = (_dx + d.delta.dx).clamp(-_max, 0.0);
    final armed = next <= -_trigger;
    if (armed && !_armed) HapticFeedback.mediumImpact();
    setState(() {
      _dx = next;
      _dragging = true;
      _armed = armed;
    });
  }

  void _end() {
    final fire = _armed;
    setState(() {
      _dx = 0;
      _dragging = false;
      _armed = false;
    });
    if (fire) widget.onReply();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final progress = (-_dx / _trigger).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: (_) => _end(),
      onHorizontalDragCancel: _end,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: [
          Positioned(
            right: -34,
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.6 + 0.4 * progress,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.reply_rounded,
                    size: 19,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dx, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// A person's name colour in a group (the same colour every time).
Color _senderColor(int id) {
  const palette = [
    Color(0xFFE17076),
    Color(0xFFEDA86C),
    Color(0xFFA695E7),
    Color(0xFF7BC862),
    Color(0xFF6EC9CB),
    Color(0xFF65AADD),
    Color(0xFFEE7AAE),
    Color(0xFFCC7A3E),
  ];
  return palette[id.abs() % palette.length];
}
