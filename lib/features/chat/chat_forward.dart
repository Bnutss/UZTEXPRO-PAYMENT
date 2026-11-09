import 'dart:async';
import 'dart:io';

import 'chat_api.dart';
import 'chat_media.dart';
import 'chat_models.dart';

/// Where a message can be forwarded: a chat (personal or group) that exists, or
/// a person one has no chat with yet (the chat is opened when sending).
class ForwardTarget {
  const ForwardTarget.chat(ChatConversation this.chat) : user = null;
  const ForwardTarget.person(ChatUser this.user) : chat = null;

  final ChatConversation? chat;
  final ChatUser? user;

  /// The person (or, for a group, its stand-in) shown for this target.
  ChatUser get peer => chat?.peer ?? user!;
  bool get isGroup => chat?.isGroup ?? false;

  /// The same chat or person twice is one target.
  String get key => chat != null ? 'c${chat!.id}' : 'u${user!.id}';
}

/// What a forward came to.
class ForwardResult {
  const ForwardResult({
    required this.sent,
    required this.failed,
    required this.chatIds,
  });

  final int sent;

  /// Messages that could not be forwarded (no file, no network…).
  final int failed;

  /// The conversation each target ended up as, in the order of the targets.
  final List<int> chatIds;
}

/// Forwards messages into other chats.
///
/// A text or voice message, and a photo / video / document the server still
/// has, is copied by the server ("forward" request: nothing is uploaded). The
/// server drops an original once everybody has it; then the app sends its own
/// copy of the file from this phone, marked as a forward of the same message.
class ChatForwarder {
  ChatForwarder(this.api);

  final ChatRest api;
  int _n = 0;

  String _clientId() =>
      'fw${DateTime.now().microsecondsSinceEpoch}_${_n++}';

  /// [messages] is one message, or the photos of an album (oldest first).
  Future<ForwardResult> forward(
    List<ChatMessage> messages,
    List<ForwardTarget> targets,
  ) async {
    var sent = 0;
    var failed = 0;
    final chatIds = <int>[];
    final stored = [
      for (final m in messages)
        if (!m.isLocal && !m.isSystem) m,
    ];
    for (final target in targets) {
      int convId;
      try {
        convId =
            target.chat?.id ?? (await api.openConversation(target.user!.id)).id;
      } catch (_) {
        failed += stored.length;
        continue;
      }
      chatIds.add(convId);
      // Several photos / videos go as one album, as they were sent.
      final media = stored.where((m) => m.isMedia).length;
      final album = media > 1 ? 'fa${DateTime.now().microsecondsSinceEpoch}' : '';
      for (final m in stored) {
        final ok = await _one(convId, m, m.isMedia ? album : '');
        ok ? sent++ : failed++;
      }
    }
    return ForwardResult(sent: sent, failed: failed, chatIds: chatIds);
  }

  Future<bool> _one(int convId, ChatMessage m, String albumId) async {
    final clientId = _clientId();
    try {
      final copy = await api.forwardMessage(
        convId,
        m.id,
        clientId,
        albumId: albumId,
      );
      // The file is on this phone already: the new message shows it at once
      // (and opens at once) instead of being fetched from the server first.
      if (m.isMedia) await _keepCopy(copy, m);
      return true;
    } on ChatApiException catch (e) {
      // The server no longer has the file: send the copy from this phone.
      if (e.statusCode == 410 && m.isMedia) {
        return _upload(convId, m, albumId, clientId);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Puts this phone's file and preview of [original] where the new message
  /// [copy] looks for its own. Nothing to copy (not downloaded here) is fine.
  Future<void> _keepCopy(ChatMessage copy, ChatMessage original) async {
    try {
      await ChatMediaStore.init();
      final file = ChatMediaStore.fileOf(original);
      if (file == null || !file.existsSync()) return;
      final thumb = ChatMediaStore.thumbOf(original);
      await ChatMediaStore.keepOutgoing(
        copy,
        file.path,
        (thumb != null && thumb.existsSync()) ? thumb.path : null,
      );
    } catch (_) {}
  }

  Future<bool> _upload(
    int convId,
    ChatMessage m,
    String albumId,
    String clientId,
  ) async {
    try {
      await ChatMediaStore.init();
      var file = ChatMediaStore.fileOf(m);
      if (file == null) return false;
      if (!file.existsSync()) {
        // Not on this phone either (and the server had dropped it): nothing to send.
        return false;
      }
      final thumb = ChatMediaStore.thumbOf(m);
      final media = m.media!;
      final upload = ChatUpload(
        filePath: file.path,
        kind: m.kind,
        name: media.name,
        width: media.width,
        height: media.height,
        durationMs: media.durationMs,
        thumbPath: (thumb != null && thumb.existsSync()) ? thumb.path : null,
        caption: m.text,
        albumId: albumId,
      );
      final sent = await api.sendMedia(
        convId,
        upload,
        '${clientId}u',
        forwardOf: m.id,
      );
      await _keepCopy(sent, m);
      return true;
    } on FileSystemException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
