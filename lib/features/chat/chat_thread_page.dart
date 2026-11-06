import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  @override
  void dispose() {
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
    return [
      if (stored)
        AdaptivePopupMenuItem<_MsgAction>(
          label: s.chatMenuReply,
          icon: ios26 ? 'arrowshape.turn.up.left' : Icons.reply_rounded,
          value: _MsgAction.reply,
        ),
      AdaptivePopupMenuItem<_MsgAction>(
        label: s.chatMenuCopy,
        icon: ios26 ? 'doc.on.doc' : Icons.copy_rounded,
        value: _MsgAction.copy,
      ),
      if (mine && stored)
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

  void _onMenu(ChatMessage m, _MsgAction? action) {
    switch (action) {
      case _MsgAction.reply:
        _startReply(m);
      case _MsgAction.copy:
        Clipboard.setData(ClipboardData(text: m.text));
        HapticFeedback.selectionClick();
      case _MsgAction.edit:
        _startEdit(m);
      case _MsgAction.deleteForMe:
        _c.deleteMessage(m, forAll: false);
      case _MsgAction.deleteForAll:
        _c.deleteMessage(m, forAll: true);
      case null:
        break;
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
    final ok = await _c.toggleMuted();
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
          statusOf: () => !widget.link.connected.value
              ? s.chatConnecting
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
          background: kChatWallpaperBase,
          // The wallpaper shows behind the glass controls: no plate.
          fade: false,
          body: (context, topInset) => Stack(
            children: [
              const Positioned.fill(child: ChatWallpaper()),
              // The messages fill the whole area, down to the screen edge, and
              // scroll under the glass of the header and of the input bar.
              Positioned.fill(child: _buildMessages(s, topInset)),
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
                        editText: (_editing ?? _replying)?.text,
                        onCancelEdit: _cancelEdit,
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
        return _Bubble(
          message: e.message!,
          mine: _c.isMine(e.message!),
          senderLabel: widget.isGroup && !_c.isMine(e.message!) && e.firstInRun
              ? _authorOf(e.message!.sender, s)
              : null,
          tail: e.lastInRun,
          gapAbove: e.firstInRun,
          onRetry: () => _c.retry(e.message!),
          notSentHint: s.chatNotSent,
          editedLabel: s.chatEdited,
          menu: _menuFor(e.message!, _c.isMine(e.message!), s),
          onMenu: (a) => _onMenu(e.message!, a),
          quoteAuthor: e.message!.reply == null
              ? null
              : _authorOf(e.message!.reply!.sender, s),
          onReply: () => _startReply(e.message!),
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
  _Entry.day(this.day) : message = null, firstInRun = false, lastInRun = false;
  _Entry.message(
    ChatMessage this.message, {
    required this.firstInRun,
    required this.lastInRun,
  }) : day = null;

  final DateTime? day;
  final ChatMessage? message;
  final bool firstInRun;
  final bool lastInRun;
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

enum _MsgAction { reply, copy, edit, deleteForMe, deleteForAll }

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
    this.senderLabel,
  });

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
    final failed = m.state == ChatSendState.failed;
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

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.84,
      ),
      padding: const EdgeInsets.fromLTRB(14, 9, 12, 8),
      decoration: BoxDecoration(
        color: mine ? const Color(0xFFE1FFC7) : Colors.white,
        borderRadius: radius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (senderLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
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
            _Quote(
              author: quoteAuthor!,
              text: m.reply!.text,
              color: mine ? const Color(0xFF5DAA55) : AppColors.brandOrange,
            ),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text(
                m.text,
                style: const TextStyle(fontSize: 17, height: 1.28, color: fg),
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
              enabled: !m.isLocal && !failed,
              onReply: onReply,
              child: AdaptivePopupMenuButton.widget<_MsgAction>(
                items: menu,
                triggerOnLongPress: true,
                onTap: failed ? onRetry : null,
                onSelected: (_, entry) => onMenu(entry.value),
                child: bubble,
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
