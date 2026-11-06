import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:uztexpro_payment/features/chat/chat_models.dart';
import 'package:uztexpro_payment/features/chat/chat_thread_controller.dart';

import 'chat_fakes.dart';

Future<void> pump([int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late FakeLink link;
  late FakeRest rest;
  late ChatThreadController c;

  ChatThreadController make({int? conv = convId, int retryMs = 60}) =>
      ChatThreadController(
        rest: rest,
        link: link,
        peer: peer,
        conversationId: conv,
        retryAfter: Duration(milliseconds: retryMs),
        typingTimeout: const Duration(milliseconds: 60),
      );

  setUp(() {
    link = FakeLink();
    rest = FakeRest();
  });
  tearDown(() => c.dispose());

  group('opening', () {
    test(
      'loads the latest page oldest-first and marks the peer messages read over the socket',
      () async {
        rest.store.addAll([
          msg(1, peerId, 'a'),
          msg(2, meId, 'b'),
          msg(3, peerId, 'c'),
        ]);
        c = make();
        await c.start();
        expect(c.messages.map((m) => m.text), ['a', 'b', 'c']);
        expect(c.loading, isFalse);
        expect(link.readCalls, [
          [convId, 3],
        ]);
      },
    );

    test(
      'opened from a contact (no chat id yet): resolves the chat once, in the background',
      () async {
        rest.store.add(msg(1, peerId, 'hi'));
        c = make(conv: null);
        expect(c.conversationId, isNull);
        expect(c.loading, isTrue); // the screen is already up, showing a loader
        await c.start();
        expect(c.conversationId, convId);
        expect(rest.opened, 1);
        expect(c.messages.single.text, 'hi');
      },
    );

    test('a failed first load is reported and can be retried', () async {
      rest.failMessages = true;
      c = make();
      await c.start();
      expect(c.historyFailed, isTrue);
      expect(c.loading, isFalse);
      rest.failMessages = false;
      rest.store.add(msg(1, peerId, 'ok'));
      await c.reload();
      expect(c.historyFailed, isFalse);
      expect(c.messages.single.text, 'ok');
    });

    test('older pages are loaded on demand, without duplicates', () async {
      for (var i = 1; i <= 7; i++) {
        rest.store.add(msg(i, i.isEven ? meId : peerId, 'm$i'));
      }
      c = ChatThreadController(
        rest: rest,
        link: link,
        peer: peer,
        conversationId: convId,
        pageSize: 3,
      );
      await c.start();
      expect(c.messages.map((m) => m.id), [5, 6, 7]);
      expect(c.hasMore, isTrue);
      await c.loadMore();
      expect(c.messages.map((m) => m.id), [2, 3, 4, 5, 6, 7]);
      await c.loadMore();
      expect(c.messages.map((m) => m.id), [1, 2, 3, 4, 5, 6, 7]);
      expect(c.hasMore, isFalse);
      await c.loadMore(); // nothing more: no request, no change
      expect(c.messages.length, 7);
    });
  });

  group('sending', () {
    test(
      'the message is shown at once as "sending", and the socket echo confirms it (one message)',
      () async {
        c = make();
        await c.start();
        c.send('  hello  ');
        expect(c.messages.single.text, 'hello');
        expect(c.messages.single.state, ChatSendState.sending);
        expect(c.messages.single.isLocal, isTrue);
        expect(link.sent.single['conversation'], convId);
        expect(link.sent.single['to'], isNull);

        final cid = link.sent.single['client_id'] as String;
        link.emit('message', json(msg(100, meId, 'hello', cid: cid)));
        await pump();
        expect(c.messages.length, 1);
        expect(c.messages.single.id, 100);
        expect(c.messages.single.state, ChatSendState.sent);

        await wait(120); // the fallback timer must have been cancelled
        expect(rest.sentViaRest, 0);
      },
    );

    test('empty / blank text is ignored', () async {
      c = make();
      await c.start();
      c.send('   ');
      c.send('');
      expect(c.messages, isEmpty);
      expect(link.sent, isEmpty);
    });

    test('socket down: goes straight over HTTP', () async {
      c = make();
      await c.start();
      link.online = false;
      c.send('offline');
      await pump(10);
      expect(link.sent, isEmpty);
      expect(rest.sentViaRest, 1);
      expect(c.messages.single.state, ChatSendState.sent);
      expect(c.messages.single.id, greaterThan(0));
    });

    test(
      'no echo from the socket in time: sent again over HTTP with the same client id, shown once',
      () async {
        c = make(retryMs: 40);
        await c.start();
        c.send('slow');
        final cid = link.sent.single['client_id'];
        await wait(120);
        expect(rest.sentViaRest, 1);
        expect(rest.store.single.clientId, cid);
        expect(c.messages.length, 1);
        expect(c.messages.single.state, ChatSendState.sent);

        // the late socket echo arrives as well: still one message
        link.emit('message', json(rest.store.single));
        await pump();
        expect(c.messages.length, 1);
      },
    );

    test('HTTP failure marks the message failed; tapping retries it', () async {
      c = make();
      await c.start();
      link.online = false;
      rest.failSend = true;
      c.send('x');
      await pump(10);
      expect(c.messages.single.state, ChatSendState.failed);

      rest.failSend = false;
      c.retry(c.messages.single);
      expect(c.messages.single.state, ChatSendState.sending);
      await pump(10);
      expect(c.messages.single.state, ChatSendState.sent);
      expect(c.messages.length, 1);
    });

    test(
      'a server error event for a client id marks that message failed',
      () async {
        c = make();
        await c.start();
        c.send('bad');
        final cid = link.sent.single['client_id'] as String;
        link.emit('error', {'code': 'bad_recipient', 'client_id': cid});
        await pump();
        expect(c.messages.single.state, ChatSendState.failed);
        await wait(100);
        expect(rest.sentViaRest, 0); // no automatic fallback after a refusal
      },
    );

    test(
      'typed before the chat finished opening: sent "to" the user, the echo adopts the chat, no duplicate',
      () async {
        rest.openGate =
            Completer<void>(); // the server is slow to open the chat
        c = make(conv: null);
        final started = c.start();
        await pump();
        expect(c.conversationId, isNull);

        c.send('first');
        expect(c.messages.single.state, ChatSendState.sending);
        expect(link.sent.single['to'], peerId);
        expect(link.sent.single['conversation'], isNull);

        final cid = link.sent.single['client_id'] as String;
        link.emit('message', json(msg(50, meId, 'first', cid: cid)));
        await pump();
        expect(c.conversationId, convId);
        expect(c.messages.single.state, ChatSendState.sent);

        rest.openGate!.complete(); // the open finally returns
        await started;
        expect(c.messages.length, 1);
        expect(c.conversationId, convId);
        expect(rest.sentViaRest, 0);
      },
    );

    test(
      'an echo for a message I did not send from here is ignored while the chat is unknown',
      () async {
        rest.openGate = Completer<void>();
        c = make(conv: null);
        final started = c.start();
        await pump();
        // I wrote to somebody else from another device
        link.emit(
          'message',
          json(msg(60, meId, 'to someone else', cid: 'other', conv: 77)),
        );
        await pump();
        expect(c.messages, isEmpty);
        expect(c.conversationId, isNull);
        rest.openGate!.complete();
        await started;
      },
    );

    test(
      'local messages stay below server ones, in the order they were typed',
      () async {
        rest.store.add(msg(1, peerId, 'old'));
        c = make();
        await c.start();
        link.online = false;
        rest.failSend = true;
        c.send('one');
        c.send('two');
        await pump(10);
        link.emit('message', json(msg(2, peerId, 'new from peer')));
        await pump();
        expect(c.messages.map((m) => m.text), [
          'old',
          'new from peer',
          'one',
          'two',
        ]);
      },
    );
  });

  group('read marks', () {
    test(
      'onReadMarked fires when the peer\'s messages are marked read, once per new message',
      () async {
        var marked = 0;
        c = ChatThreadController(
          rest: rest,
          link: link,
          peer: peer,
          conversationId: convId,
          onReadMarked: () => marked++,
        );
        rest.store.add(msg(1, peerId, 'a'));
        await c.start();
        expect(marked, 1);
        link.emit('message', json(msg(2, peerId, 'b')));
        await pump();
        expect(marked, 2);
        link.emit('message', json(msg(2, peerId, 'b'))); // duplicate event
        await pump();
        expect(marked, 2);
        link.emit(
          'message',
          json(msg(3, meId, 'mine')),
        ); // my own: nothing to mark
        await pump();
        expect(marked, 2);
      },
    );
  });

  group('live events', () {
    test(
      'a message of the peer appears and is marked read; another chat is ignored',
      () async {
        c = make();
        await c.start();
        link.emit('message', json(msg(10, peerId, 'hey')));
        await pump();
        expect(c.messages.single.text, 'hey');
        expect(link.readCalls.last, [convId, 10]);
        link.emit('message', json(msg(11, 99, 'elsewhere', conv: 77)));
        await pump();
        expect(c.messages.length, 1);
      },
    );

    test(
      'the read mark is sent once per new message, and over HTTP when the socket is down',
      () async {
        c = make();
        await c.start();
        link.emit('message', json(msg(10, peerId, 'a')));
        await pump();
        link.emit('message', json(msg(10, peerId, 'a'))); // duplicate event
        await pump();
        expect(link.readCalls.length, 1);
        link.online = false;
        link.emit('message', json(msg(12, peerId, 'b')));
        await pump(10);
        expect(rest.readViaRest, [12]);
      },
    );

    test('the same message arriving twice is stored once', () async {
      c = make();
      await c.start();
      final e = json(msg(20, peerId, 'dup'));
      link.emit('message', e);
      link.emit('message', e);
      await pump();
      expect(c.messages.length, 1);
    });

    test(
      '"read" by the peer turns my messages read up to that id only',
      () async {
        rest.store.addAll([
          msg(1, meId, 'a'),
          msg(2, meId, 'b'),
          msg(3, meId, 'c'),
        ]);
        c = make();
        await c.start();
        expect(c.messages.every((m) => !m.read), isTrue);
        link.emit('read', {
          'conversation': convId,
          'reader': peerId,
          'up_to': 2,
        });
        await pump();
        expect(c.messages.map((m) => m.read), [true, true, false]);
        // someone else's read, or another chat: no effect
        link.emit('read', {'conversation': convId, 'reader': 99, 'up_to': 3});
        link.emit('read', {'conversation': 77, 'reader': peerId, 'up_to': 3});
        await pump();
        expect(c.messages.last.read, isFalse);
      },
    );

    test(
      '"typing" shows and fades by itself; a message clears it at once',
      () async {
        c = make();
        await c.start();
        link.emit('typing', {'conversation': convId, 'user': peerId});
        await pump();
        expect(c.peerTyping, isTrue);
        await wait(120);
        expect(c.peerTyping, isFalse);

        link.emit('typing', {'conversation': convId, 'user': peerId});
        await pump();
        link.emit('message', json(msg(30, peerId, 'done')));
        await pump();
        expect(c.peerTyping, isFalse);

        link.emit('typing', {
          'conversation': convId,
          'user': 99,
        }); // not the peer
        await pump();
        expect(c.peerTyping, isFalse);
      },
    );

    test(
      'my own typing is sent at most every 2.5 s and never for empty text',
      () async {
        c = make();
        await c.start();
        c.onTextChanged('');
        c.onTextChanged('   ');
        expect(link.typingCalls, isEmpty);
        c.onTextChanged('h');
        c.onTextChanged('he');
        c.onTextChanged('hel');
        expect(link.typingCalls, [convId]);
        link.online = false;
        c.onTextChanged('hell');
        expect(link.typingCalls.length, 1);
      },
    );
  });

  group('connection', () {
    test(
      'coming back online catches up on messages missed meanwhile, without duplicates',
      () async {
        rest.store.addAll([msg(1, peerId, 'a'), msg(2, meId, 'b')]);
        c = make();
        await c.start();
        link.online = false;
        // while offline the peer wrote twice and read my message
        rest.store.addAll([
          msg(3, peerId, 'missed 1'),
          msg(4, peerId, 'missed 2'),
        ]);
        rest.store[1] = msg(2, meId, 'b', read: true);
        link.online = true;
        await pump(10);
        expect(c.messages.map((m) => m.text), [
          'a',
          'b',
          'missed 1',
          'missed 2',
        ]);
        expect(c.messages[1].read, isTrue);
        expect(link.readCalls.last, [convId, 4]);
      },
    );

    test('a read flag never goes back from true to false on refresh', () async {
      rest.store.add(msg(1, meId, 'a'));
      c = make();
      await c.start();
      link.emit('read', {'conversation': convId, 'reader': peerId, 'up_to': 1});
      await pump();
      expect(c.messages.single.read, isTrue);
      link.online = false;
      link.online = true; // the server page still says read:false
      await pump(10);
      expect(c.messages.single.read, isTrue);
    });
  });
}
