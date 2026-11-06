import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uztexpro_payment/features/chat/chat_hub.dart';
import 'package:uztexpro_payment/features/chat/chat_sounds.dart';

import 'chat_fakes.dart';

class _FakePlayer implements ChatSoundPlayer {
  final played = <String>[];
  @override
  Future<void> play(String asset) async => played.add(asset);
}

class _NoIdRest extends FakeRest {
  @override
  int? get myId => null;
}

Future<void> pump([int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Map<String, dynamic> incoming(int id, {int sender = peerId}) =>
    json(msg(id, sender, 'hi'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLink link;
  late FakeRest rest;
  late ChatHub hub;

  Future<void> make({FakeRest? r}) async {
    link = FakeLink();
    rest = r ?? FakeRest();
    hub = ChatHub(api: rest, link: link);
    hub.start();
    await pump();
  }

  tearDown(() => hub.dispose());

  test('starts with the server count', () async {
    rest = FakeRest()..unreadOnServer = 4;
    link = FakeLink();
    hub = ChatHub(api: rest, link: link)..start();
    await pump();
    expect(hub.unread.value, 4);
  });

  test(
    'a message from somebody else raises the count; my own echo does not',
    () async {
      await make();
      link.emit('message', incoming(1));
      await pump();
      link.emit('message', incoming(2));
      await pump();
      expect(hub.unread.value, 2);

      link.emit(
        'message',
        incoming(3, sender: meId),
      ); // sent by me from another device
      await pump();
      expect(hub.unread.value, 2);
    },
  );

  test('typing / read events do not count', () async {
    await make();
    link.emit('typing', {'conversation': convId, 'user': peerId});
    link.emit('read', {'conversation': convId, 'reader': peerId, 'up_to': 3});
    await pump();
    expect(hub.unread.value, 0);
  });

  test(
    'chat window open: the number follows the server (debounced), a sound plays for the other person only',
    () async {
      final player = _FakePlayer();
      rest = FakeRest();
      link = FakeLink();
      hub = ChatHub(
        api: rest,
        link: link,
        sounds: ChatSounds(player, incomingGap: Duration.zero),
        refreshDelay: const Duration(milliseconds: 30),
      )..start();
      await pump();
      hub.chatOpen = true;
      final calls = rest.unreadCalls;

      link.emit('message', incoming(1));
      link.emit('message', incoming(2));
      await pump();
      expect(
        hub.unread.value,
        0,
      ); // not guessed: the open conversation reads them
      expect(player.played, [kIncomingSound, kIncomingSound]);

      link.emit('message', incoming(3, sender: meId)); // my own echo: no sound
      await pump();
      expect(player.played.length, 2);

      rest.unreadOnServer = 1; // one of them was read in the open conversation
      await Future<void>.delayed(const Duration(milliseconds: 90));
      expect(
        rest.unreadCalls,
        calls + 1,
      ); // a burst of three events: ONE request
      expect(hub.unread.value, 1);
    },
  );

  test(
    'chat window closed: the count grows locally and there is no sound (badge only)',
    () async {
      final player = _FakePlayer();
      rest = FakeRest();
      link = FakeLink();
      hub = ChatHub(api: rest, link: link, sounds: ChatSounds(player))..start();
      await pump();
      link.emit('message', incoming(1));
      await pump();
      expect(hub.unread.value, 1);
      expect(player.played, isEmpty);
    },
  );

  test('closing the window asks the server for the number', () async {
    await make();
    hub.chatOpen = true;
    rest.unreadOnServer = 2;
    final calls = rest.unreadCalls;
    hub.chatOpen = false;
    await pump();
    expect(rest.unreadCalls, calls + 1);
    expect(hub.unread.value, 2);
  });

  test('requestRefresh makes one request for a burst of calls', () async {
    rest = FakeRest()..unreadOnServer = 4;
    link = FakeLink();
    hub = ChatHub(
      api: rest,
      link: link,
      refreshDelay: const Duration(milliseconds: 20),
    )..start();
    await pump();
    final calls = rest.unreadCalls;
    hub.requestRefresh();
    hub.requestRefresh();
    hub.requestRefresh();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(rest.unreadCalls, calls + 1);
    expect(hub.unread.value, 4);
  });

  test('opening and closing twice in a row asks once per close', () async {
    await make();
    final calls = rest.unreadCalls;
    hub.chatOpen = true;
    hub.chatOpen = true;
    hub.chatOpen = false;
    hub.chatOpen = false;
    await pump();
    expect(rest.unreadCalls, calls + 1);
  });

  test(
    'the socket coming back refreshes from the server (messages missed meanwhile)',
    () async {
      await make();
      link.online = false;
      rest.unreadOnServer = 3;
      link.online = true;
      await pump();
      expect(hub.unread.value, 3);
    },
  );

  test('back from the background asks the server', () async {
    await make();
    rest.unreadOnServer = 5;
    hub.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pump();
    expect(hub.unread.value, 5);
  });

  test('a server failure keeps the last known number', () async {
    rest = FakeRest()..unreadOnServer = 2;
    link = FakeLink();
    hub = ChatHub(api: rest, link: link)..start();
    await pump();
    expect(hub.unread.value, 2);
    rest.failUnread = true;
    await hub.refresh();
    expect(hub.unread.value, 2);
  });

  test('"denied" (removed from the group) clears the badge', () async {
    rest = FakeRest()..unreadOnServer = 7;
    link = FakeLink();
    hub = ChatHub(api: rest, link: link)..start();
    await pump();
    link.emit('denied', {'code': 4403});
    await pump();
    expect(hub.unread.value, 0);
  });

  test(
    'without my user id in the token, a message makes it ask the server instead of guessing',
    () async {
      rest = _NoIdRest()..unreadOnServer = 1;
      link = FakeLink();
      hub = ChatHub(api: rest, link: link)..start();
      await pump();
      final calls = rest.unreadCalls;
      rest.unreadOnServer = 2;
      link.emit('message', incoming(1, sender: meId));
      await pump();
      expect(rest.unreadCalls, calls + 1);
      expect(hub.unread.value, 2);
    },
  );

  test('dispose is safe twice and later events are ignored', () async {
    await make();
    hub.dispose();
    hub.dispose();
    link.emit('message', incoming(9)); // must not throw
    await pump();
  });
}
