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

void main() {
  group('models', () {
    test('a group in the list: a stand-in "peer" carries title and photo', () {
      final c = ChatConversation.fromJson({
        'id': 7,
        'kind': 'group',
        'title': 'Sewing shop',
        'photo': 'http://x/p.jpg',
        'members_count': 4,
        'my_role': 'admin',
        'unread': 2,
        'muted': true,
        'peer': null,
        'last_message': null,
        'updated_at': '2026-11-07T10:00:00+05:00',
      });
      expect(c.isGroup, isTrue);
      expect(c.peer.name, 'Sewing shop');
      expect(c.peer.photo, 'http://x/p.jpg');
      expect(c.peer.id, -7); // never a real user's id
      expect(c.peer.shortName, 'Sewing shop'); // not "Sewing s."
      expect(c.membersCount, 4);
      expect(c.isAdmin, isTrue);
      expect(c.muted, isTrue);
    });

    test('a personal chat is unchanged', () {
      final c = ChatConversation.fromJson({
        'id': 1,
        'kind': 'direct',
        'peer': {'id': 3, 'name': 'Anna Petrova Ivanovna'},
        'unread': 0,
        'updated_at': '2026-11-07T10:00:00+05:00',
      });
      expect(c.isGroup, isFalse);
      expect(c.peer.id, 3);
      expect(c.peer.shortName, 'Anna P.');
    });

    test('members of a group card carry a role', () {
      final c = ChatConversation.fromJson({
        'id': 7,
        'kind': 'group',
        'title': 'G',
        'updated_at': '2026-11-07T10:00:00+05:00',
        'members': [
          {'id': 1, 'name': 'A', 'role': 'owner'},
          {'id': 2, 'name': 'B', 'role': 'admin'},
          {'id': 3, 'name': 'C', 'role': 'member'},
        ],
      });
      expect(c.members.map((m) => m.isOwner), [true, false, false]);
      expect(c.members.map((m) => m.isAdmin), [true, true, false]);
      expect(c.membersCount, 3);
    });

    test('a service line and a sender name are read', () {
      final m = ChatMessage.fromJson({
        'id': 1,
        'conversation': 7,
        'sender': 2,
        'text': 'B added C',
        'created_at': '2026-11-07T10:00:00+05:00',
        'kind': 'system',
        'event': 'added',
        'payload': {'actor': 2, 'actor_name': 'B', 'user': 3, 'user_name': 'C'},
        'sender_name': 'B',
      });
      expect(m.isSystem, isTrue);
      expect(m.event, 'added');
      expect(m.payload!['user_name'], 'C');
      expect(m.senderName, 'B');
    });
  });

  group('a group chat', () {
    late FakeLink link;
    late FakeRest rest;
    late ChatThreadController c;
    const gid = 40;
    final groupPeer = ChatUser.groupStandIn(gid, 'Team', null);

    setUp(() {
      link = FakeLink();
      rest = FakeRest();
      c = ChatThreadController(
        rest: rest,
        link: link,
        peer: groupPeer,
        conversationId: gid,
        isGroup: true,
        typingTimeout: const Duration(milliseconds: 60),
      );
    });
    tearDown(() => c.dispose());

    test('"mine" is decided by my id, not by "not the peer"', () async {
      rest.store.addAll([
        msg(1, 3, 'from anna', conv: gid),
        msg(2, meId, 'mine', conv: gid),
        msg(3, 4, 'from carl', conv: gid),
      ]);
      await c.start();
      await pump();
      expect(c.messages.map(c.isMine), [false, true, false]);
    });

    test(
      'it loads the card of the group (not an "open chat" request)',
      () async {
        await c.start();
        await pump();
        expect(rest.groupCalls, contains('group:$gid'));
        expect(rest.opened, 0);
      },
    );

    test('several people can type at once; my own typing is ignored', () async {
      await c.start();
      link.emit('typing', {'conversation': gid, 'user': 3});
      link.emit('typing', {'conversation': gid, 'user': 4});
      link.emit('typing', {'conversation': gid, 'user': meId});
      await pump();
      expect(c.typingIds.toSet(), {3, 4});
      expect(c.peerTyping, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(c.peerTyping, isFalse);
    });

    test('a message stops that person typing, not the others', () async {
      await c.start();
      link.emit('typing', {'conversation': gid, 'user': 3});
      link.emit('typing', {'conversation': gid, 'user': 4});
      await pump();
      link.emit('message', {
        ...json(msg(9, 3, 'hi', conv: gid)),
        'sender_name': 'Anna',
      });
      await pump();
      expect(c.typingIds.toSet(), {4});
      expect(c.names[3], 'Anna');
    });

    test(
      'a read mark of somebody else ticks my messages; mine does not',
      () async {
        rest.store.addAll([
          msg(1, meId, 'one', conv: gid),
          msg(2, meId, 'two', conv: gid),
        ]);
        await c.start();
        await pump();
        link.emit('read', {'conversation': gid, 'reader': meId, 'up_to': 2});
        await pump();
        expect(c.messages.every((m) => !m.read), isTrue);
        link.emit('read', {'conversation': gid, 'reader': 3, 'up_to': 1});
        await pump();
        expect(c.messages.map((m) => m.read), [true, false]);
      },
    );

    test('events of another chat are ignored', () async {
      await c.start();
      link.emit('message', json(msg(9, 3, 'elsewhere', conv: 999)));
      link.emit('typing', {'conversation': 999, 'user': 3});
      await pump();
      expect(c.messages, isEmpty);
      expect(c.peerTyping, isFalse);
    });

    test('being removed or the group deleted closes the screen', () async {
      await c.start();
      link.emit('conversation_removed', {'conversation': 999});
      await pump();
      expect(c.removed, isFalse);
      link.emit('conversation_removed', {'conversation': gid});
      await pump();
      expect(c.removed, isTrue);
    });

    test('a change of the group reloads its card', () async {
      await c.start();
      await pump();
      rest.groupCalls.clear();
      link.emit('conversations_changed', {'conversation': gid});
      await pump();
      expect(rest.groupCalls, ['group:$gid']);
    });

    test('my message is sent into the group with no "to"', () async {
      await c.start();
      c.send('hello team');
      await pump();
      expect(link.sent.single['conversation'], gid);
      expect(link.sent.single['to'], isNull);
    });

    test('leaving the group closes it for me', () async {
      await c.start();
      expect(await c.leaveGroup(), isTrue);
      expect(rest.groupCalls, contains('remove:$gid:$meId'));
      expect(c.removed, isTrue);
    });

    test('a group that answers 404 is gone: the screen closes', () async {
      rest.groupGone = true;
      await c.start();
      await pump();
      expect(c.removed, isTrue);
    });

    test('deleting a group that is already gone still closes it', () async {
      await c.start();
      rest.groupGone = true;
      expect(await c.deleteGroup(), isTrue);
      expect(c.removed, isTrue);
    });

    test('an admin action reloads the card', () async {
      await c.start();
      await pump();
      rest.groupCalls.clear();
      expect(await c.addMembers([5, 6]), isTrue);
      expect(await c.setRole(5, 'admin'), isTrue);
      expect(await c.removeMember(6), isTrue);
      expect(rest.groupCalls.where((e) => e.startsWith('add')), ['add:$gid']);
      expect(rest.groupCalls.where((e) => e.startsWith('role')), [
        'role:$gid:5:admin',
      ]);
      expect(rest.groupCalls.where((e) => e.startsWith('remove')), [
        'remove:$gid:6',
      ]);
      expect(rest.groupCalls.where((e) => e.startsWith('group')).length, 3);
    });
  });
}
