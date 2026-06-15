import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert' show json, base64, ascii, jsonDecode;
import 'package:upgrader/upgrader.dart';
import 'package:uztexpro_payment/features/auth/login_page.dart';
import 'package:uztexpro_payment/features/home/menu_page.dart';
import '../core/storage/app_storage.dart';
import '../notifiers/theme_notifier.dart';
import '../core/localization/locale_notifier.dart';

class PROApp extends StatefulWidget {
  @override
  _ProMobile createState() => _ProMobile();
}

class _ProMobile extends State<PROApp> {
  final storage = AppStorage();

  @override
  void initState() {
    super.initState();
    _restoreTheme();
    _restoreLocale();
  }

  Future<void> _restoreTheme() async {
    final saved = await storage.read(key: 'isDarkTheme');
    if (saved == 'true') {
      themeNotifier.value = ThemeMode.dark;
    }
  }

  Future<void> _restoreLocale() async {
    final saved = await storage.read(key: 'locale');
    if (saved != null && saved.isNotEmpty) {
      localeNotifier.value = Locale(saved);
    }
  }

  Future<String> get jwtOrEmpty async {
    try {
      var jwt = await storage.read(key: "jwt");
      return jwt ?? "";
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: localeNotifier,
          builder: (context, locale, _) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              themeMode: themeMode,
              locale: locale,
              theme: _lightTheme(),
              darkTheme: _darkTheme(),
              home: UpgradeAlert(
                upgrader: Upgrader(),
                showIgnore: false,
                showLater: true,
                dialogStyle: UpgradeDialogStyle.cupertino,
                child: FutureBuilder<String>(
                  future: jwtOrEmpty,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Scaffold(
                        body: Center(child: Text("Ошибка: ${snapshot.error}")),
                      );
                    }
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      final stored = snapshot.data!;
                      try {
                        final body = jsonDecode(stored) as Map<String, dynamic>;
                        final rawToken = body['token'] as String?;
                        if (rawToken == null) return LoginPage();
                        final parts = rawToken.split('.');
                        if (parts.length != 3) return LoginPage();
                        final payload = json.decode(
                          ascii.decode(base64.decode(base64.normalize(parts[1]))),
                        );
                        final exp = DateTime.fromMillisecondsSinceEpoch(
                            payload['exp'] * 1000);
                        if (exp.isAfter(DateTime.now())) {
                          return MenuPage(jwtToken: stored);
                        }
                      } catch (_) {}
                    }
                    return LoginPage();
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  ThemeData _lightTheme() {
    const primary = Color(0xFFFF9800);
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: false,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      cardColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: Color(0xFFFF5722),
        surface: Colors.white,
        background: Color(0xFFF5F5F5),
        onSurface: Color(0xFF424242),
        onBackground: Color(0xFF424242),
        outline: Color(0xFFDDDDDD),
      ),
      cardTheme: const CardThemeData(color: Colors.white),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: Colors.grey.shade50,
        filled: true,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF424242)),
        bodyMedium: TextStyle(color: Color(0xFF424242)),
        titleLarge: TextStyle(color: Color(0xFF424242)),
      ),
    );
  }

  ThemeData _darkTheme() {
    const primary = Color(0xFFFF9800);
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: false,
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E1E),
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: Color(0xFFFF5722),
        surface: Color(0xFF1E1E1E),
        background: Color(0xFF121212),
        onSurface: Color(0xFFE0E0E0),
        onBackground: Color(0xFFE0E0E0),
        outline: Color(0xFF3A3A3A),
      ),
      cardTheme: const CardThemeData(color: Color(0xFF1E1E1E)),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1E1E1E),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF1E1E1E),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        fillColor: Color(0xFF2A2A2A),
        filled: true,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFE0E0E0)),
        bodyMedium: TextStyle(color: Color(0xFFE0E0E0)),
        titleLarge: TextStyle(color: Color(0xFFE0E0E0)),
      ),
    );
  }
}
