import 'dart:convert';

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
  });
  Future<ChatMessage> sendMessage(
    int conversationId,
    String text,
    String clientId,
  );
  Future<void> markRead(int conversationId, int upToId);
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
    final data = await _get('/conversations/');
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
  }) async {
    final data = await _get('/conversations/$conversationId/messages/', {
      'limit': '$limit',
      if (beforeId != null) 'before_id': '$beforeId',
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
    String clientId,
  ) async {
    final data = await _post('/conversations/$conversationId/messages/', {
      'text': text,
      'client_id': clientId,
    });
    return ChatMessage.fromJson((data as Map).cast<String, dynamic>());
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
