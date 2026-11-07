/// Models of the chat API (`/api/v1/app-update/chat/...`).
library;

class ChatUser {
  const ChatUser({
    required this.id,
    required this.name,
    this.position = '',
    this.department = '',
    this.photo,
    this.phone = '',
    this.online = false,
    this.lastSeen,
    this.role = '',
  });

  final int id;
  final String name;
  final String position;
  final String department;
  final String? photo;
  final String phone;

  /// Connected to the chat right now / when last connected (null: never).
  final bool online;
  final DateTime? lastSeen;

  /// In a group: owner / admin / member (empty elsewhere).
  final String role;

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'owner' || role == 'admin';

  /// A group shown where a person is expected (the header, the list row): the
  /// id is negative so it never meets a real user's.
  factory ChatUser.groupStandIn(
    int conversationId,
    String title,
    String? photo,
  ) => ChatUser(id: -conversationId, name: title, photo: photo);

  /// "Surname Name": the full name without the patronymic.
  String get surnameName {
    if (id < 0) return name.trim();
    return name.trim().split(RegExp(r'\s+')).take(2).join(' ');
  }

  /// "Surname N.": the full name (with patronymic) is far too long for a
  /// title.
  String get shortName {
    if (id < 0) return name.trim(); // a group's title is not a person's name
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return name.trim();
    return '${parts[0]} ${parts[1].substring(0, 1)}.';
  }

  /// "Operator · Sewing": the line under a name in lists.
  String get subtitle =>
      [position, department].where((t) => t.isNotEmpty).join(' · ');

  factory ChatUser.fromJson(Map<String, dynamic> j) => ChatUser(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String? ?? '',
    position: j['position'] as String? ?? '',
    department: j['department'] as String? ?? '',
    photo: j['photo'] as String?,
    phone: j['phone'] as String? ?? '',
    online: j['online'] as bool? ?? false,
    lastSeen: j['last_seen'] == null
        ? null
        : DateTime.tryParse(j['last_seen'] as String)?.toLocal(),
    role: j['role'] as String? ?? '',
  );
}

/// Where a message of mine is on its way. Messages that came from the server
/// are always [sent].
enum ChatSendState { sending, sent, failed }

/// The quote above an answer: which message it answers.
class ChatReply {
  const ChatReply({
    required this.id,
    required this.sender,
    required this.text,
    this.kind = 'text',
  });

  final int id;
  final int sender;
  final String text;

  /// `voice` when the quoted message is a voice one (no text to show).
  final String kind;
  bool get isVoice => kind == 'voice';

  factory ChatReply.fromJson(Map<String, dynamic> j) => ChatReply(
    id: (j['id'] as num).toInt(),
    sender: (j['sender'] as num).toInt(),
    text: j['text'] as String? ?? '',
    kind: j['kind'] as String? ?? 'text',
  );
}

/// A photo, video or document of a message: what the server knows about it.
/// The original is only on the server until every recipient has saved it
/// ([available] turns false then); the phones keep their copy.
class ChatMedia {
  const ChatMedia({
    required this.name,
    this.size = 0,
    this.mime = '',
    this.width = 0,
    this.height = 0,
    this.durationMs = 0,
    this.thumbUrl,
    this.available = true,
  });

  final String name;
  final int size;
  final String mime;
  final int width;
  final int height;
  final int durationMs;

  /// The small preview on the server (it stays after the original is gone).
  final String? thumbUrl;

  /// The original is still on the server.
  final bool available;

  double get aspect => width > 0 && height > 0 ? width / height : 1;

