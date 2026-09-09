import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../core/storage/app_storage.dart';
import 'package:uztexpro_payment/features/home/menu_page.dart';
import 'package:uztexpro_payment/main.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/brand_transition_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final LocalAuthentication auth = LocalAuthentication();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AppStorage storage = AppStorage();

  bool isLoading = false;
  bool isPasswordVisible = false;
  bool _canCheckBiometrics = false;
  bool _useBiometrics = false;
  bool _showSuccessTransition = false;

  final Color primaryColor = AppColors.brandOrange;
  final Color secondaryColor = AppColors.brandRed;

  @override
  void initState() {
    super.initState();
    _initializeApp();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
          ),
        );

    _animationController.forward();
    localeNotifier.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() => setState(() {});

  Future<void> _initializeApp() async {
    await fetchSecureStorageData();
    await checkBiometrics();
    await loadBiometricPreference();

    if (_useBiometrics && _canCheckBiometrics) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        loginWithBiometrics(context);
      });
    }
  }

  Future<void> checkBiometrics() async {
    try {
      final canCheck = await auth.canCheckBiometrics;
      final isSupported = await auth.isDeviceSupported();
      _canCheckBiometrics = canCheck || isSupported;
    } catch (e) {
      _canCheckBiometrics = false;
    }
  }

  Future<void> loadBiometricPreference() async {
    String? useBiometrics = await storage.read(key: 'useBiometrics');
    setState(() {
      _useBiometrics = useBiometrics == 'true';
    });
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await auth.authenticate(
        localizedReason: S.of(context).authLoginReason,
      );
    } catch (e) {
      return false;
    }
  }

  Future<String?> attemptLogIn(String username, String password) async {
    try {
      var res = await http
          .post(
            Uri.parse("$API/auth/login/"),
            body: {"username": username, "password": password},
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => http.Response('Timeout', 408),
          );
      if (res.statusCode == 200) return res.body;
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> fetchSecureStorageData() async {
    final username = await storage.read(key: 'username') ?? '';
    final password = await storage.read(key: 'password') ?? '';
    _usernameController.text = username;
    _passwordController.text = password;
  }

  Future<void> loginWithBiometrics(BuildContext context) async {
    final s = S.of(context);
    if (!_canCheckBiometrics) {
      _showSnackBar(s.biometricNotSupported);
      return;
    }

    bool authenticated = await authenticateWithBiometrics();
    if (authenticated) {
      final username = await storage.read(key: 'username');
      final password = await storage.read(key: 'password');
      if (username != null &&
          password != null &&
          username.isNotEmpty &&
          password.isNotEmpty) {
        setState(() => isLoading = true);
        var jwt = await attemptLogIn(username, password);
        if (jwt != null) {
          await storage.write(key: "jwt", value: jwt);
          await _completeLogin(jwt);
        } else {
          setState(() => isLoading = false);
          _showSnackBar(s.loginError);
        }
      } else {
        _showSnackBar(s.credentialsNotFound);
      }
    }
  }

  void _showSnackBar(String message) {
    _ErrorBanner.show(context, message: message);
  }

  void _navigateToMainPage(String jwt) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => MenuPage(jwtToken: jwt)),
      (route) => false,
    );
  }

  // Shows the branded success transition instead of jumping straight to the
  // main screen after a successful login (mirrors the web app's post-signin
  // BrandLoadingScreen transition).
  Future<void> _completeLogin(String jwt) async {
    if (!mounted) return;
    setState(() {
      isLoading = false;
      _showSuccessTransition = true;
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _navigateToMainPage(jwt);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            _buildLoginView(s),
            if (isLoading || _showSuccessTransition)
              BrandTransitionScreen(
                title: _showSuccessTransition
                    ? s.loginSuccessTitle
                    : s.enterUztexpro,
                subtitle: _showSuccessTransition
                    ? s.loginSuccessSubtitle
                    : s.pleaseWait,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginView(S s) {
    return Container(
      color: AppColors.groupedBackground,
      child: SafeArea(child: _buildLoginForm(s)),
    );
  }

  Widget _buildLoginForm(S s) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildLogo(),
                const SizedBox(height: 20),
                _buildWelcomeText(s),
                const SizedBox(height: 32),
                _buildTextField(
                  controller: _usernameController,
                  icon: Icons.person_outline,
                  label: s.loginField,
                  isPassword: false,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _passwordController,
                  icon: Icons.lock_outline,
                  label: s.passwordField,
                  isPassword: true,
                ),
                const SizedBox(height: 32),
                _buildLoginButton(s),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset('assets/icon/logo.png', fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildWelcomeText(S s) {
    return Column(
      children: [
        Text(
          s.welcome,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C1C1E),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.signInAccount,
          style: const TextStyle(fontSize: 16, color: Color(0xFF8A8A8E)),
        ),
      ],
    );
  }

  static const BorderRadius _fieldRadius = BorderRadius.all(
    Radius.circular(16),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required bool isPassword,
  }) {
    // AdaptiveTextField's own default look (8pt radius, tight 8pt vertical
    // padding, no border) reads as cramped and plain next to the rest of
    // this screen's cards — the widget explicitly exposes decoration/padding
    // overrides for exactly this, so give it the same white
    // rounded-and-bordered card language as everything else here instead of
    // its bare default box.
    return AdaptiveTextField(
      controller: controller,
      obscureText: isPassword && !isPasswordVisible,
      placeholder: label,
      style: const TextStyle(fontSize: 16, color: Color(0xFF1C1C1E)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      cupertinoDecoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _fieldRadius,
        border: Border.all(color: AppColors.groupedBackground, width: 1),
      ),
      decoration: InputDecoration(
        hintText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: _fieldRadius,
          borderSide: const BorderSide(color: AppColors.groupedBackground),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _fieldRadius,
          borderSide: const BorderSide(color: AppColors.groupedBackground),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _fieldRadius,
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF8A8A8E)),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(
                isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF8A8A8E),
              ),
              onPressed: () =>
                  setState(() => isPasswordVisible = !isPasswordVisible),
            )
          : null,
    );
  }

  Widget _buildLoginButton(S s) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AdaptiveButton(
        onPressed: _login,
        label: s.signIn,
        color: primaryColor,
        textColor: Colors.white,
        style: AdaptiveButtonStyle.filled,
        size: AdaptiveButtonSize.large,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  Future<void> _login() async {
    final s = S.of(context);
    FocusScope.of(context).unfocus();

    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar(s.enterLoginPassword);
      return;
    }

    setState(() => isLoading = true);

    var username = _usernameController.text.trim();
    var password = _passwordController.text;

    try {
      var jwt = await attemptLogIn(username, password);
      if (jwt != null) {
        await storage.write(key: "username", value: username);
        await storage.write(key: "password", value: password);
        await storage.write(key: "jwt", value: jwt);
        await _completeLogin(jwt);
      } else {
        setState(() => isLoading = false);
        _showSnackBar(s.wrongCredentials);
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar(s.connectionError);
    }
  }
}

