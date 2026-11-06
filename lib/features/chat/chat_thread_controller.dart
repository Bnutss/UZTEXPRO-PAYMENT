import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'chat_api.dart';
import 'chat_models.dart';
import 'chat_socket.dart';

/// State and logic of one conversation: history, live messages, sending with
/// an immediate local copy, delivery fallbacks, read marks and "typing".
///
/// "Mine" is everything not sent by the peer: it is a chat of two people, so
/// the id of the signed-in user is not needed.
class ChatThreadController extends ChangeNotifier {
  ChatThreadController({
    required this.rest,
    required this.link,
    required this.peer,
    int? conversationId,
    this.retryAfter = const Duration(seconds: 6),
    this.typingTimeout = const Duration(seconds: 4),
    this.pageSize = 50,
    this.onReadMarked,
    this.isGroup = false,
  }) : _convId = conversationId;

  final ChatRest rest;
  final ChatLink link;

  /// For a group, a stand-in carrying its title and photo
  /// ([ChatUser.groupStandIn]).
  final ChatUser peer;

  /// A group chat: many people write, `peer` is the group itself.
  final bool isGroup;

  /// If the socket has not echoed a message within this time, it is sent again
  /// over HTTP (the server saves one message per client id).
  final Duration retryAfter;

  /// "Typing…" fades after this long without a new typing event.
  final Duration typingTimeout;
  final int pageSize;

  /// Called after the peer's messages were marked read (the unread total on
  /// the tab changes).
  final VoidCallback? onReadMarked;

  int? _convId;

  /// Null until the chat has been opened on the server (a contact was just
  /// tapped): the screen does not wait for it.
  int? get conversationId => _convId;

  final List<ChatMessage> _messages = [];

  /// Oldest first.
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool loading = true;
  bool loadingMore = false;
  bool hasMore = false;
  bool historyFailed = false;

  /// Somebody is typing (in a group, anybody but me).
  bool get peerTyping => _typing.isNotEmpty;

  /// Who is typing: user id → the timer that ends it.
  final Map<int, Timer> _typing = {};

  /// Names by user id, from the messages and the member list (group).
  final Map<int, String> names = {};

  /// Ids of the people typing now.
  Iterable<int> get typingIds => _typing.keys;

  /// The group's card (members, my role), once loaded.
  ChatConversation? group;

  /// I was removed from the group, or it was deleted: the screen closes.
  bool removed = false;

  bool get isAdmin => group?.isAdmin ?? false;

  /// The peer's presence: fresh from the server when the chat opens, and
  /// "online" as soon as they type or write.
  late bool peerOnline = peer.online;
  late DateTime? peerLastSeen = peer.lastSeen;

  /// Notifications of this chat are off (for me).
  bool muted = false;

  /// The chat was deleted (by me or by the peer): the screen should close.
  bool deleted = false;

  StreamSubscription<ChatEvent>? _sub;
  bool _wasConnected = false;
  bool _disposed = false;
  int _localSeq = 0;
  int _lastReadSent = 0;
  DateTime? _lastTypingSent;
  final Map<String, Timer> _pendingTimers = {};

  /// Direct: everything not from the peer is mine. Group: what I wrote (a local
  /// copy has sender 0, the server's echo has my real id).
  bool isMine(ChatMessage m) => isGroup
      ? (m.sender == 0 || (rest.myId != null && m.sender == rest.myId))
      : m.sender != peer.id;

  // ── life cycle ────────────────────────────────────────────────────────

  Future<void> start() async {
    _sub = link.events.listen(_onEvent);
    _wasConnected = link.connected.value;
    link.connected.addListener(_onConnection);
    unawaited(isGroup ? _loadGroup() : _refreshPresence());
    await _loadLatest(initial: true);
  }

  /// The group's card: members, my role, the mute flag.
  Future<void> _loadGroup() async {
    final id = _convId;
    if (id == null) return;
    try {
      final g = await rest.group(id);
      group = g;
      muted = g.muted;
      for (final m in g.members) {
        names[m.id] = m.name;
      }
      _changed();
    } catch (e) {
      // A group I am no longer in (or that was deleted) answers 404.
      if (e is ChatApiException && e.statusCode == 404) {
        removed = true;
        _changed();
      }
    }
  }

  Future<void> reloadGroup() => _loadGroup();

