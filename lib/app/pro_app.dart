import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'dart:convert' show json, base64, ascii, jsonDecode;
import 'package:uztexpro_payment/features/auth/login_page.dart';
import 'package:uztexpro_payment/features/home/menu_page.dart';
import '../core/storage/app_storage.dart';
import '../core/localization/locale_notifier.dart';
import '../core/theme/app_colors.dart';

class PROApp extends StatefulWidget {
  @override
  _ProMobile createState() => _ProMobile();
}

class _ProMobile extends State<PROApp> {
  final storage = AppStorage();
  late final Future<String> _jwtFuture;

  @override
  void initState() {
    super.initState();
    _restoreLocale();
    _jwtFuture = jwtOrEmpty;
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
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        return AdaptiveApp(
          themeMode: ThemeMode.light,
          materialLightTheme: _lightMaterialTheme(),
          cupertinoLightTheme: _lightCupertinoTheme(),
          locale: locale,
          // Without these, Material widgets (date pickers, etc.) fall back
          // to English regardless of `locale` above — the app can only
          // resolve a non-default locale's built-in strings once the
          // corresponding delegate is registered here. Keeping all three
          // (including Material's) also lets not-yet-migrated Material
          // widgets keep working under the iOS Cupertino root.
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ru'), Locale('en'), Locale('uz')],
          home: FutureBuilder<String>(
            future: _jwtFuture,
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
        );
      },
    );
  }

  ThemeData _lightMaterialTheme() {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: false,
      scaffoldBackgroundColor: AppColors.groupedBackground,
      cardColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brandOrange,
        secondary: AppColors.brandRed,
        surface: Colors.white,
        background: AppColors.groupedBackground,
        onSurface: Color(0xFF1A1A1A),
        onBackground: Color(0xFF1A1A1A),
        outline: Color(0xFFE0E0E0),
      ),
      cardTheme: const CardThemeData(color: Colors.white),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
      inputDecorationTheme: const InputDecorationTheme(
        fillColor: Color(0xFFF2F2F2),
        filled: true,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF1A1A1A)),
        bodyMedium: TextStyle(color: Color(0xFF1A1A1A)),
        titleLarge: TextStyle(color: Color(0xFF1A1A1A)),
      ),
    );
  }

  CupertinoThemeData _lightCupertinoTheme() {
    return const CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.brandOrange,
      scaffoldBackgroundColor: AppColors.groupedBackground,
      barBackgroundColor: Colors.white,
      textTheme: CupertinoTextThemeData(
        primaryColor: AppColors.brandOrange,
      ),
    );
  }
}
