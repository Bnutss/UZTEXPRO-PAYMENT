import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uztexpro_payment/features/chat/chat_socket.dart';

/// A real WebSocket server on localhost, to see the client behave on the wire.
class TestServer {
  late final HttpServer http;
  final sockets = <WebSocket>[];
  final received = <Map<String, dynamic>>[];
  int connections = 0;

  /// 0 = accept; otherwise close the socket right after the handshake with it.
  int closeWith = 0;

  /// Answer app-level pings (the client's "is it alive" check).
  bool answerPing = true;

  /// Refuse the handshake with HTTP 403 (what the server does for a bad token).
  bool refuseHandshake = false;

  int get port => http.port;

  Future<void> start() async {
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen((req) async {
      connections++;
      if (refuseHandshake) {
        req.response.statusCode = 403;
        await req.response.close();
        return;
      }
      final ws = await WebSocketTransformer.upgrade(req);
      sockets.add(ws);
      if (closeWith != 0) {
        await ws.close(closeWith);
        return;
      }
      ws.listen((raw) {
        final m = jsonDecode(raw as String) as Map<String, dynamic>;
        received.add(m);
        if (m['action'] == 'ping' && answerPing)
          ws.add(jsonEncode({'event': 'pong'}));
      });
    });
  }

  void push(String event, Map<String, dynamic> data) =>
      sockets.last.add(jsonEncode({'event': event, 'data': data}));

  Future<void> dropAll() async {
    for (final s in sockets) {
      await s.close(1011); // abnormal for the client: it must reconnect
    }
    sockets.clear();
  }

  Future<void> stop() async {
    for (final s in sockets) {
      await s.close();
    }
    await http.close(force: true);
  }
}

Future<void> until(bool Function() cond, {int ms = 3000}) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (!cond()) {
    if (DateTime.now().isAfter(end))
      fail('timed out waiting for the condition');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

ChatSocket client(TestServer s) => ChatSocket(
  'tok',
  url: Uri.parse('ws://127.0.0.1:${s.port}/ws/chat/?token=tok'),
  minBackoff: const Duration(milliseconds: 30),
  maxBackoff: const Duration(milliseconds: 120),
);

void main() {
  late TestServer server;
  late ChatSocket socket;

  setUp(() async {
    server = TestServer();
    await server.start();
    socket = client(server); // idle until a test starts its own
  });
  tearDown(() async {
    socket.dispose();
    await server.stop();
  });

  test('the default URL is wss://<api host>/ws/chat/?token=…', () {
    final u = ChatSocket.defaultUrl('abc');
    expect(u.scheme, 'wss');
    expect(u.host, 'pro.uztex.uz');
    expect(u.path, '/ws/chat/');
    expect(u.queryParameters, {'token': 'abc'});
  });

  test(
    'connects, receives events, sends actions in the server format',
    () async {
      socket = client(server)..start();
      final got = <ChatEvent>[];
      socket.events.listen(got.add);
      await until(() => socket.connected.value);

      server.push('message', {'id': 1, 'text': 'hi'});
      server.push('typing', {'conversation': 5, 'user': 3});
      await until(() => got.length == 2);
      expect(got.map((e) => e.type), ['message', 'typing']);
      expect(got.first.data['text'], 'hi');

      expect(
        socket.sendMessage(conversation: 5, text: 'yo', clientId: 'c1'),
        isTrue,
      );
      expect(socket.sendMessage(to: 3, text: 'first', clientId: 'c2'), isTrue);
      socket.typing(5);
      socket.read(5, 9);
      await until(() => server.received.length == 4);
      expect(server.received, [
        {'action': 'send', 'conversation': 5, 'text': 'yo', 'client_id': 'c1'},
        {'action': 'send', 'to': 3, 'text': 'first', 'client_id': 'c2'},
        {'action': 'typing', 'conversation': 5},
        {'action': 'read', 'conversation': 5, 'up_to': 9},
      ]);
    },
  );

  test(
    'sending while not connected returns false (the caller falls back to HTTP)',
    () {
      socket = client(server); // not started
      expect(socket.connected.value, isFalse);
      expect(
        socket.sendMessage(conversation: 1, text: 'x', clientId: 'c'),
        isFalse,
      );
    },
  );

  test(
    'a dropped connection is re-established by itself; the app is told both ways',
    () async {
      socket = client(server)..start();
      final states = <bool>[];
      socket.connected.addListener(() => states.add(socket.connected.value));
      await until(() => socket.connected.value);
      expect(server.connections, 1);

      await server.dropAll();
      await until(() => server.connections >= 2 && socket.connected.value);
      expect(states, containsAllInOrder([false, true]));

      // and it works again after the return
      final got = <ChatEvent>[];
      socket.events.listen(got.add);
      server.push('message', {'id': 2});
      await until(() => got.isNotEmpty);
    },
  );

  test(
    'the server being unreachable is retried with a pause, then connects when it is back',
    () async {
      final port = server.port;
      await server.stop();
      socket = ChatSocket(
        'tok',
        url: Uri.parse('ws://127.0.0.1:$port/ws/chat/?token=tok'),
        minBackoff: const Duration(milliseconds: 30),
        maxBackoff: const Duration(milliseconds: 100),
      )..start();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(socket.connected.value, isFalse);

      server = TestServer();
      server.http = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      server.http.listen((req) async {
        server.connections++;
        server.sockets.add(await WebSocketTransformer.upgrade(req));
      });
      await until(() => socket.connected.value);
    },
  );

  test(
    '4403 (not in the chat group) is final: reported as "denied", no reconnect loop',
    () async {
      server.closeWith = 4403;
      socket = client(server);
      final got = <ChatEvent>[];
      socket.events.listen(got.add);
      socket.start();
      await until(() => got.any((e) => e.type == 'denied'));
      expect(got.firstWhere((e) => e.type == 'denied').data['code'], 4403);
      expect(socket.denied, isTrue);
      final n = server.connections;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(server.connections, n); // it did not try again
      expect(socket.connected.value, isFalse);
    },
  );

  test(
    'a refused handshake (bad token, HTTP 403) keeps retrying quietly instead of crashing',
    () async {
      server.refuseHandshake = true;
      socket = client(server)..start();
      await until(() => server.connections >= 3);
      expect(socket.connected.value, isFalse);
    },
  );

  test('ensureAlive: a live socket answers the ping and stays', () async {
    socket = client(server)..start();
    await until(() => socket.connected.value);
    await socket.ensureAlive();
    expect(socket.connected.value, isTrue);
    expect(server.received.any((m) => m['action'] == 'ping'), isTrue);
  });

  test('ensureAlive: a silent (dead) socket is dropped and replaced', () async {
    server.answerPing = false;
    socket = client(server)..start();
    await until(() => socket.connected.value);
    expect(server.connections, 1);
    final check = socket.ensureAlive(); // the ping goes unanswered …
    await Future<void>.delayed(const Duration(milliseconds: 150));
    server.answerPing = true; // … and the new connection will work
    await check; // no pong within 3 s → reconnect
    await until(
      () => server.connections >= 2 && socket.connected.value,
      ms: 6000,
    );
  }, timeout: const Timeout(Duration(seconds: 15)));

  test('dispose stops everything, no reconnect afterwards', () async {
    socket = client(server)..start();
    await until(() => socket.connected.value);
    socket.dispose();
    final n = server.connections;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(server.connections, n);
  });
}
