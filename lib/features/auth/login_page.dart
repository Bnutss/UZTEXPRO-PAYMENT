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

  final Color primaryColor = const Color(0xFFFF8C00);
  final Color secondaryColor = const Color(0xFFCC1500);
  final Color accentColor = const Color(0xFF6A1B9A);

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

  Future<void> toggleBiometricPreference(bool value) async {
    setState(() {
      _useBiometrics = value;
    });
    await storage.write(key: 'useBiometrics', value: value.toString());
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
          _navigateToMainPage(jwt);
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
    AdaptiveSnackBar.show(
      context,
      message: message,
      type: AdaptiveSnackBarType.error,
    );
  }

  void _navigateToMainPage(String jwt) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => MenuPage(jwtToken: jwt)),
      (route) => false,
    );
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
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: isLoading ? _buildLoadingView(s) : _buildLoginView(s),
      ),
    );
  }

  Widget _buildLoadingView(S s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF3D1800), const Color(0xFF1F0000)]
              : [const Color(0xFFFF8C00), const Color(0xFFCC1500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                backgroundColor: Colors.white.withOpacity(0.2),
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              s.enterUztexpro,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.pleaseWait,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginView(S s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF3D1800), const Color(0xFF1F0000)]
                  : [const Color(0xFFFF8C00), const Color(0xFFCC1500)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -50,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
        ),
        Positioned(
          top: 120,
          right: 30,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          left: -80,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
        ),
        Positioned(
          bottom: 180,
          right: -30,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),
        SafeArea(child: _buildLoginForm(s)),
      ],
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
                if (_canCheckBiometrics) ...[
                  const SizedBox(height: 20),
                  _buildBiometricToggle(s),
                  if (_useBiometrics) ...[
                    const SizedBox(height: 16),
                    _buildBiometricLoginButton(s),
                  ],
                ],
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
        child: Image.asset('assets/icon/uztexpro.png', fit: BoxFit.cover),
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
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black26,
                offset: Offset(0, 1),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.signInAccount,
          style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.82)),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required bool isPassword,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !isPasswordVisible,
      style: const TextStyle(fontSize: 16, color: Colors.white),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        floatingLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.9)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                ),
                onPressed: () =>
                    setState(() => isPasswordVisible = !isPasswordVisible),
              )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.15),
      ),
    );
  }

  Widget _buildLoginButton(S s) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AdaptiveButton(
        onPressed: _login,
        label: s.signIn,
        textColor: Colors.white,
        style: AdaptiveButtonStyle.glass,
        size: AdaptiveButtonSize.large,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  Widget _buildBiometricToggle(S s) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => toggleBiometricPreference(!_useBiometrics),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fingerprint,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.biometricAuth,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.useFingerprint,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                AdaptiveSwitch(
                  value: _useBiometrics,
                  onChanged: toggleBiometricPreference,
                  activeColor: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricLoginButton(S s) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: AdaptiveButton.child(
        onPressed: () => loginWithBiometrics(context),
        style: AdaptiveButtonStyle.glass,
        size: AdaptiveButtonSize.large,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fingerprint, size: 22, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              s.signInBiometric,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: Colors.white,
              ),
            ),
          ],
        ),
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
        _navigateToMainPage(jwt);
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
