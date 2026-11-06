import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uztexpro_payment/features/chat/chat_api.dart';
import 'package:uztexpro_payment/features/chat/chat_models.dart';
import 'package:uztexpro_payment/features/chat/chat_socket.dart';

/// Test doubles shared by the chat tests.
const peerId = 3;
const meId = 8;
const convId = 5;
const peer = ChatUser(id: peerId, name: 'Anna');

ChatMessage msg(
  int id,
  int sender,
  String text, {
  String cid = '',
  bool read = false,
  int conv = convId,
}) => ChatMessage(
  id: id,
  conversation: conv,
  sender: sender,
  text: text,
  clientId: cid,
  createdAt: DateTime(2026, 11, 6, 12, 0, id),
  read: read,
);

Map<String, dynamic> json(ChatMessage m) => {
  'id': m.id,
  'conversation': m.conversation,
  'sender': m.sender,
  'text': m.text,
  'client_id': m.clientId,
  'created_at': m.createdAt.toUtc().toIso8601String(),
  'read': m.read,
};

class FakeLink implements ChatLink {
  final _ctrl = StreamController<ChatEvent>.broadcast();
  final ValueNotifier<bool> _conn = ValueNotifier(true);
  final sent = <Map<String, dynamic>>[];
  final typingCalls = <int>[];
  final readCalls = <List<int>>[];

  @override
  Stream<ChatEvent> get events => _ctrl.stream;
  @override
  ValueListenable<bool> get connected => _conn;
  set online(bool v) => _conn.value = v;
  void emit(String type, Map<String, dynamic> data) =>
      _ctrl.add(ChatEvent(type, data));

  @override
  bool sendMessage({
    int? conversation,
    int? to,
    required String text,
    required String clientId,
  }) {
    if (!_conn.value) return false;
    sent.add({
      'conversation': conversation,
      'to': to,
      'text': text,
      'client_id': clientId,
    });
    return true;
  }

  @override
  void typing(int conversation) => typingCalls.add(conversation);
  @override
  void read(int conversation, int upTo) => readCalls.add([conversation, upTo]);
}

class FakeRest implements ChatRest {
  int unreadOnServer = 0;
  int unreadCalls = 0;
  bool failUnread = false;

  @override
  int? get myId => meId;

  final contactsList = <ChatUser>[];
  final conversationsList = <ChatConversation>[];

  @override
  Future<List<ChatUser>> contacts({String search = ''}) async => contactsList;

  @override
  Future<List<ChatConversation>> conversations() async => conversationsList;

  final registeredTokens = <String>[];
  final removedTokens = <String>[];
  bool failRegister = false;

  @override
  Future<void> registerDevice(String token, String platform) async {
    if (failRegister) throw const ChatApiException(null);
    registeredTokens.add('$platform:$token');
  }

  @override
  Future<void> removeDevice(String token) async => removedTokens.add(token);

  @override
  Future<int> unread() async {
    unreadCalls++;
    if (failUnread) throw const ChatApiException(null);
    return unreadOnServer;
  }

  final store = <ChatMessage>[];
  int opened = 0;
  int sentViaRest = 0;
  bool failSend = false;
  bool failMessages = false;
  final readViaRest = <int>[];
  int _next = 1000;

  /// When set, opening the chat waits for it (the server is slow).
  Completer<void>? openGate;

  @override
  Future<ChatConversation> openConversation(int userId) async {
    opened++;
    if (openGate != null) await openGate!.future;
    return ChatConversation(
      id: convId,
      peer: peer,
      lastMessage: null,
      unread: 0,
      updatedAt: DateTime(2026),
    );
  }

  @override
  Future<ChatPageResult> messages(
    int conversationId, {
    int? beforeId,
    int limit = 50,
  }) async {
    if (failMessages) throw const ChatApiException(null);
    var rows = store.where((m) => beforeId == null || m.id < beforeId).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final more = rows.length > limit;
    rows = rows.length > limit ? rows.sublist(rows.length - limit) : rows;
    return ChatPageResult(rows, more);
  }

  @override
  Future<ChatMessage> sendMessage(
    int conversationId,
    String text,
    String clientId,
  ) async {
    sentViaRest++;
    if (failSend) throw const ChatApiException(null);
    final dup = store.where((m) => m.clientId == clientId).toList();
    if (dup.isNotEmpty) return dup.first;
    final m = msg(++_next, meId, text, cid: clientId);
    store.add(m);
    return m;
  }

  @override
  Future<void> markRead(int conversationId, int upToId) async =>
      readViaRest.add(upToId);
}

/// A message at a given time (the default helper uses a fixed date).
class ChatMessageX {
  static ChatMessage at(int id, int sender, String text, DateTime when) =>
      ChatMessage(
        id: id,
        conversation: convId,
        sender: sender,
        text: text,
        clientId: '',
        createdAt: when,
        read: false,
      );
}
