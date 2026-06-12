import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/storage/app_storage.dart';
import '../../notifiers/theme_notifier.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/localization/app_strings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  final AppStorage _storage = const AppStorage();

  String _displayName = '';
  String _email = '';
  String _login = '';
  String _version = '';

  static const Color _gradientStart = Color(0xFFFF8C00);
  static const Color _gradientEnd = Color(0xFFCC1500);

  final List<Map<String, String>> _languages = [
    {'code': 'ru', 'name': 'Русский', 'desc': 'Русский язык'},
    {'code': 'en', 'name': 'English', 'desc': 'English language'},
    {'code': 'uz', 'name': "O'zbekcha", 'desc': "O'zbek tili"},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
    _loadUserData();
    _loadVersion();
    localeNotifier.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() => setState(() {});

  Future<void> _loadUserData() async {
    final jwtRaw = await _storage.read(key: 'jwt');
    if (jwtRaw != null) {
      try {
        final body = jsonDecode(jwtRaw) as Map<String, dynamic>;
        final user = body['user'] as Map<String, dynamic>?;
        if (user != null) {
          final firstName = (user['first_name'] as String?) ?? '';
          final lastName = (user['last_name'] as String?) ?? '';
          final fullName = '$firstName $lastName'.trim();
          setState(() {
            _displayName = fullName.isNotEmpty ? fullName : (user['username'] as String? ?? '');
            _email = (user['email'] as String?) ?? '';
            _login = (user['username'] as String?) ?? '';
          });
          return;
        }
      } catch (_) {}
    }
    final login = await _storage.read(key: 'username') ?? '';
    setState(() {
      _displayName = login;
      _login = login;
    });
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _version = info.version);
  }

  @override
  void dispose() {
    _animationController.dispose();
    localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Color> gradientColors = isDark
        ? [const Color(0xFF3D1800), const Color(0xFF1F0000)]
        : [_gradientStart, _gradientEnd];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            s.settingsTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white, size: 24),
              onPressed: () => _showAboutDialog(s),
              tooltip: s.aboutApp,
            ),
          ],
        ),
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: -60, right: -40,
              child: _circle(200, 0.07),
            ),
            Positioned(
              bottom: 60, left: -70,
              child: _circle(220, 0.06),
            ),
            Positioned(
              top: 200, right: 20,
              child: _circle(60, 0.05),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _animation,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  children: [
                    _buildProfileCard(s),
                    const SizedBox(height: 24),
                    _buildSectionHeader(s.generalSettings),
                    _buildSettingButton(
                      Icons.language_rounded,
                      s.language,
                      s.languageDesc,
                      const Color(0xFFEF6C00),
                      onTap: () => _showLanguageDialog(s),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionHeader(s.appearance),
                    _buildThemeButton(s),
                    const SizedBox(height: 32),
                    _buildVersionInfo(s),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );

  Widget _buildProfileCard(S s) {
    final initials = _displayName.isNotEmpty
        ? _displayName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : 'U';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.22),
            Colors.white.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Colors.white, Color(0xFFF5F5F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: _gradientStart,
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _displayName.isNotEmpty ? _displayName : 'UZTEXPRO',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 0.3,
                shadows: [
                  Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 4),
                ],
              ),
            ),
            if (_email.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.email_outlined, color: Colors.white.withOpacity(0.7), size: 14),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _email,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (_login.isNotEmpty && _login != _displayName) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline, color: Colors.white.withOpacity(0.6), size: 13),
                  const SizedBox(width: 6),
                  Text(
                    _login,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.business_center_outlined, color: Colors.white.withOpacity(0.8), size: 14),
                  const SizedBox(width: 8),
                  Text(
                    s.paymentSystem,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4, height: 18,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              shadows: [
                Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingButton(
    IconData icon,
    String title,
    String subtitle,
    Color iconColor, {
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDarkBtn = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkBtn ? theme.colorScheme.surface : Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: onSurface.withOpacity(0.55),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: onSurface.withOpacity(0.3),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeButton(S s) {
    final theme = Theme.of(context);
    final isDarkBtn = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkBtn ? theme.colorScheme.surface : Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B1FA2).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.palette, color: Color(0xFF7B1FA2), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.theme,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isDark ? s.darkTheme : s.lightTheme,
                          style: TextStyle(
                            color: onSurface.withOpacity(0.55),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isDark,
                    activeColor: const Color(0xFF7B1FA2),
                    onChanged: (value) async {
                      themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                      await _storage.write(key: 'isDarkTheme', value: value.toString());
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVersionInfo(S s) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.white.withOpacity(0.8)),
            const SizedBox(width: 8),
            Text(
              s.appVersionLabel(_version),
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(S s) {
    final currentLang = localeNotifier.value.languageCode;
    String selectedLang = currentLang;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF6C00).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.language, color: Color(0xFFEF6C00), size: 24),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          s.selectLanguage,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ..._languages.map((lang) {
                      final isSelected = selectedLang == lang['code'];
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedLang = lang['code']!),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _gradientStart.withOpacity(0.1)
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? _gradientStart : Theme.of(context).colorScheme.outline,
                              width: 1.5,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: RadioListTile<String>(
                              value: lang['code']!,
                              groupValue: selectedLang,
                              activeColor: _gradientStart,
                              onChanged: (v) => setDialogState(() => selectedLang = v!),
                              title: Text(
                                lang['name']!,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected
                                      ? _gradientStart
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                lang['desc']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(
                            s.cancel,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            localeNotifier.value = Locale(selectedLang);
                            Navigator.of(ctx).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _gradientStart,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: Text(s.save, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAboutDialog(S s) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_gradientStart, _gradientEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _gradientStart.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text("U", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("UztexPro", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  s.versionLabel(_version),
                  style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text("© 2026 UztexPro.", style: TextStyle(fontSize: 13)),
                      const SizedBox(height: 8),
                      Text(
                        s.allRightsReserved,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gradientStart,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(s.close, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
