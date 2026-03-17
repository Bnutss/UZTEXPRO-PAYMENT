import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'app_storage.dart';
import 'package:uztexpro_payment/main_page.dart';
import 'package:uztexpro_payment/main.dart';
import 'app_strings.dart';
import 'locale_notifier.dart';

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

  final Color primaryColor = const Color(0xFFFF9800);
  final Color secondaryColor = const Color(0xFFFF5722);
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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
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
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  Future<String?> attemptLogIn(String username, String password) async {
    try {
      var res = await http.post(
        Uri.parse("$API/auth/login/"),
        body: {"username": username, "password": password},
      ).timeout(
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
      if (username != null && password != null && username.isNotEmpty && password.isNotEmpty) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
          ],
        ),
        backgroundColor: accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _navigateToMainPage(String jwt) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => MainPageScreen(jwtToken: jwt)),
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
      ),
      child: Scaffold(
        body: isLoading ? _buildLoadingView(s) : _buildLoginView(s),
      ),
    );
  }

  Widget _buildLoadingView(S s) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
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
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              s.pleaseWait,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginView(S s) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildAppBar(s),
            Expanded(child: _buildLoginForm(s)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(S s) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "UZTEXPRO",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 3)],
                ),
              ),
              Text(
                s.paymentSystem,
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9), letterSpacing: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(S s) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Card(
              elevation: 16,
              shadowColor: Colors.black.withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 36),
                    _buildWelcomeText(s),
                    const SizedBox(height: 32),
                    _buildTextField(
                      controller: _usernameController,
                      icon: Icons.person_outline,
                      label: s.loginField,
                      isPassword: false,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _passwordController,
                      icon: Icons.lock_outline,
                      label: s.passwordField,
                      isPassword: true,
                    ),
                    const SizedBox(height: 32),
                    _buildLoginButton(s),
                    if (_canCheckBiometrics) ...[
                      const SizedBox(height: 24),
                      _buildBiometricToggle(s),
                      if (_useBiometrics) ...[
                        const SizedBox(height: 20),
                        _buildBiometricLoginButton(s),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.4),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.2),
          ),
          child: const Icon(Icons.security, size: 42, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildWelcomeText(S s) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        Text(
          s.welcome,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: onSurface),
        ),
        const SizedBox(height: 8),
        Text(
          s.signInAccount,
          style: TextStyle(fontSize: 16, color: onSurface.withOpacity(0.6)),
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
      style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
        floatingLabelStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        prefixIcon: Icon(icon, color: primaryColor),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  color: accentColor,
                ),
                onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
              )
            : null,
        filled: true,
      ),
    );
  }

  Widget _buildLoginButton(S s) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(
          s.signIn,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricToggle(S s) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
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
                    color: accentColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.fingerprint, color: accentColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.biometricAuth,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.useFingerprint,
                        style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _useBiometrics,
                  onChanged: toggleBiometricPreference,
                  activeColor: accentColor,
                  activeTrackColor: accentColor.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricLoginButton(S s) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor, width: 1.5),
      ),
      child: ElevatedButton.icon(
        onPressed: () => loginWithBiometrics(context),
        icon: const Icon(Icons.fingerprint, size: 24),
        label: Text(
          s.signInBiometric,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: accentColor,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
