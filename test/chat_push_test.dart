import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uztexpro_payment/features/chat/chat_push.dart';

import 'chat_fakes.dart';

class _Push implements PushClient {
  String? token = 'device-token-1';
  bool failRegister = false;
  int registered = 0;
  int badgeCleared = 0;
  void Function(Map<String, dynamic>)? tap;

  @override
  Future<String?> register() async {
    registered++;
    if (failRegister) throw StateError('permission denied');
    return token;
  }

  @override
  void onTap(void Function(Map<String, dynamic> data) listener) =>
      tap = listener;

  @override
  void clearBadge() => badgeCleared++;
}

Map<String, dynamic> chatPush({
  Object? conversation = 5,
  Object? sender = 3,
  String name = 'Anna',
}) => {
  'type': 'chat',
  'title': name,
  'message': 'hi',
  'conversation': conversation,
  'sender': sender,
  'sender_name': name,
  'message_id': 77,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('which chat a tapped push leads to', () {
    test('a chat push gives the conversation and the person', () {
      final t = parseChatPush(chatPush())!;
      expect(t.conversationId, 5);
      expect(t.peer.id, 3);
      expect(t.peer.name, 'Anna');
    });

    test('ids may arrive as strings (the SDK passes data through JSON)', () {
      final t = parseChatPush(chatPush(conversation: '5', sender: '3'))!;
      expect(t.conversationId, 5);
      expect(t.peer.id, 3);
    });

    test('not a chat push, or missing ids: nothing to open', () {
      expect(
        parseChatPush({'type': 'other', 'conversation': 5, 'sender': 3}),
        isNull,
      );
      expect(parseChatPush({'type': 'chat', 'sender': 3}), isNull);
      expect(parseChatPush({'type': 'chat', 'conversation': 5}), isNull);
      expect(
        parseChatPush({'type': 'chat', 'conversation': 'x', 'sender': 3}),
        isNull,
      );
      expect(parseChatPush({}), isNull);
    });

    test('the name falls back to the title', () {
      final data = chatPush()..remove('sender_name');
      expect(parseChatPush(data)!.peer.name, 'Anna');
    });
  });

  group('is the app open', () {
    final now = DateTime(2026, 11, 6, 12);
    int ago(Duration d) => now.subtract(d).millisecondsSinceEpoch;

    test('a fresh heartbeat means open, a stale or missing one means not', () {
      expect(
        PushForeground.isForeground(ago(const Duration(seconds: 5)), now),
        isTrue,
      );
      expect(
        PushForeground.isForeground(ago(const Duration(seconds: 44)), now),
        isTrue,
      );
      expect(
        PushForeground.isForeground(ago(const Duration(seconds: 46)), now),
        isFalse,
      );
      expect(
        PushForeground.isForeground(ago(const Duration(hours: 3)), now),
        isFalse,
      ); // app was killed
      expect(PushForeground.isForeground(null, now), isFalse);
    });

    test(
      'a little clock skew is tolerated, a heartbeat from the far future is not',
      () {
        expect(
          PushForeground.isForeground(
            now.add(const Duration(seconds: 3)).millisecondsSinceEpoch,
            now,
          ),
          isTrue,
        );
        expect(
          PushForeground.isForeground(
            now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
            now,
          ),
          isFalse,
        );
      },
    );
  });

  group('the service', () {
    late FakeRest rest;
    late _Push push;
    late ChatPushService svc;

    setUp(() {
      rest = FakeRest();
      push = _Push();
      svc = ChatPushService(api: rest, client: push, platform: 'ios');
    });
    tearDown(() => svc.dispose());

    test(
      'start registers this phone with the backend (token + platform)',
      () async {
        await svc.start();
        expect(rest.registeredTokens, ['ios:device-token-1']);
        expect(svc.token, 'device-token-1');
      },
    );

    test(
      'no permission / no token / no network: nothing breaks, nothing is registered',
      () async {
        push.failRegister = true;
        await svc.start(); // must not throw
        expect(rest.registeredTokens, isEmpty);
        expect(svc.token, isNull);

        final svc2 = ChatPushService(
          api: rest,
          client: _Push()..token = null,
          platform: 'android',
        );
        await svc2.start();
        expect(rest.registeredTokens, isEmpty);
        svc2.dispose();

        rest.failRegister = true;
        final svc3 = ChatPushService(
          api: rest,
          client: _Push(),
          platform: 'android',
        );
        await svc3.start(); // the backend is down
        expect(svc3.token, isNull);
        svc3.dispose();
      },
    );

    test('stop (logout) removes the token on the backend, once', () async {
      await svc.start();
      await svc.stop();
      expect(rest.removedTokens, ['device-token-1']);
      await svc.stop();
      expect(rest.removedTokens, ['device-token-1']); // nothing left to remove
    });

    test('stop without a registered token does nothing', () async {
      push.failRegister = true;
      await svc.start();
      await svc.stop();
      expect(rest.removedTokens, isEmpty);
    });

    test(
      'tapping a chat notification asks to open that conversation',
      () async {
        await svc.start();
        ChatPushTarget? got;
        svc.openRequest.addListener(() => got = svc.openRequest.value);
        push.tap!(chatPush(conversation: 9, sender: 4, name: 'Bob'));
        expect(got!.conversationId, 9);
        expect(got!.peer.id, 4);
        expect(got!.peer.name, 'Bob');
      },
    );

    test('tapping something else, or the same chat twice, behaves', () async {
      await svc.start();
      var n = 0;
      svc.openRequest.addListener(() => n++);
      push.tap!({'type': 'promo'});
      expect(n, 0);
      push.tap!(chatPush());
      push.tap!(chatPush()); // a second tap on the same chat opens it again
      expect(n, 2);
    });

    test('clearBadge reaches the SDK', () async {
      svc.clearBadge();
      expect(push.badgeCleared, 1);
    });

    test(
      'lifecycle: leaving the app and coming back does not break it',
      () async {
        await svc.start();
        svc.didChangeAppLifecycleState(AppLifecycleState.paused);
        svc.didChangeAppLifecycleState(AppLifecycleState.resumed);
        svc.didChangeAppLifecycleState(AppLifecycleState.inactive);
        svc.didChangeAppLifecycleState(AppLifecycleState.resumed);
      },
    );

    test('dispose is safe twice and a late tap is ignored', () async {
      await svc.start();
      svc.dispose();
      svc.dispose();
      expect(() => push.tap!(chatPush()), returnsNormally);
    });
  });
}
