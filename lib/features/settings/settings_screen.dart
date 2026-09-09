import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../core/storage/app_storage.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';

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
  final LocalAuthentication _auth = LocalAuthentication();

  String _displayName = '';
  String _email = '';
  String _login = '';
  String _version = '';
  bool _canCheckBiometrics = false;
  bool _useBiometrics = false;
  // Which biometric icon/label to show — detected per device instead of
  // hardcoding a fingerprint (iPhones with Face ID have no Touch ID sensor
  // at all, so "fingerprint" would be flatly wrong there).
  BiometricType? _biometricType;

  static const Color _gradientStart = AppColors.brandOrange;
  static const Color _gradientEnd = AppColors.brandRed;

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
    _checkBiometrics();
    _loadBiometricPreference();
    localeNotifier.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() => setState(() {});

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      final available = await _auth.getAvailableBiometrics();
      BiometricType? type;
      if (available.contains(BiometricType.face)) {
        type = BiometricType.face;
      } else if (available.contains(BiometricType.fingerprint)) {
        type = BiometricType.fingerprint;
      } else if (available.isNotEmpty) {
        type = available.first;
      }
      if (mounted) {
        setState(() {
          _canCheckBiometrics = canCheck || isSupported;
          _biometricType = type;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _canCheckBiometrics = false);
    }
  }

  Future<void> _loadBiometricPreference() async {
    final useBiometrics = await _storage.read(key: 'useBiometrics');
    if (mounted) setState(() => _useBiometrics = useBiometrics == 'true');
  }

  Future<void> _toggleBiometricPreference(bool value) async {
    setState(() => _useBiometrics = value);
    await _storage.write(key: 'useBiometrics', value: value.toString());
  }

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

  // No own Scaffold/AnnotatedRegion here: this screen is only ever mounted
  // as a tab body inside MenuPage's IndexedStack, which already paints the
  // shared background + status bar style for every tab.
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
                if (_canCheckBiometrics) ...[
                  const SizedBox(height: 12),
                  _buildBiometricToggle(s),
                ],
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
          color: Color(0xFF1C1C1E),
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
                color: _gradientStart.withOpacity(0.12),
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
                color: Color(0xFF1C1C1E),
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 0.3,
              ),
            ),
            if (_email.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.email_outlined,
                    color: Color(0xFF8A8A8E),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF8A8A8E),
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
                  const Icon(
                    Icons.person_outline,
                    color: Color(0xFFB0B0B5),
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _login,
                    style: const TextStyle(
                      color: Color(0xFFB0B0B5),
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
                color: _gradientStart.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.business_center_outlined,
                    color: _gradientEnd,
                    size: 13,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    s.paymentSystem,
                    style: const TextStyle(
                      color: _gradientEnd,
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
              color: _gradientStart,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1C1C1E),
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.4,
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
                    color: _gradientStart.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.language_rounded,
                    color: _gradientStart,
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
                          color: Color(0xFF1C1C1E),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        s.languageDesc,
                        style: const TextStyle(
                          color: Color(0xFF8A8A8E),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildLanguageControl(selectedIndex),
          ],
        ),
      ),
    );
  }

  void _selectLanguage(int index) {
    HapticFeedback.selectionClick();
    final code = _languages[index]['code']!;
    localeNotifier.value = Locale(code);
    _storage.write(key: 'locale', value: code);
  }

  Widget _buildLanguageControl(int selectedIndex) {
    final labels = _languages.map((lang) => lang['code']!.toUpperCase()).toList();

    // AdaptiveSegmentedControl renders a Material 3 SegmentedButton on
    // Android, but the app theme has useMaterial3 disabled — that mismatch
    // is what made it look off here. A plain custom pill track matches
    // this card's own glass styling instead, same as the iOS control does
    // natively.
    if (Platform.isIOS) {
      return AdaptiveSegmentedControl(
        labels: labels,
        selectedIndex: selectedIndex,
        color: _gradientStart,
        onValueChanged: _selectLanguage,
      );
    }
    return _LanguageSegments(
      labels: labels,
      selectedIndex: selectedIndex,
      onChanged: _selectLanguage,
    );
  }

  Widget _buildBiometricToggle(S s) {
    final isFaceId = _biometricType == BiometricType.face;
    final icon = isFaceId ? Icons.face_rounded : Icons.fingerprint;
    final description = isFaceId ? s.useFaceId : s.useFingerprint;

    return _GlassCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _toggleBiometricPreference(!_useBiometrics),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _gradientStart.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: _gradientStart, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.biometricAuth,
                        style: const TextStyle(
                          color: Color(0xFF1C1C1E),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Color(0xFF8A8A8E),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                AdaptiveSwitch(
                  value: _useBiometrics,
                  onChanged: _toggleBiometricPreference,
                  activeColor: _gradientStart,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const TextStyle _versionTextStyle = TextStyle(
    color: Color(0xFF8A8A8E),
    fontSize: 12,
    decoration: TextDecoration.none,
  );

  Widget _buildVersionInfo(S s) {
    final label = s.appVersionLabel(_version);
    // The real native iOS 26 button (no minSize) has no way to report its
    // UIKit-rendered content size back to Flutter's layout, so inside a
    // Center it just expands to the full available width instead of
    // hugging the icon+label like the old Flutter-drawn fallback did.
    // Measure the label ourselves and pass that as an explicit width.
    final textPainter = TextPainter(
      text: TextSpan(text: label, style: _versionTextStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    const iconWidth = 14.0;
    const iconGap = 7.0;
    const horizontalPadding = 18.0 * 2;
    final width = iconWidth + iconGap + textPainter.width + horizontalPadding;

    return Center(
      child: AdaptiveButton.child(
        onPressed: () => _showAboutDialog(s),
        style: AdaptiveButtonStyle.glass,
        size: AdaptiveButtonSize.small,
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(30),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 18),
        minSize: Size(width, 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline,
              size: iconWidth,
              color: Color(0xFF8A8A8E),
            ),
            const SizedBox(width: iconGap),
            Text(label, style: _versionTextStyle),
          ],
        ),
      ),
    );
  }

  // Native AdaptiveAlertDialog instead of a hand-rolled dark glass card: now
  // that the app is a standard light theme there's no bespoke look left to
  // preserve, and the native alert gets correct light/dark text for free.
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
      actions: [
        AlertAction(
          title: s.close,
          style: AlertActionStyle.primary,
          onPressed: () {},
        ),
      ],
    );
  }
}

// ── Reusable card ────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEDED), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Android's stand-in for [AdaptiveSegmentedControl]: a plain pill-track
/// selector matching iOS's native segmented control look — light gray
/// track, white selected pill, brand-red selected label.
class _LanguageSegments extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _LanguageSegments({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.brandRed
                        : const Color(0xFF8A8A8E),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
