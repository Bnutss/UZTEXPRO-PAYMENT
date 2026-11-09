import 'package:flutter_test/flutter_test.dart';
import 'package:uztexpro_payment/features/chat/chat_forward.dart';
import 'package:uztexpro_payment/features/chat/chat_models.dart';

import 'chat_fakes.dart';

ChatMessage _msg(
  int id, {
  String kind = 'text',
  String albumId = '',
  int conversation = 1,
}) => ChatMessage(
  id: id,
  conversation: conversation,
  sender: 2,
  text: 'text $id',
  clientId: 'c$id',
  createdAt: DateTime(2026),
  read: false,
  kind: kind,
  albumId: albumId,
  media: kind == 'image' || kind == 'video' || kind == 'file'
      ? ChatMedia(name: 'p$id.jpg')
      : null,
);

ChatConversation _chat(int id, {bool group = false}) => ChatConversation(
  id: id,
  peer: ChatUser(id: group ? -id : 10 + id, name: 'Chat $id'),
  lastMessage: null,
  unread: 0,
  updatedAt: DateTime(2026),
  isGroup: group,
);

void main() {
  test('a message goes into every picked chat, once each', () async {
    final rest = FakeRest();
    final result = await ChatForwarder(rest).forward(
      [_msg(5)],
      [ForwardTarget.chat(_chat(1)), ForwardTarget.chat(_chat(2, group: true))],
    );
    expect(result.sent, 2);
    expect(result.failed, 0);
    expect(result.chatIds, [1, 2]);
    expect(rest.forwardCalls.map((c) => c.split(':').take(2).join(':')), [
      '1:5',
      '2:5',
    ]);
    // every copy has its own client id (a retry of one is saved once, two are not one)
    final ids = rest.forwardCalls.map((c) => c.split(':')[2]).toSet();
    expect(ids.length, 2);
  });

  test('a person with no chat yet: the chat is opened first', () async {
    final rest = FakeRest();
    final result = await ChatForwarder(rest).forward(
      [_msg(5)],
      [ForwardTarget.person(const ChatUser(id: 33, name: 'New'))],
    );
    expect(result.sent, 1);
    expect(rest.forwardCalls.single.startsWith('${result.chatIds.single}:5:'), isTrue);
  });

  test('messages still being sent, and service lines, are not forwarded', () async {
    final rest = FakeRest();
    final local = _msg(-3);
    final system = _msg(6, kind: 'system');
    final result = await ChatForwarder(rest).forward(
      [local, system, _msg(7)],
      [ForwardTarget.chat(_chat(1))],
    );
    expect(result.sent, 1);
    expect(rest.forwardCalls.single.split(':')[1], '7');
  });

  test('a file the server dropped, and not on this phone: counted as failed', () async {
    final rest = FakeRest()..goneForwards.add(9);
    final result = await ChatForwarder(rest).forward(
      [_msg(9, kind: 'image')],
      [ForwardTarget.chat(_chat(1))],
    );
    expect(result.failed, 1);
    expect(result.sent, 0);
    expect(rest.mediaCalls, isEmpty); // nothing to upload
  });

  test('a text that the server refuses is a failure, not a crash', () async {
    final rest = FakeRest()..goneForwards.add(5); // a 410 for a text: not retried
    final result = await ChatForwarder(rest).forward(
      [_msg(5)],
      [ForwardTarget.chat(_chat(1))],
    );
    expect(result.failed, 1);
  });

  test('the same chat or person twice is one target', () {
    expect(ForwardTarget.chat(_chat(1)).key, ForwardTarget.chat(_chat(1)).key);
    expect(
      ForwardTarget.person(const ChatUser(id: 4, name: 'A')).key,
      isNot(ForwardTarget.chat(_chat(4)).key),
    );
  });

  test('"forward" in the message JSON', () {
    final plain = ChatMessage.fromJson({
      'id': 1,
      'conversation': 1,
      'sender': 2,
      'text': 'x',
      'created_at': '2026-11-09T10:00:00+05:00',
      'forward': null,
    });
    expect(plain.forward, isNull);
    final fwd = ChatMessage.fromJson({
      'id': 2,
      'conversation': 1,
      'sender': 2,
      'text': 'x',
      'created_at': '2026-11-09T10:00:00+05:00',
      'forward': {'name': 'Anna Karimova', 'user': 7},
    });
    expect(fwd.forward?.name, 'Anna Karimova');
    expect(fwd.forward?.userId, 7);
    // a copy of the message (a new id when the server confirms it) keeps it
    expect(fwd.copyWith(id: 99).forward?.name, 'Anna Karimova');
  });
}