  factory ChatMedia.fromJson(Map<String, dynamic> j) => ChatMedia(
    name: j['name'] as String? ?? '',
    size: (j['size'] as num?)?.toInt() ?? 0,
    mime: j['mime'] as String? ?? '',
    width: (j['width'] as num?)?.toInt() ?? 0,
    height: (j['height'] as num?)?.toInt() ?? 0,
    durationMs: (j['duration_ms'] as num?)?.toInt() ?? 0,
    thumbUrl: j['thumb'] as String?,
    available: j['available'] as bool? ?? true,
  );
}

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
    this.edited = false,
    this.reply,
    this.senderName = '',
    this.kind = 'text',
    this.event = '',
    this.payload,
    this.audioUrl,
    this.localAudioPath,
    this.durationMs = 0,
    this.waveform = const [],
    this.media,
    this.albumId = '',
  });

  /// Photos and videos sent together share one id: they are drawn as one album.
  final String albumId;

  /// A photo / video / document (kind `image` / `video` / `file`).
  final ChatMedia? media;
  bool get isImage => kind == 'image';
  bool get isVideo => kind == 'video';
  bool get isFile => kind == 'file';
  bool get isMedia => media != null && (isImage || isVideo || isFile);

  /// A voice message: the recording on the server (or, before it is uploaded,
  /// the file on this phone), its length and the loudness bars (0..31).
  final String? audioUrl;
  final String? localAudioPath;
  final int durationMs;
  final List<int> waveform;
  bool get isVoice => kind == 'voice';

  final int id;
  final int conversation;
  final int sender;
  final String text;
  final String clientId;

  /// In the device's time zone (the server sends an ISO time with an offset).
  final DateTime createdAt;
  final bool read;
  final ChatSendState state;

  /// The text was changed after sending.
  final bool edited;

  /// The message this one answers.
  final ChatReply? reply;

  /// In a group: who wrote it.
  final String senderName;

  /// `text`, or `system` for a service line of a group ("X added Y"): then
  /// [event] says what happened and [payload] has the names.
  final String kind;
  final String event;
  final Map<String, dynamic>? payload;
  bool get isSystem => kind == 'system';

  /// Not stored on the server yet (shown at once, confirmed by the echo).
  bool get isLocal => id <= 0;

  ChatMessage copyWith({
    int? id,
    int? conversation,
    bool? read,
    ChatSendState? state,
    String? localAudioPath,
  }) => ChatMessage(
    id: id ?? this.id,
    conversation: conversation ?? this.conversation,
    sender: sender,
    text: text,
    clientId: clientId,
    createdAt: createdAt,
    read: read ?? this.read,
    state: state ?? this.state,
    edited: edited,
    reply: reply,
    senderName: senderName,
    kind: kind,
    event: event,
    payload: payload,
    audioUrl: audioUrl,
    localAudioPath: localAudioPath ?? this.localAudioPath,
    durationMs: durationMs,
    waveform: waveform,
    media: media,
    albumId: albumId,
  );

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: (j['id'] as num).toInt(),
    conversation: (j['conversation'] as num).toInt(),
    sender: (j['sender'] as num).toInt(),
    text: j['text'] as String? ?? '',
    clientId: j['client_id'] as String? ?? '',
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    read: j['read'] as bool? ?? false,
    edited: j['edited'] as bool? ?? false,
    reply: j['reply'] is Map
        ? ChatReply.fromJson((j['reply'] as Map).cast<String, dynamic>())
        : null,
    senderName: j['sender_name'] as String? ?? '',
    kind: j['kind'] as String? ?? 'text',
    event: j['event'] as String? ?? '',
    payload: j['payload'] is Map
        ? (j['payload'] as Map).cast<String, dynamic>()
        : null,
    audioUrl: j['audio'] as String?,
    durationMs: (j['duration_ms'] as num?)?.toInt() ?? 0,
    waveform: j['waveform'] is List
        ? [for (final v in j['waveform'] as List) (v as num).toInt()]
        : const [],
    media: j['media'] is Map
        ? ChatMedia.fromJson((j['media'] as Map).cast<String, dynamic>())
        : null,
    albumId: j['album_id'] as String? ?? '',
  );
}

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.peer,
    required this.lastMessage,
    required this.unread,
    required this.updatedAt,
    this.muted = false,
    this.isGroup = false,
    this.membersCount = 0,
    this.myRole = '',
    this.members = const [],
  });

  final int id;

  /// The other person; for a group a stand-in carrying its title and photo
  /// (see [ChatUser.groupStandIn]), so a list row or a header needs no branch.
  final ChatUser peer;
  final ChatMessage? lastMessage;
  final int unread;
  final DateTime updatedAt;

  /// Notifications of this chat are switched off by me.
  final bool muted;

  final bool isGroup;
  final int membersCount;

  /// My role in a group: owner / admin / member.
  final String myRole;

  /// Every member (only in the group's card, not in the list).
  final List<ChatUser> members;

  bool get isAdmin => myRole == 'owner' || myRole == 'admin';

  ChatConversation copyWith({
    ChatMessage? lastMessage,
    int? unread,
    DateTime? updatedAt,
    bool? muted,
  }) => ChatConversation(
    id: id,
    peer: peer,
    lastMessage: lastMessage ?? this.lastMessage,
    unread: unread ?? this.unread,
    updatedAt: updatedAt ?? this.updatedAt,
    muted: muted ?? this.muted,
    isGroup: isGroup,
    membersCount: membersCount,
    myRole: myRole,
    members: members,
  );

  factory ChatConversation.fromJson(Map<String, dynamic> j) {
    final last = j['last_message'];
    final id = (j['id'] as num).toInt();
    final group = j['kind'] == 'group';
    final members = (j['members'] as List?)
        ?.whereType<Map>()
        .map((m) => ChatUser.fromJson(m.cast<String, dynamic>()))
        .toList();
    return ChatConversation(
      id: id,
      peer: group
          ? ChatUser.groupStandIn(
              id,
              j['title'] as String? ?? '',
              j['photo'] as String?,
            )
          : ChatUser.fromJson((j['peer'] as Map).cast<String, dynamic>()),
      lastMessage: last is Map
          ? ChatMessage.fromJson(last.cast<String, dynamic>())
          : null,
      unread: (j['unread'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
      muted: j['muted'] as bool? ?? false,
      isGroup: group,
      membersCount:
          (j['members_count'] as num?)?.toInt() ?? members?.length ?? 0,
      myRole: j['my_role'] as String? ?? '',
      members: members ?? const [],
    );
  }
}