  Future<void> _refreshPresence() async {
    try {
      final conv = await _open();
      _convId ??= conv.id;
      peerOnline = conv.peer.online;
      peerLastSeen = conv.peer.lastSeen;
      muted = conv.muted;
      _changed();
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    link.connected.removeListener(_onConnection);
    for (final t in _typing.values) {
      t.cancel();
    }
    for (final t in _pendingTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  // ── chat actions ──────────────────────────────────────────────────────

  Future<bool> toggleMuted() async {
    final id = _convId;
    if (id == null) return false;
    final next = !muted;
    try {
      await rest.setMuted(id, next);
    } catch (_) {
      return false;
    }
    muted = next;
    _changed();
    return true;
  }

  /// Saves a new text of my message.
  Future<bool> editMessage(ChatMessage m, String text) async {
    final body = text.trim();
    if (body.isEmpty || m.isLocal) return false;
    if (body == m.text) return true;
    try {
      _upsert(await rest.editMessage(m.id, body));
    } catch (_) {
      return false;
    }
    _changed();
    return true;
  }

  Future<bool> deleteMessage(ChatMessage m, {required bool forAll}) async {
    if (m.isLocal) return false;
    try {
      await rest.deleteMessage(m.id, forAll: forAll);
    } catch (_) {
      return false;
    }
    _messages.removeWhere((x) => x.id == m.id);
    _changed();
    return true;
  }

  /// Deletes the chat's messages (only mine, or for both people).
  Future<bool> deleteChat({required bool forAll}) async {
    final id = _convId;
    if (id == null) return false;
    try {
      await rest.deleteConversation(id, forAll: forAll);
    } catch (_) {
      return false;
    }
    _messages.clear();
    hasMore = false;
    deleted = true;
    _changed();
    return true;
  }

  // ── group actions ─────────────────────────────────────────────────────

  Future<bool> _groupCall(Future<void> Function(int id) call) async {
    final id = _convId;
    if (id == null) return false;
    try {
      await call(id);
    } catch (_) {
      return false;
    }
    await _loadGroup();
    return true;
  }

  Future<bool> renameGroup(String title) =>
      _groupCall((id) => rest.updateGroup(id, title: title));

  Future<bool> changeGroupPhoto(Uint8List photo) =>
      _groupCall((id) => rest.updateGroup(id, photo: photo));

  Future<bool> removeGroupPhoto() =>
      _groupCall((id) => rest.updateGroup(id, removePhoto: true));

  Future<bool> addMembers(List<int> ids) =>
      _groupCall((id) => rest.addMembers(id, ids));

  Future<bool> removeMember(int userId) =>
      _groupCall((id) => rest.removeMember(id, userId));

  Future<bool> setRole(int userId, String role) =>
      _groupCall((id) => rest.setMemberRole(id, userId, role));

  /// Leaves the group (my own id).
  Future<bool> leaveGroup() async {
    final id = _convId;
    final me = rest.myId;
    if (id == null || me == null) return false;
    try {
      await rest.removeMember(id, me);
    } catch (e) {
      if (!(e is ChatApiException && e.statusCode == 404)) return false;
    }
    removed = true;
    _changed();
    return true;
  }

  /// Deletes the whole group for everybody (the owner).
  Future<bool> deleteGroup() async {
    final id = _convId;
    if (id == null) return false;
    try {
      await rest.deleteGroup(id);
    } catch (e) {
      // Already gone (deleted on another phone): that is what was wanted.
      if (!(e is ChatApiException && e.statusCode == 404)) return false;
    }
    removed = true;
    _changed();
    return true;
  }

  // ── history ───────────────────────────────────────────────────────────

  Future<void> _ensureConversation() async {
    if (_convId != null) return;
    final conv = await _open();
    _convId ??= conv.id;
  }

  /// One "open the chat" request is shared by whoever needs it first (the
  /// history and the presence both start at once).
  Future<ChatConversation>? _opening;
  Future<ChatConversation> _open() =>
      _opening ??= rest.openConversation(peer.id).catchError((Object e) {
        _opening = null;
        throw e;
      });

  Future<void> _loadLatest({bool initial = false}) async {
    try {
      await _ensureConversation();
      final page = await rest.messages(_convId!, limit: pageSize);
      for (final m in page.messages) {
        _upsert(m);
      }
      if (initial) hasMore = page.hasMore;
      historyFailed = false;
    } catch (_) {
      if (initial) historyFailed = true;
    } finally {
      loading = false;
      _changed();
      _markReadIfNeeded();
    }
  }

  /// Retry after the first load failed (pull / tap).
  Future<void> reload() async {
    loading = true;
    historyFailed = false;
    _changed();
    await _loadLatest(initial: true);
  }

  /// Older messages, when the user scrolls to the top.
  Future<void> loadMore() async {
    if (loadingMore || !hasMore || _convId == null) return;
    final oldest = _messages
        .where((m) => !m.isLocal)
        .fold<int?>(null, (min, m) => min == null ? m.id : math.min(min, m.id));
    if (oldest == null) return;
    loadingMore = true;
    _changed();
    try {
      final page = await rest.messages(
        _convId!,
        beforeId: oldest,
        limit: pageSize,
      );
      for (final m in page.messages) {
        _upsert(m);
      }
      hasMore = page.hasMore;
    } catch (_) {
      // Stays available: the next scroll to the top tries again.
    } finally {
      loadingMore = false;
      _changed();
    }
  }

  /// The socket came back: pick up what was missed while it was away.
  void _onConnection() {
    final now = link.connected.value;
    final returned = now && !_wasConnected;
    _wasConnected = now;
    if (returned && _convId != null) _loadLatest();
  }

  // ── merging ───────────────────────────────────────────────────────────

  /// Adds a message or replaces the one it confirms (same id, or the same
  /// client id for my own copy that was shown before the server knew it).
  void _upsert(ChatMessage m) {
    if (m.senderName.isNotEmpty && m.sender > 0) names[m.sender] = m.senderName;
    var i = m.id > 0 ? _messages.indexWhere((x) => x.id == m.id) : -1;
    if (i < 0 && m.clientId.isNotEmpty) {
      // The local copy has no real sender id: match on "mine / the peer's".
      i = _messages.indexWhere(
        (x) => x.clientId == m.clientId && isMine(x) == isMine(m),
      );
    }
    if (i >= 0) {
      final old = _messages[i];
      _messages[i] = m.copyWith(read: m.read || old.read);
    } else {
      _messages.add(m);
    }
    _messages.sort(_compare);
  }

  static int _compare(ChatMessage a, ChatMessage b) {
    if (a.isLocal != b.isLocal) return a.isLocal ? 1 : -1;
    return a.isLocal
        ? a.createdAt.compareTo(b.createdAt)
        : a.id.compareTo(b.id);
  }

  // ── live events ───────────────────────────────────────────────────────

  void _onEvent(ChatEvent e) {
    switch (e.type) {
      case 'message_edited':
        final m = ChatMessage.fromJson(e.data);
        if (m.conversation == _convId) {
          _upsert(m);
          _changed();
        }
      case 'message_deleted':
        if ((e.data['conversation'] as num?)?.toInt() == _convId) {
          _messages.removeWhere((m) => m.id == (e.data['id'] as num?)?.toInt());
          _changed();
        }
      case 'cleared':
        if ((e.data['conversation'] as num?)?.toInt() == _convId) {
          _messages.clear();
          hasMore = false;
          _clearTyping();
          _changed();
        }
      case 'conversation_removed':
        if ((e.data['conversation'] as num?)?.toInt() == _convId) {
          removed = true;
          _changed();
        }
      case 'conversations_changed':
        if (isGroup && (e.data['conversation'] as num?)?.toInt() == _convId) {
          unawaited(_loadGroup());
        }
      case 'message':
        _onMessage(ChatMessage.fromJson(e.data));
      case 'typing':
        _onTyping(e.data);
      case 'read':
        _onRead(e.data);
      case 'error':
        _onError(e.data);
    }
  }

  bool _adopt(int conversation, {required int sender, String clientId = ''}) {
    if (_convId != null) return conversation == _convId;
    // The chat is not known yet: take events of the peer, and the echo of my
    // own first message.
    final mine = isGroup ? false : sender != peer.id;
    final ok = !mine || _messages.any((x) => x.clientId == clientId);
    if (ok) _convId = conversation;
    return ok;
  }

  void _onMessage(ChatMessage m) {
    if (!_adopt(m.conversation, sender: m.sender, clientId: m.clientId)) return;
    _pendingTimers.remove(m.clientId)?.cancel();
    _upsert(m);
    if (!isMine(m)) {
      _stopTyping(m.sender);
      peerOnline = true;
    }
    _changed();
    _markReadIfNeeded();
  }

  void _onTyping(Map<String, dynamic> d) {
    final user = (d['user'] as num?)?.toInt();
    final conv = (d['conversation'] as num?)?.toInt();
    if (user == null || conv == null) return;
    if (isGroup) {
      if (user == rest.myId || conv != _convId) return;
    } else {
      if (user != peer.id) return;
      if (!_adopt(conv, sender: peer.id)) return;
      peerOnline = true;
    }
    _typing[user]?.cancel();
    _typing[user] = Timer(typingTimeout, () {
      _typing.remove(user);
      _changed();
    });
    _changed();
  }

  void _stopTyping(int user) {
    _typing.remove(user)?.cancel();
  }

  void _clearTyping() {
    for (final t in _typing.values) {
      t.cancel();
    }
    _typing.clear();
  }

  void _onRead(Map<String, dynamic> d) {
    final conv = (d['conversation'] as num?)?.toInt();
    final reader = (d['reader'] as num?)?.toInt();
    final upTo = (d['up_to'] as num?)?.toInt() ?? 0;
    if (conv != _convId) return;
    if (isGroup ? reader == rest.myId : reader != peer.id) return;
    var any = false;
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      if (isMine(m) && !m.isLocal && !m.read && m.id <= upTo) {
        _messages[i] = m.copyWith(read: true);
        any = true;
      }
    }
    if (any) _changed();
  }

  void _onError(Map<String, dynamic> d) {
    final cid = d['client_id'] as String?;
    if (cid == null || cid.isEmpty) return;
    _pendingTimers.remove(cid)?.cancel();
    _setState(cid, ChatSendState.failed);
  }

  // ── read marks and typing ─────────────────────────────────────────────

  void _markReadIfNeeded() {
    final conv = _convId;
    if (conv == null) return;
    final incoming = _messages.where((m) => !isMine(m) && !m.isLocal);
    if (incoming.isEmpty) return;
    final last = incoming.last.id;
    if (last <= _lastReadSent) return;
    _lastReadSent = last;
    onReadMarked?.call();
    if (link.connected.value) {
      link.read(conv, last);
    } else {
      rest.markRead(conv, last).catchError((_) {
        // Try again with the next message / the next catch-up.
        _lastReadSent = 0;
      });
    }
  }

  /// Call on every change of the input: tells the peer that I am typing, at
  /// most every 2.5 s.
  void onTextChanged(String text) {
    final conv = _convId;
    if (text.trim().isEmpty || conv == null || !link.connected.value) return;
    final now = DateTime.now();
    final last = _lastTypingSent;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 2500)) {
      return;
    }
    _lastTypingSent = now;
    link.typing(conv);
  }

