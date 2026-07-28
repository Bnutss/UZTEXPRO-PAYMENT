import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../main.dart';

/// A newer Android build published on our own server (self-hosted
/// distribution, outside Google Play) — see `app_update` on the backend.
class AppUpdateInfo {
  final String versionName;
  final int versionCode;
  final String? apkUrl;
  final String changelog;
  final bool isCritical;

  AppUpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.changelog,
    required this.isCritical,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      versionName: json['version_name']?.toString() ?? '',
      versionCode: (json['version_code'] as num?)?.toInt() ?? 0,
      apkUrl: json['apk_url'] as String?,
      changelog: json['changelog']?.toString() ?? '',
      isCritical: json['is_critical'] as bool? ?? false,
    );
  }
}

class AppUpdateApi {
  /// Returns the latest published Android build if it's newer than
  /// [currentVersionCode], or null if the app is already up to date (or the
  /// check failed — this is a background convenience check, never worth
  /// surfacing a network error for).
  static Future<AppUpdateInfo?> check(int currentVersionCode) async {
    try {
      final uri = Uri.parse('$API/app-update/check/').replace(queryParameters: {
        'platform': 'android',
        'version_code': '$currentVersionCode',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! Map<String, dynamic> || body['update_available'] != true) {
        return null;
      }
      return AppUpdateInfo.fromJson(body);
    } catch (_) {
      return null;
    }
  }
}
