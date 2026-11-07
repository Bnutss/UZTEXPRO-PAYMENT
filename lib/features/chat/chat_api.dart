import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:uztexpro_payment/main.dart' show API;

import 'chat_models.dart';

/// The chat endpoints are not reachable (network, server, bad answer).
class ChatApiException implements Exception {
  const ChatApiException(this.statusCode);
  final int? statusCode;

  @override
  String toString() => 'ChatApiException($statusCode)';
}

/// Lets the person stop an upload or a download that is going on.
class ChatCancelToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final l in _listeners) {
      l();
    }
  }

  /// [listener] runs when the token is cancelled (at once if it already is).
  void onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }
}

/// The upload / download was stopped by the person (not a failure).
class ChatCancelled implements Exception {
  const ChatCancelled();

  @override
  String toString() => 'ChatCancelled';
}

/// A photo / video / document ready to be uploaded (already compressed).
class ChatUpload {
  const ChatUpload({
    required this.filePath,
    required this.kind,
    required this.name,
    this.width = 0,
    this.height = 0,
    this.durationMs = 0,
    this.thumbPath,
    this.caption = '',
    this.albumId = '',
  });

  /// Photos and videos sent together share this id (one album in the chat).
  final String albumId;

  final String filePath;

  /// `image`, `video` or `file`.
  final String kind;
  final String name;
  final int width;
  final int height;
  final int durationMs;

  /// A small JPEG preview (photos and videos).
  final String? thumbPath;
  final String caption;

  ChatUpload withCaption(String caption) => ChatUpload(
    filePath: filePath,
    kind: kind,
    name: name,
    width: width,
    height: height,
    durationMs: durationMs,
    thumbPath: thumbPath,
    caption: caption,
    albumId: albumId,
  );

  ChatUpload inAlbum(String albumId) => ChatUpload(
    filePath: filePath,
    kind: kind,
    name: name,
    width: width,
    height: height,
    durationMs: durationMs,
    thumbPath: thumbPath,
    caption: caption,
    albumId: albumId,
  );
}

/// A page of history, oldest message first.
class ChatPageResult {
  const ChatPageResult(this.messages, this.hasMore);
  final List<ChatMessage> messages;
  final bool hasMore;
}

/// What the conversation screen needs from the REST side (a seam for tests).
abstract class ChatRest {
  /// The id of the signed-in user, when the token carries it.
  int? get myId;

  /// Address and token for the native chat preview, which loads its messages
  /// itself (empty where there is none).
  String get apiBase;
  String get apiToken;

  /// Total of unread messages.
  Future<int> unread();

  Future<List<ChatUser>> contacts({String search});

  /// This phone wants push notifications for the signed-in user.
  Future<void> registerDevice(String token, String platform);

  /// Stop push notifications to this phone (on logout).
  Future<void> removeDevice(String token);
  Future<List<ChatConversation>> conversations();
  Future<ChatConversation> openConversation(int userId);
  Future<ChatPageResult> messages(
    int conversationId, {
    int? beforeId,
    int limit,
    String? kind,
  });
  Future<ChatMessage> sendMessage(
    int conversationId,
    String text,
    String clientId, {
    int? replyTo,
  });

  /// Uploads a recorded voice message (a file on this phone).
  Future<ChatMessage> sendVoice(
    int conversationId,
    String filePath,
    int durationMs,
    List<int> waveform,
    String clientId, {
    int? replyTo,
  });

  /// Uploads a photo / video / document; [onProgress] gets 0..1.
  Future<ChatMessage> sendMedia(
    int conversationId,
    ChatUpload upload,
    String clientId, {
    int? replyTo,
    void Function(double progress)? onProgress,
    ChatCancelToken? cancel,
  });

  /// Downloads the original of a message to [destPath] (throws a
  /// [ChatApiException] with 410 when the server no longer has it).
  Future<void> downloadMedia(
    int messageId,
    String destPath, {
    void Function(double progress)? onProgress,
    ChatCancelToken? cancel,
  });

  /// "I saved it on the phone": the server may delete its copy once every
  /// recipient has.
  Future<void> ackDownloaded(int messageId);
  Future<void> markRead(int conversationId, int upToId);

  /// Deletes the messages of a chat: only for me, or for both people.
  Future<void> deleteConversation(int conversationId, {bool forAll = false});

  /// Changes the text of my message.
  Future<ChatMessage> editMessage(int messageId, String text);

