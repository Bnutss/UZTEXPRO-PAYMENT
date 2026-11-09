import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uztexpro_payment/main.dart' show API;

import '../../core/storage/app_storage.dart';

/// The signed-in person's own photo as a local file, for the Settings tab of
/// the messenger (the native tab bar draws a round avatar from a file path,
/// like Telegram). Same source as the Settings screen: the employee linked to
/// the user. Null when there is no photo or no network.
class ChatMyPhoto {
  ChatMyPhoto._();

  static File? _cached;

  /// Bumps when the photo was changed or removed in "Edit profile": the tab
  /// bar loads it again.
  static final ValueNotifier<int> version = ValueNotifier(0);

  static void invalidate() {
    _cached = null;
    version.value++;
  }

  static Future<File?> load() async {
    final cached = _cached;
    if (cached != null && cached.existsSync()) return cached;
    try {
      final jwtRaw = await const AppStorage().read(key: 'jwt');
      if (jwtRaw == null) return null;
      final token = (jsonDecode(jwtRaw) as Map<String, dynamic>)['token'];
      if (token is! String) return null;
      final headers = {'Authorization': 'Bearer $token'};

      // The picture the person set in the messenger (falling back to the
      // employee's own photo): the same card as "My Profile".
      final res = await http
          .get(Uri.parse('$API/app-update/chat/profile/'), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final url = _resolve(body['photo'] as String?);
      if (url == null) return null;

      final img = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (img.statusCode != 200 || img.bodyBytes.isEmpty) return null;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/my_tab_avatar_${url.hashCode}');
      await file.writeAsBytes(img.bodyBytes, flush: true);
      return _cached = file;
    } catch (_) {
      return null;
    }
  }

  static String? _resolve(String? url) {
    if (url == null || url.isEmpty) return null;
    final origin = Uri.parse(API).origin;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return '$origin$url';
    if (url.startsWith('http://')) return 'https://${url.substring(7)}';
    return url;
  }
}
