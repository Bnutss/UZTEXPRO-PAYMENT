import 'dart:async';
import 'dart:math' as math;

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
  }) : _convId = conversationId;

  final ChatRest rest;
  final ChatLink link;
  final ChatUser peer;

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
  bool peerTyping = false;

  StreamSubscription<ChatEvent>? _sub;
  bool _wasConnected = false;
  bool _disposed = false;
  int _localSeq = 0;
  int _lastReadSent = 0;
  DateTime? _lastTypingSent;
  Timer? _typingTimer;
  final Map<String, Timer> _pendingTimers = {};

  bool isMine(ChatMessage m) => m.sender != peer.id;

  // ── life cycle ────────────────────────────────────────────────────────

  Future<void> start() async {
    _sub = link.events.listen(_onEvent);
    _wasConnected = link.connected.value;
    link.connected.addListener(_onConnection);
    await _loadLatest(initial: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    link.connected.removeListener(_onConnection);
    _typingTimer?.cancel();
    for (final t in _pendingTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  // ── history ───────────────────────────────────────────────────────────

  Future<void> _ensureConversation() async {
    if (_convId != null) return;
    final conv = await rest.openConversation(peer.id);
    _convId ??= conv.id;
  }

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
    final mine = sender != peer.id;
    final ok = !mine || _messages.any((x) => x.clientId == clientId);
    if (ok) _convId = conversation;
    return ok;
  }

  void _onMessage(ChatMessage m) {
    if (!_adopt(m.conversation, sender: m.sender, clientId: m.clientId)) return;
    _pendingTimers.remove(m.clientId)?.cancel();
    _upsert(m);
    if (!isMine(m)) peerTyping = false;
    _changed();
    _markReadIfNeeded();
  }

  void _onTyping(Map<String, dynamic> d) {
    final user = (d['user'] as num?)?.toInt();
    final conv = (d['conversation'] as num?)?.toInt();
    if (user != peer.id || conv == null) return;
    if (!_adopt(conv, sender: peer.id)) return;
    peerTyping = true;
    _typingTimer?.cancel();
    _typingTimer = Timer(typingTimeout, () {
      peerTyping = false;
      _changed();
    });
    _changed();
  }

  void _onRead(Map<String, dynamic> d) {
    final conv = (d['conversation'] as num?)?.toInt();
    final reader = (d['reader'] as num?)?.toInt();
    final upTo = (d['up_to'] as num?)?.toInt() ?? 0;
    if (conv != _convId || reader != peer.id) return;
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
  void send(String text) {
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
