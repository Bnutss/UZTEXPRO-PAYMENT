import 'dart:typed_data';
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
    int? replyTo,
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
  final groupCalls = <String>[];

  final mediaCalls = <String>[];

  /// `conversation:message:client id` of every forward on the server; a media
  /// message in [goneForwards] answers 410, as a file the server dropped.
  final forwardCalls = <String>[];
  final goneForwards = <int>{};

  @override
  Future<ChatMessage> forwardMessage(
    int conversationId,
    int messageId,
    String clientId, {
    String albumId = '',
  }) async {
    forwardCalls.add('$conversationId:$messageId:$clientId');
    if (goneForwards.contains(messageId)) throw const ChatApiException(410);
    return ChatMessage(
      id: 777,
      conversation: conversationId,
      sender: 1,
      text: 'fwd',
      clientId: clientId,
      createdAt: DateTime(2026),
      read: false,
      forward: const ChatForward(name: 'Anna', userId: 2),
    );
  }

  @override
  Future<ChatMessage> sendMedia(
    int conversationId,
    ChatUpload upload,
    String clientId, {
    int? replyTo,
    int? forwardOf,
    void Function(double progress)? onProgress,
    ChatCancelToken? cancel,
  }) async {
    mediaCalls.add('send:$conversationId:${upload.kind}:$clientId');
    onProgress?.call(1);
    return ChatMessage(
      id: 888,
      conversation: conversationId,
      sender: 1,
      text: upload.caption,
      clientId: clientId,
      createdAt: DateTime(2026),
      read: false,
      kind: upload.kind,
      media: ChatMedia(
        name: upload.name,
        width: upload.width,
        height: upload.height,
      ),
    );
  }

  @override
  Future<void> downloadMedia(
    int messageId,
    String destPath, {
    void Function(double progress)? onProgress,
    ChatCancelToken? cancel,
  }) async => mediaCalls.add('download:$messageId');

  @override
  Future<void> ackDownloaded(int messageId) async =>
      mediaCalls.add('ack:$messageId');

  @override
  Future<ChatMessage> sendVoice(
    int conversationId,
    String filePath,
    int durationMs,
    List<int> waveform,
    String clientId, {
    int? replyTo,
  }) async {
    groupCalls.add('voice:$conversationId:$clientId');
    return ChatMessage(
      id: 777,
      conversation: conversationId,
      sender: 1,
      text: 'Voice',
      clientId: clientId,
      createdAt: DateTime(2026),
      read: false,
      kind: 'voice',
      audioUrl: 'https://x/a.m4a',
      durationMs: durationMs,
      waveform: waveform,
    );
  }

  /// The group answers 404 (deleted / I was removed).
  bool groupGone = false;

  @override
  Future<ChatConversation> createGroup(
    String title,
    List<int> memberIds, {
    Uint8List? photo,
  }) async {
    groupCalls.add('create:$title:${memberIds.join(',')}');
    return ChatConversation(
      id: 900,
      peer: ChatUser.groupStandIn(900, title, null),
      lastMessage: null,
      unread: 0,
      updatedAt: DateTime(2026),
      isGroup: true,
      membersCount: memberIds.length + 1,
      myRole: 'owner',
    );
  }

  @override
  Future<ChatConversation> group(int id) async {
    groupCalls.add('group:$id');
    if (groupGone) throw const ChatApiException(404);
    return ChatConversation(
      id: id,
      peer: ChatUser.groupStandIn(id, 'G', null),
      lastMessage: null,
      unread: 0,
      updatedAt: DateTime(2026),
      isGroup: true,
    );
  }

  @override
  Future<ChatConversation> updateGroup(
    int id, {
    String? title,
    Uint8List? photo,
    bool removePhoto = false,
  }) => group(id);

  @override
  Future<void> addMembers(int id, List<int> userIds) async =>
      groupCalls.add('add:$id');

  @override
  Future<void> removeMember(int id, int userId) async =>
      groupCalls.add('remove:$id:$userId');

  @override
  Future<void> setMemberRole(int id, int userId, String role) async =>
      groupCalls.add('role:$id:$userId:$role');

  @override
  Future<void> deleteGroup(int id) async {
    groupCalls.add('delete:$id');
    if (groupGone) throw const ChatApiException(404);
  }

  final deletedChats = <String>[];
  final mutedChats = <String>[];
  final deletedMessages = <String>[];

  @override
  Future<ChatMessage> editMessage(int id, String text) async =>
      store.firstWhere((m) => m.id == id);

  @override
  Future<void> deleteMessage(int id, {bool forAll = false}) async =>
      deletedMessages.add('$id:${forAll ? 'all' : 'me'}');

  @override
  Future<void> deleteConversation(int id, {bool forAll = false}) async =>
      deletedChats.add('$id:${forAll ? 'all' : 'me'}');

  @override
  Future<void> setMuted(int id, bool muted, {int? hours}) async =>
      mutedChats.add('$id:$muted');

  ChatServerNotify serverNotify = const ChatServerNotify();

  @override
  Future<ChatServerNotify> notifySettings() async => serverNotify;

  @override
  Future<ChatServerNotify> saveNotifySettings(ChatServerNotify s) async =>
      serverNotify = s;

  int unreadOnServer = 0;
  int unreadCalls = 0;
  bool failUnread = false;

  @override
  int? get myId => meId;

  @override
  String get apiBase => '';

  @override
  String get apiToken => '';

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
  Future<void> registerDevice(
    String token,
    String platform, {
    String name = '',
  }) async {
    if (failRegister) throw const ChatApiException(null);
    registeredTokens.add('$platform:$token');
  }

  final deviceList = <ChatDeviceInfo>[];
  final deletedDevices = <int>[];

  @override
  Future<List<ChatDeviceInfo>> devices({String? current}) async =>
      List.of(deviceList);

  @override
  Future<void> deleteDevice(int id) async {
    deletedDevices.add(id);
    deviceList.removeWhere((d) => d.id == id);
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
    String? kind,
  }) async {
    if (failMessages) throw const ChatApiException(null);
    var rows =
        store
            .where((m) => beforeId == null || m.id < beforeId)
            .where(
              (m) =>
                  kind == null ||
                  (kind == 'voice' && m.isVoice) ||
                  (kind == 'media' && (m.isImage || m.isVideo)),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final more = rows.length > limit;
    rows = rows.length > limit ? rows.sublist(rows.length - limit) : rows;
    return ChatPageResult(rows, more);
  }

  @override
  Future<ChatMessage> sendMessage(
    int conversationId,
    String text,
    String clientId, {
    int? replyTo,
  }) async {
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
