import 'package:shared_preferences/shared_preferences.dart';

/// Drop-in replacement for FlutterSecureStorage that uses SharedPreferences.
/// Works on macOS without requiring Keychain entitlements or Apple Developer signing.
class AppStorage {
  const AppStorage();

  Future<String?> read({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> write({required String key, String? value}) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }

  Future<void> delete({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