  /// Deletes one message: for both people, or only for me.
  Future<void> deleteMessage(int messageId, {bool forAll = false});

  /// Switches the notifications of a chat off / on (for me).
  Future<void> setMuted(int conversationId, bool muted);

  // ── groups ──
  Future<ChatConversation> createGroup(
    String title,
    List<int> memberIds, {
    Uint8List? photo,
  });

  /// The group's card with every member.
  Future<ChatConversation> group(int conversationId);

  Future<ChatConversation> updateGroup(
    int conversationId, {
    String? title,
    Uint8List? photo,
    bool removePhoto = false,
  });

  Future<void> addMembers(int conversationId, List<int> userIds);

  /// Removes a person, or leaves the group (my own id).
  Future<void> removeMember(int conversationId, int userId);

  Future<void> setMemberRole(int conversationId, int userId, String role);

  /// Deletes the whole group for everybody (the owner).
  Future<void> deleteGroup(int conversationId);
}

/// REST side of the chat. [jwtToken] is the value kept after login: either the
/// raw JSON of the login answer (`{"token": "..."}`) or the bare token.
class ChatApi implements ChatRest {
  ChatApi(String jwtToken) : token = _extractToken(jwtToken);

  final String token;

  static const _timeout = Duration(seconds: 20);
  static String get _base => '$API/app-update/chat';

  static String _extractToken(String stored) {
    try {
      return jsonDecode(stored)['token'] as String;
    } catch (_) {
      return stored;
    }
  }

  Map<String, String> get headers => {'Authorization': 'Bearer $token'};

  @override
  String get apiBase => _base;

  @override
  String get apiToken => token;

  /// The id of the signed-in user, read from the JWT (`user_id`).
  @override
  late final int? myId = _userIdOf(token);

