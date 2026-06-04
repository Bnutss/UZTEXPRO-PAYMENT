import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';

class ConfidentialityPage extends StatefulWidget {
  @override
  _ConfidentialityPageState createState() => _ConfidentialityPageState();
}

class _ConfidentialityPageState extends State<ConfidentialityPage> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  bool _isAuthenticated = false;
  bool _useBiometrics = false;
  List<BiometricType> _availableBiometrics = [];

  static const Color _gradientStart = Color(0xFFFF8C00);
  static const Color _gradientEnd = Color(0xFFCC1500);

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _loadBiometricPreference();
    localeNotifier.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() => setState(() {});

  @override
  void dispose() {
    localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    bool canCheckBiometrics;
    List<BiometricType> availableBiometrics;
    try {
      canCheckBiometrics = await auth.canCheckBiometrics;
      availableBiometrics = await auth.getAvailableBiometrics();
    } catch (e) {
      canCheckBiometrics = false;
      availableBiometrics = <BiometricType>[];
    }
    if (!mounted) return;
    setState(() {
      _canCheckBiometrics = canCheckBiometrics;
      _availableBiometrics = availableBiometrics;
    });
  }

  Future<void> _loadBiometricPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? useBiometrics = prefs.getBool('useBiometrics');
    setState(() {
      _useBiometrics = useBiometrics ?? false;
    });
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    final s = S.of(context);
    try {
      authenticated = await auth.authenticate(
        localizedReason: s.authReason,
      );
    } catch (e) {
      authenticated = false;
    }
    if (!mounted) return;
    setState(() {
      _isAuthenticated = authenticated;
    });
  }

  Future<void> _toggleBiometricPreference(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _useBiometrics = value;
    });
    await prefs.setBool('useBiometrics', value);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            s.privacyTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Builder(
            builder: (ctx) {
              final isDarkAppBar = Theme.of(ctx).brightness == Brightness.dark;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDarkAppBar
                        ? [const Color(0xFF3D1800), const Color(0xFF1F0000)]
                        : [_gradientStart, _gradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
              );
            },
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
        ),
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: Theme.of(context).brightness == Brightness.dark
                      ? [const Color(0xFF3D1800), const Color(0xFF1F0000)]
                      : [_gradientStart, _gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              bottom: 80,
              left: -70,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              top: 180,
              right: 30,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _isAuthenticated
                    ? _buildAuthenticatedContent(s)
                    : _buildUnauthenticatedContent(s),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthenticatedContent(S s) {
    return SizedBox(
      key: const ValueKey('authenticated'),
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.18),
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.security, size: 50, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              s.privacySettings,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 4)],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 44),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _canCheckBiometrics
                      ? () => _toggleBiometricPreference(!_useBiometrics)
                      : null,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.fingerprint, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            s.useBiometric,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: _useBiometrics,
                          onChanged: _canCheckBiometrics ? _toggleBiometricPreference : null,
                          activeColor: Colors.white,
                          activeTrackColor: Colors.white.withOpacity(0.4),
                          inactiveThumbColor: Colors.white.withOpacity(0.6),
                          inactiveTrackColor: Colors.white.withOpacity(0.2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnauthenticatedContent(S s) {
    return SizedBox(
      key: const ValueKey('unauthenticated'),
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.18),
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 26,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.lock_outline, size: 54, color: Colors.white),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              s.biometricRequired,
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint, size: 26),
                label: Text(
                  s.authenticate,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _gradientStart,
                  elevation: 5,
                  shadowColor: Colors.black.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
