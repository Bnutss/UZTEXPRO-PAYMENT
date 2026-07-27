import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../core/storage/app_storage.dart';
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

  // No own Scaffold/gradient/AnnotatedRegion here: this screen is only ever
  // mounted as a tab body inside MenuPage's IndexedStack, which already
  // paints the shared background gradient + glow circles + status bar style
  // for every tab. A second full-bleed gradient Container nested inside its
  // own Scaffold used to duplicate that background starting partway down the
  // screen — since each gradient positions itself relative to its own
  // (different-sized) box, the colors didn't line up at the seam and showed
  // as a visible hard-edged rectangle cutting through the header's glow
  // circle. Just build the tab content directly, like the other tabs do.
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return FadeTransition(
      opacity: _animation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                const SizedBox(height: 36),
                _buildVersionInfo(s),
              ],
            ),
          ),
        ],
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

  Widget _buildVersionInfo(S s) {
    return Center(
      child: AdaptiveButton.child(
        onPressed: () => _showAboutDialog(s),
        style: AdaptiveButtonStyle.glass,
        size: AdaptiveButtonSize.small,
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 18),
        // useNative:false keeps this a plain Flutter-drawn button instead of
        // a real native UIButton — the native iOS 26 path was picking up an
        // unwanted underline under the label (iOS accessibility auto-styling
        // real UIButtons), which a Flutter-drawn button can't be affected by.
        useNative: false,
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
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(S s) {
    final copyright = DateTime.now().year > 2026
        ? '© 2026–${DateTime.now().year} UztexPro.'
        : '© 2026 UztexPro.';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: s.close,
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, _) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, _, _) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
            child: _AboutDialogCard(
              version: s.versionLabel(_version),
              copyright: copyright,
              allRightsReserved: s.allRightsReserved,
              closeLabel: s.close,
              accentStart: _gradientStart,
              accentEnd: _gradientEnd,
            ),
          ),
        );
      },
    );
  }
}

// ── About / version dialog ──────────────────────────────────────────────────
//
// Built as an app-styled glass card instead of AdaptiveAlertDialog. The
// native iOS 26 alert renders its labels with the system's real light/dark
// UITraitCollection regardless of the app's forced-dark Flutter theme, which
// on a device actually set to Light Mode produced barely-readable black/gray
// text over our dark blur. A fully in-Flutter dialog sidesteps that mismatch
// and matches the rest of the app's frosted-glass look.

class _AboutDialogCard extends StatelessWidget {
  final String version;
  final String copyright;
  final String allRightsReserved;
  final String closeLabel;
  final Color accentStart;
  final Color accentEnd;

  const _AboutDialogCard({
    required this.version,
    required this.copyright,
    required this.allRightsReserved,
    required this.closeLabel,
    required this.accentStart,
    required this.accentEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              decoration: BoxDecoration(
                color: const Color(0xFF241208).withOpacity(0.92),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.16),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              // Text below has no Material ancestor otherwise (this dialog is
              // shown via showGeneralDialog, which doesn't provide one like
              // showDialog does) — without it, Flutter silently falls back to
              // its debug "missing Material" text style: yellow with an
              // underline, which is exactly the ugly text the version dialog
              // was showing.
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [accentStart, accentEnd],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentStart.withOpacity(0.45),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      version,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      copyright,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      allRightsReserved,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: AdaptiveButton(
                        onPressed: () => Navigator.of(context).pop(),
                        label: closeLabel,
                        textColor: Colors.white,
                        color: Colors.white,
                        style: AdaptiveButtonStyle.glass,
                        size: AdaptiveButtonSize.large,
                        borderRadius: BorderRadius.circular(13),
                        // The Cupertino fallback button (useNative: false)
                        // defaults to a large horizontal-only padding meant
                        // for full-size buttons, which doesn't fit the fixed
                        // 44pt height here and clipped the label. Keep it
                        // explicit and compact instead.
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        useNative: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
