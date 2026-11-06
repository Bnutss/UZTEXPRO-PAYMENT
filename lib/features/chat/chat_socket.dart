import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:uztexpro_payment/main.dart' show API;

/// One event from the server: `message`, `typing`, `read`, `error`, or the
/// local `denied` (the server refused this user: bad token / not in the group).
class ChatEvent {
  const ChatEvent(this.type, this.data);
  final String type;
  final Map<String, dynamic> data;
}

/// What the conversation logic needs from the live connection (a seam for
/// tests).
abstract class ChatLink {
  Stream<ChatEvent> get events;

  /// True while the socket is open.
  ValueListenable<bool> get connected;

  /// Hands a message to the socket; false when it is not open (the caller then
  /// falls back to HTTP). Either [conversation] or [to] (a user id, for a first
  /// message).
  bool sendMessage({
    int? conversation,
    int? to,
    required String text,
    required String clientId,
    int? replyTo,
  });

  void typing(int conversation);
  void read(int conversation, int upTo);
}

/// The chat WebSocket: `wss://<host>/ws/chat/?token=<jwt>`.
///
/// It reconnects by itself with a growing pause (1 s, 2 s, 4 s … 30 s), is
/// kept alive by protocol pings, and tells the app when it is open
/// ([connected]) so that the conversation can catch up on what it missed.
class ChatSocket implements ChatLink {
  ChatSocket(
    String token, {
    Uri? url,
    this.minBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(seconds: 30),
  }) : _url = url ?? defaultUrl(token);

  /// `https://pro.uztex.uz/api/v1` → `wss://pro.uztex.uz/ws/chat/?token=...`
  static Uri defaultUrl(String token) {
    final api = Uri.parse(API);
    return Uri(
      scheme: api.scheme == 'http' ? 'ws' : 'wss',
      host: api.host,
      port: api.hasPort ? api.port : null,
      path: '/ws/chat/',
      queryParameters: {'token': token},
    );
  }

  final Uri _url;
  final Duration minBackoff;
  final Duration maxBackoff;

  final _events = StreamController<ChatEvent>.broadcast();
  @override
  Stream<ChatEvent> get events => _events.stream;

  final ValueNotifier<bool> _connected = ValueNotifier(false);
  @override
  ValueListenable<bool> get connected => _connected;

  WebSocket? _ws;
  Timer? _retry;
  int _attempt = 0;
  bool _started = false;
  bool _connecting = false;
  bool _disposed = false;
  bool _denied = false;
  Completer<void>? _pong;

  /// The server refused this user (4401 / 4403): no point in retrying.
  bool get denied => _denied;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _connect();
  }

  Future<void> _connect() async {
    if (_disposed || _connecting || _ws != null || _denied) return;
    _connecting = true;
    try {
      final ws = await WebSocket.connect(
        _url.toString(),
      ).timeout(const Duration(seconds: 10));
      if (_disposed) {
        await ws.close();
        return;
      }
      ws.pingInterval = const Duration(seconds: 20);
      _ws = ws;
      _attempt = 0;
      _connected.value = true;
      ws.listen(
        _onData,
        onDone: () => _onClosed(ws),
        onError: (_) => _onClosed(ws),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _onData(dynamic raw) {
    if (raw is! String) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    final type = decoded['event'] as String?;
    if (type == null) return;
    if (type == 'pong') {
      _pong?.complete();
      return;
    }
    final data = decoded['data'];
    _events.add(
      ChatEvent(type, data is Map ? data.cast<String, dynamic>() : const {}),
    );
  }

  void _onClosed(WebSocket ws) {
    if (!identical(ws, _ws)) return;
    final code = ws.closeCode;
    _ws = null;
    _connected.value = false;
    if (code == 4401 || code == 4403) {
      _denied = true;
      _events.add(ChatEvent('denied', {'code': code}));
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _denied) return;
    _retry?.cancel();
    final base = minBackoff.inMilliseconds * math.pow(2, _attempt);
    final ms = math.min(base.toInt(), maxBackoff.inMilliseconds);
    // A little jitter, so that every phone does not return at the same moment
    // after a server restart.
    final jitter = math.Random().nextInt(ms ~/ 4 + 1);
    _attempt = math.min(_attempt + 1, 16);
    _retry = Timer(Duration(milliseconds: ms + jitter), _connect);
  }

  /// Connect now instead of waiting for the next retry (back in the app, the
  /// network returned).
  void reconnectNow() {
    if (_disposed || _denied || _ws != null) return;
    _retry?.cancel();
    _attempt = 0;
    _connect();
  }

  /// After the app was in the background a socket can be dead without anybody
  /// noticing: ask the server, and reconnect when there is no answer.
  Future<void> ensureAlive() async {
    final ws = _ws;
    if (ws == null) {
      reconnectNow();
      return;
    }
    final pong = _pong = Completer<void>();
    ws.add(jsonEncode({'action': 'ping'}));
    try {
      await pong.future.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      if (identical(ws, _ws)) {
        _onClosed(ws);
        unawaited(ws.close());
      }
    }
  }

  bool _send(Map<String, dynamic> payload) {
    final ws = _ws;
    if (ws == null) return false;
    try {
      ws.add(jsonEncode(payload));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  bool sendMessage({
    int? conversation,
    int? to,
    required String text,
    required String clientId,
    int? replyTo,
  }) => _send({
    'action': 'send',
    if (conversation != null) 'conversation': conversation else 'to': to,
    'text': text,
    'client_id': clientId,
    if (replyTo != null) 'reply_to': replyTo,
  });

  @override
  void typing(int conversation) =>
      _send({'action': 'typing', 'conversation': conversation});

  @override
  void read(int conversation, int upTo) =>
      _send({'action': 'read', 'conversation': conversation, 'up_to': upTo});

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _retry?.cancel();
    final ws = _ws;
    _ws = null;
    ws?.close(WebSocketStatus.normalClosure);
    _events.close();
    _connected.dispose();
  }
}
