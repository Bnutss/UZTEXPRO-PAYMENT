import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'app_update_api.dart';

/// Checks the App Store for a newer iOS build. Every App Store update is
/// treated as mandatory.
class AppStoreUpdateApi {
  /// Returns the App Store release if it's newer than the installed build,
  /// or null if the app is up to date (or the check failed — never worth
  /// surfacing a network error for).
  static Future<AppUpdateInfo?> check() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      // The lookup is per storefront and the app isn't published in every
      // one (RU, KZ return nothing), so pin it to the Uzbek store rather
      // than the device region. The response is CDN-cached for up to a day
      // (`max-age=86400`), which is why a fresh release used to go unseen —
      // the timestamp makes every request a cache miss.
      final uri = Uri.https('itunes.apple.com', '/lookup', {
        'bundleId': packageInfo.packageName,
        'country': 'uz',
        '_': '${DateTime.now().millisecondsSinceEpoch}',
      });
      final res = await http
          .get(uri, headers: const {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final results = body is Map<String, dynamic> ? body['results'] : null;
      if (results is! List || results.isEmpty) return null;
      final app = results.first as Map<String, dynamic>;
      final storeVersion = app['version']?.toString() ?? '';
      if (!isNewer(storeVersion, packageInfo.version)) return null;
      final trackId = app['trackId'];
      return AppUpdateInfo(
        versionName: storeVersion,
        versionCode: 0,
        apkUrl: null,
        storeUrl: trackId != null
            ? 'itms-apps://apps.apple.com/app/id$trackId'
            : app['trackViewUrl']?.toString(),
        changelog: app['releaseNotes']?.toString().trim() ?? '',
        isCritical: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Compares dotted versions numerically: 1.10.0 is newer than 1.9.3.
  static bool isNewer(String store, String installed) {
    List<int> parts(String v) =>
        v.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
    final a = parts(store), b = parts(installed);
    for (var i = 0; i < a.length || i < b.length; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