// ── Error banner ─────────────────────────────────────────────────────────
//
// Replaces AdaptiveSnackBar for login errors: the plugin's message text
// picked up an unwanted underline decoration on iOS with no exposed way to
// override it, so this is a small self-drawn banner instead — full control
// over the TextStyle (decoration explicitly set to none) and matches the
// app's own red/orange palette rather than the plugin's generic error color.

class _ErrorBanner {
  static void show(BuildContext context, {required String message}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) =>
          _ErrorBannerWidget(message: message, onDismiss: () => entry.remove()),
    );
    overlay.insert(entry);
  }
}

class _ErrorBannerWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBannerWidget({required this.message, required this.onDismiss});

  @override
  State<_ErrorBannerWidget> createState() => _ErrorBannerWidgetState();
}

class _ErrorBannerWidgetState extends State<_ErrorBannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _timer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _timer = Timer(const Duration(seconds: 3), _dismiss);
  }

  Future<void> _dismiss() async {
    if (_dismissed) return;
    _dismissed = true;
    _timer?.cancel();
    if (mounted) await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              // This overlay entry sits outside any Scaffold/Material
              // ancestor, so Text here has none to inherit from — without
              // this, Flutter silently falls back to its debug "missing
              // Material" text style (yellow with an underline).
              child: Material(
                type: MaterialType.transparency,
                child: GestureDetector(
                  onTap: _dismiss,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFCC1500), Color(0xFF7A0E00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