  // ── sending ───────────────────────────────────────────────────────────

  String _newClientId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 32)}';

  /// Shows the message at once and sends it: over the socket when it is open,
  /// otherwise (or when the socket does not confirm in time) over HTTP.
  void send(String text, {ChatMessage? replyTo}) {
    final body = text.trim();
    if (body.isEmpty) return;
    final local = ChatMessage(
      id: -(++_localSeq),
      conversation: _convId ?? 0,
      // My real user id is not needed (and unknown here): 0 is "not the peer".
      sender: 0,
      text: body,
      clientId: _newClientId(),
      createdAt: DateTime.now(),
      read: false,
      state: ChatSendState.sending,
      reply: replyTo == null || replyTo.isLocal
          ? null
          : ChatReply(
              id: replyTo.id,
              sender: replyTo.sender,
              text: replyTo.text,
            ),
    );
    _messages.add(local);
    _messages.sort(_compare);
    _changed();
    _dispatch(local);
  }

  /// Tap on a failed message.
  void retry(ChatMessage failed) {
    if (failed.state != ChatSendState.failed) return;
    _setState(failed.clientId, ChatSendState.sending);
    _dispatch(failed.copyWith(state: ChatSendState.sending));
  }

  void _dispatch(ChatMessage local) {
    final viaSocket =
        link.connected.value &&
        link.sendMessage(
          conversation: _convId,
          to: _convId == null ? peer.id : null,
          text: local.text,
          clientId: local.clientId,
          replyTo: local.reply?.id,
        );
    if (viaSocket) {
      _pendingTimers[local.clientId] = Timer(
        retryAfter,
        () => _restSend(local),
      );
    } else {
      _restSend(local);
    }
  }

  bool _stillPending(String clientId) => _messages.any(
    (m) => m.clientId == clientId && m.state == ChatSendState.sending,
  );

  Future<void> _restSend(ChatMessage local) async {
    _pendingTimers.remove(local.clientId)?.cancel();
    if (_disposed || !_stillPending(local.clientId)) return;
    try {
      await _ensureConversation();
      final saved = await rest.sendMessage(
        _convId!,
        local.text,
        local.clientId,
        replyTo: local.reply?.id,
      );
      _upsert(saved);
      _changed();
    } catch (_) {
      if (!_disposed && _stillPending(local.clientId)) {
        _setState(local.clientId, ChatSendState.failed);
      }
    }
  }

  void _setState(String clientId, ChatSendState state) {
    final i = _messages.indexWhere((m) => m.clientId == clientId && m.isLocal);
    if (i < 0) return;
    _messages[i] = _messages[i].copyWith(state: state);
    _changed();
  }
}
