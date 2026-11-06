/// Models of the chat API (`/api/v1/app-update/chat/...`).
library;

class ChatUser {
  const ChatUser({
    required this.id,
    required this.name,
    this.position = '',
    this.department = '',
    this.photo,
  });

  final int id;
  final String name;
  final String position;
  final String department;
  final String? photo;

  /// "Operator · Sewing": the line under a name in lists.
  String get subtitle =>
      [position, department].where((t) => t.isNotEmpty).join(' · ');

  factory ChatUser.fromJson(Map<String, dynamic> j) => ChatUser(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String? ?? '',
    position: j['position'] as String? ?? '',
    department: j['department'] as String? ?? '',
    photo: j['photo'] as String?,
  );
}

/// Where a message of mine is on its way. Messages that came from the server
/// are always [sent].
enum ChatSendState { sending, sent, failed }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversation,
    required this.sender,
    required this.text,
    required this.clientId,
    required this.createdAt,
    required this.read,
    this.state = ChatSendState.sent,
  });

  final int id;
  final int conversation;
  final int sender;
  final String text;
  final String clientId;

  /// In the device's time zone (the server sends an ISO time with an offset).
  final DateTime createdAt;
  final bool read;
  final ChatSendState state;

  /// Not stored on the server yet (shown at once, confirmed by the echo).
  bool get isLocal => id <= 0;

  ChatMessage copyWith({
    int? id,
    int? conversation,
    bool? read,
    ChatSendState? state,
  }) => ChatMessage(
    id: id ?? this.id,
    conversation: conversation ?? this.conversation,
    sender: sender,
    text: text,
    clientId: clientId,
    createdAt: createdAt,
    read: read ?? this.read,
    state: state ?? this.state,
  );

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: (j['id'] as num).toInt(),
    conversation: (j['conversation'] as num).toInt(),
    sender: (j['sender'] as num).toInt(),
    text: j['text'] as String? ?? '',
    clientId: j['client_id'] as String? ?? '',
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    read: j['read'] as bool? ?? false,
  );
}

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.peer,
    required this.lastMessage,
    required this.unread,
    required this.updatedAt,
  });

  final int id;
  final ChatUser peer;
  final ChatMessage? lastMessage;
  final int unread;
  final DateTime updatedAt;

  ChatConversation copyWith({
    ChatMessage? lastMessage,
    int? unread,
    DateTime? updatedAt,
  }) => ChatConversation(
    id: id,
    peer: peer,
    lastMessage: lastMessage ?? this.lastMessage,
    unread: unread ?? this.unread,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory ChatConversation.fromJson(Map<String, dynamic> j) {
    final last = j['last_message'];
    return ChatConversation(
      id: (j['id'] as num).toInt(),
      peer: ChatUser.fromJson((j['peer'] as Map).cast<String, dynamic>()),
      lastMessage: last is Map
          ? ChatMessage.fromJson(last.cast<String, dynamic>())
          : null,
      unread: (j['unread'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
    );
  }
}