  static int? _userIdOf(String jwt) {
    try {
      final payload = jwt.split('.')[1];
      final map =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(payload))),
              )
              as Map<String, dynamic>;
      return (map['user_id'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final http.Response res;
    try {
      res = await http
          .get(
            Uri.parse('$_base$path').replace(queryParameters: query),
            headers: headers,
          )
          .timeout(_timeout);
    } catch (_) {
      throw const ChatApiException(null);
    }
    return _decode(res);
  }

  Future<dynamic> _delete(String path, [Map<String, String>? query]) async {
    final http.Response res;
    try {
      res = await http
          .delete(
            Uri.parse('$_base$path').replace(queryParameters: query),
            headers: headers,
          )
          .timeout(_timeout);
    } catch (_) {
      throw const ChatApiException(null);
    }
    return _decode(res);
  }

  @override
  Future<void> deleteConversation(
    int conversationId, {
    bool forAll = false,
  }) async {
    await _delete('/conversations/$conversationId/', {
      if (forAll) 'for_all': '1',
    });
  }

  @override
  Future<ChatMessage> editMessage(int messageId, String text) async {
    final http.Response res;
    try {
      res = await http
          .patch(
            Uri.parse('$_base/messages/$messageId/'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode({'text': text}),
          )
          .timeout(_timeout);
    } catch (_) {
      throw const ChatApiException(null);
    }
    final data = _decode(res);
    return ChatMessage.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<void> deleteMessage(int messageId, {bool forAll = false}) async {
    await _delete('/messages/$messageId/', {if (forAll) 'for_all': '1'});
  }

  @override
  Future<ChatConversation> createGroup(
    String title,
    List<int> memberIds, {
    Uint8List? photo,
  }) async {
    final data = photo == null
        ? await _post('/groups/', {'title': title, 'member_ids': memberIds})
        : await _multipart('POST', '/groups/', {
            'title': title,
            'member_ids': jsonEncode(memberIds),
          }, photo);
    return ChatConversation.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<ChatConversation> group(int conversationId) async {
    final data = await _get('/groups/$conversationId/');
    return ChatConversation.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<ChatConversation> updateGroup(
    int conversationId, {
    String? title,
    Uint8List? photo,
    bool removePhoto = false,
  }) async {
    final fields = {
      if (title != null) 'title': title,
      if (removePhoto) 'remove_photo': 'true',
    };
    final data = await _multipart(
      'PATCH',
      '/groups/$conversationId/',
      fields,
      photo,
    );
    return ChatConversation.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<void> addMembers(int conversationId, List<int> userIds) async {
    await _post('/groups/$conversationId/members/', {'user_ids': userIds});
  }

  @override
  Future<void> removeMember(int conversationId, int userId) async {
    await _delete('/groups/$conversationId/members/$userId/');
  }

  @override
  Future<void> setMemberRole(
    int conversationId,
    int userId,
    String role,
  ) async {
    await _send('PATCH', '/groups/$conversationId/members/$userId/', {
      'role': role,
    });
  }

  @override
  Future<void> deleteGroup(int conversationId) async {
    await _delete('/groups/$conversationId/');
  }

  /// A request with a JSON body (PATCH).
  Future<dynamic> _send(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    final http.Response res;
    try {
      final req = http.Request(method, Uri.parse('$_base$path'))
        ..headers.addAll({...headers, 'Content-Type': 'application/json'})
        ..body = jsonEncode(body);
      res = await http.Response.fromStream(await req.send().timeout(_timeout));
    } catch (_) {
      throw const ChatApiException(null);
    }
    return _decode(res);
  }

  /// A form request, with the group's photo when there is one.
  Future<dynamic> _multipart(
    String method,
    String path,
    Map<String, String> fields,
    Uint8List? photo,
  ) async {
    final http.Response res;
    try {
      final req = http.MultipartRequest(method, Uri.parse('$_base$path'))
        ..headers.addAll(headers)
        ..fields.addAll(fields);
      if (photo != null) {
        req.files.add(
          http.MultipartFile.fromBytes('photo', photo, filename: 'group.jpg'),
        );
      }
      res = await http.Response.fromStream(
        await req.send().timeout(const Duration(seconds: 60)),
      );
    } catch (_) {
      throw const ChatApiException(null);
    }
    return _decode(res);
  }

  @override
  Future<void> setMuted(int conversationId, bool muted) async {
    await _post('/conversations/$conversationId/mute/', {'muted': muted});
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$_base$path'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (_) {
      throw const ChatApiException(null);
    }
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ChatApiException(res.statusCode);
    }
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw ChatApiException(res.statusCode);
    }
  }

  /// People one can write to; [search] is matched by the server.
  @override
  Future<List<ChatUser>> contacts({String search = ''}) async {
    final data = await _get('/contacts/', {
      if (search.trim().isNotEmpty) 'search': search.trim(),
    });
    return (data as List)
        .whereType<Map>()
        .map((e) => ChatUser.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// My chats that have messages, newest first.
  @override
  Future<List<ChatConversation>> conversations() async {
    final data = await _get('/conversations/', {'groups': '1'});
    return (data as List)
        .whereType<Map>()
        .map((e) => ChatConversation.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Opens (or creates) the chat with [userId].
  @override
  Future<ChatConversation> openConversation(int userId) async {
    final data = await _post('/conversations/', {'user_id': userId});
    return ChatConversation.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Total of unread messages (badge of the chat button).
  @override
  Future<int> unread() async {
    final data = await _get('/unread/');
    return ((data as Map)['unread'] as num?)?.toInt() ?? 0;
  }

  /// History of a chat, oldest first within the page; [beforeId] loads older.
  @override
  Future<ChatPageResult> messages(
    int conversationId, {
    int? beforeId,
    int limit = 50,
    String? kind,
  }) async {
    final data = await _get('/conversations/$conversationId/messages/', {
      'limit': '$limit',
      if (beforeId != null) 'before_id': '$beforeId',
      if (kind != null) 'kind': kind, // 'voice' or 'media'
    });
    final map = data as Map;
    return ChatPageResult(
      (map['messages'] as List)
          .whereType<Map>()
          .map((e) => ChatMessage.fromJson(e.cast<String, dynamic>()))
          .toList(),
      map['has_more'] == true,
    );
  }

  /// Sends over HTTP (the socket is down). The same [clientId] twice is saved
  /// once by the server.
  @override
  Future<ChatMessage> sendMessage(
    int conversationId,
    String text,
    String clientId, {
    int? replyTo,
  }) async {
    final data = await _post('/conversations/$conversationId/messages/', {
      'text': text,
      'client_id': clientId,
      if (replyTo != null) 'reply_to': replyTo,
    });
    return ChatMessage.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<ChatMessage> sendVoice(
    int conversationId,
    String filePath,
    int durationMs,
    List<int> waveform,
    String clientId, {
    int? replyTo,
  }) async {
    final http.Response res;
    try {
      final req =
          http.MultipartRequest(
              'POST',
              Uri.parse('$_base/conversations/$conversationId/messages/'),
            )
            ..headers.addAll(headers)
            ..fields['client_id'] = clientId
            ..fields['duration_ms'] = '$durationMs'
            ..fields['waveform'] = jsonEncode(waveform);
      if (replyTo != null) req.fields['reply_to'] = '$replyTo';
      req.files.add(await http.MultipartFile.fromPath('audio', filePath));
      res = await http.Response.fromStream(
        await req.send().timeout(const Duration(seconds: 90)),
      );
    } catch (_) {
      throw const ChatApiException(null);
    }
    return ChatMessage.fromJson((_decode(res) as Map).cast<String, dynamic>());
  }

  @override
  Future<ChatMessage> sendMedia(
    int conversationId,
    ChatUpload u,
    String clientId, {
    int? replyTo,
    void Function(double progress)? onProgress,
    ChatCancelToken? cancel,
  }) async {
    final multipart =
        http.MultipartRequest(
            'POST',
            Uri.parse('$_base/conversations/$conversationId/messages/'),
          )
          ..headers.addAll(headers)
          ..fields.addAll({
            'client_id': clientId,
            'kind': u.kind,
            'name': u.name,
            'width': '${u.width}',
            'height': '${u.height}',
            'duration_ms': '${u.durationMs}',
            if (u.caption.isNotEmpty) 'caption': u.caption,
            if (u.albumId.isNotEmpty) 'album_id': u.albumId,
            if (replyTo != null) 'reply_to': '$replyTo',
          });
    multipart.files.add(
      await http.MultipartFile.fromPath('file', u.filePath, filename: u.name),
    );
    final thumb = u.thumbPath;
    if (thumb != null) {
      multipart.files.add(
        await http.MultipartFile.fromPath('thumb', thumb, filename: 't.jpg'),
      );
    }
    final total = multipart.contentLength;
    final stream = multipart.finalize();
    // dart:io, not package:http: it lets each chunk be flushed to the socket,
    // so the progress is the real upload and not just the buffering.
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client.postUrl(Uri.parse(multipart.url.toString()));
      multipart.headers.forEach(req.headers.set);
      req.contentLength = total;
      var sent = 0;
      await for (final chunk in stream) {
        if (cancel?.isCancelled == true) throw const ChatCancelled();
        req.add(chunk);
        await req.flush();
        sent += chunk.length;
        onProgress?.call((sent / total).clamp(0.0, 1.0));
      }
      final resp = await req.close().timeout(const Duration(minutes: 3));
      final bytes = await resp.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      final decoded = _decode(http.Response.bytes(bytes, resp.statusCode));
      return ChatMessage.fromJson((decoded as Map).cast<String, dynamic>());
    } on ChatApiException {
      rethrow;
    } on ChatCancelled {
      rethrow;
    } catch (_) {
      if (cancel?.isCancelled == true) throw const ChatCancelled();
      throw const ChatApiException(null);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> downloadMedia(
    int messageId,
    String destPath, {
    void Function(double progress)? onProgress,
    ChatCancelToken? cancel,
  }) async {
    final client = http.Client();
    cancel?.onCancel(client.close);
    final part = File('$destPath.part');
    try {
      final req = http.Request(
        'GET',
        Uri.parse('$_base/messages/$messageId/file/'),
      )..headers.addAll(headers);
      final resp = await client.send(req).timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) {
        throw ChatApiException(resp.statusCode);
      }
      await part.parent.create(recursive: true);
      final sink = part.openWrite();
      final total = resp.contentLength ?? 0;
      var got = 0;
      try {
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          got += chunk.length;
          if (total > 0) onProgress?.call((got / total).clamp(0.0, 1.0));
        }
      } finally {
        await sink.close();
      }
      await part.rename(destPath);
    } on ChatApiException {
      rethrow;
    } catch (_) {
      if (cancel?.isCancelled == true) throw const ChatCancelled();
      throw const ChatApiException(null);
    } finally {
      client.close();
      if (await part.exists()) {
        try {
          await part.delete();
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> ackDownloaded(int messageId) async {
    await _post('/messages/$messageId/downloaded/', const {});
  }

  @override
  Future<void> markRead(int conversationId, int upToId) async {
    await _post('/conversations/$conversationId/read/', {'up_to_id': upToId});
  }

  @override
  Future<void> registerDevice(String token, String platform) async {
    await _post('/devices/', {'token': token, 'platform': platform});
  }

  @override
  Future<void> removeDevice(String token) async {
    await _post('/devices/remove/', {'token': token});
  }
}
