import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
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
      duration: const Duration(milliseconds: 450),
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
            _displayName = fullName.isNotEmpty
                ? fullName
                : (user['username'] as String? ?? '');
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
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(top: -60, right: -40, child: _circle(200, 0.06)),
              Positioned(bottom: 60, left: -70, child: _circle(220, 0.05)),
              Positioned(top: 240, right: 20, child: _circle(60, 0.04)),
              SafeArea(
                child: FadeTransition(
                  opacity: _animation,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildHeader(s),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                          children: [
                            _buildProfileCard(s),
                            const SizedBox(height: 28),
                            _buildSectionHeader(s.generalSettings),
                            const SizedBox(height: 10),
                            _buildLanguageSelector(s),
                            const SizedBox(height: 28),
                            _buildSectionHeader(s.appearance),
                            const SizedBox(height: 10),
                            _buildThemeButton(s),
                            const SizedBox(height: 36),
                            _buildVersionInfo(s),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(S s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        s.settingsTitle,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _circle(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );

  Widget _buildProfileCard(S s) {
    final initials = _displayName.isNotEmpty
        ? _displayName
              .split(' ')
              .map((w) => w.isNotEmpty ? w[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : 'U';

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 18,
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
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(0, 1),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            if (_email.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.email_outlined,
                    color: Colors.white.withOpacity(0.65),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _email,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
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
                  Icon(
                    Icons.person_outline,
                    color: Colors.white.withOpacity(0.55),
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _login,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.22),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.business_center_outlined,
                    color: Colors.white.withOpacity(0.75),
                    size: 13,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    s.paymentSystem,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
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
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.4,
              shadows: const [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector(S s) {
    final currentCode = localeNotifier.value.languageCode;
    final selectedIndex = _languages
        .indexWhere((lang) => lang['code'] == currentCode)
        .clamp(0, _languages.length - 1);

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.language_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.language,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        s.languageDesc,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AdaptiveSegmentedControl(
              labels: _languages
                  .map((lang) => lang['code']!.toUpperCase())
                  .toList(),
              selectedIndex: selectedIndex,
              color: _gradientStart,
              onValueChanged: (index) {
                final code = _languages[index]['code']!;
                localeNotifier.value = Locale(code);
                _storage.write(key: 'locale', value: code);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeButton(S s) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;
        return _GlassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.theme,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isDark ? s.darkTheme : s.lightTheme,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                AdaptiveSwitch(
                  value: isDark,
                  // A pure-white "on" track blends into the light theme's
                  // translucent white glass card, leaving almost no visible
                  // contrast — use the brand accent instead, which reads
                  // clearly against both the light and dark gradients.
                  activeColor: _gradientStart,
                  thumbColor: Colors.white,
                  onChanged: (value) async {
                    themeNotifier.value = value
                        ? ThemeMode.dark
                        : ThemeMode.light;
                    await _storage.write(
                      key: 'isDarkTheme',
                      value: value.toString(),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVersionInfo(S s) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAboutDialog(s),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
                const SizedBox(width: 7),
                Text(
                  s.appVersionLabel(_version),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(S s) {
    final copyright = DateTime.now().year > 2026
        ? '© 2026–${DateTime.now().year} UztexPro.'
        : '© 2026 UztexPro.';

    AdaptiveAlertDialog.show(
      context: context,
      title: s.versionLabel(_version),
      message: '$copyright\n${s.allRightsReserved}',
      icon: PlatformInfo.isIOS26OrHigher()
          ? 'info.circle.fill'
          : Icons.info_outline_rounded,
      iconColor: _gradientStart,
      iconSize: 40,
      actions: [
        AlertAction(
          title: s.close,
          onPressed: () {},
          style: AlertActionStyle.cancel,
        ),
      ],
    );
  }
}

// ── Reusable glass card ─────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.13),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withOpacity(0.22),
                width: 0.8,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

