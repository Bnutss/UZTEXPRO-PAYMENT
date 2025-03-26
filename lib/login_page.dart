import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uztexpro_payment/main_page.dart';
import 'package:uztexpro_payment/main.dart';

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
  final FlutterSecureStorage storage = FlutterSecureStorage();

  bool isLoading = false;
  bool isPasswordVisible = false;
  bool _canCheckBiometrics = false;
  bool _useBiometrics = false;

  // Brand colors
  final Color primaryColor = const Color(0xFFFF9800);
  final Color secondaryColor = const Color(0xFFFF5722);
  final Color accentColor = const Color(0xFF6A1B9A);
  final Color backgroundColor = const Color(0xFFF5F5F5);
  final Color cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _initializeApp();

    // Configure animations
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
  }

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
      _canCheckBiometrics = await auth.canCheckBiometrics;
    } catch (e) {
      debugPrint("Error checking biometrics: $e");
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
        localizedReason: 'Используйте биометрию для входа в приложение',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      debugPrint("Authentication error: $e");
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
        onTimeout: () {
          return http.Response('Timeout', 408);
        },
      );

      if (res.statusCode == 200) {
        return res.body;
      } else {
        return null;
      }
    } on Exception catch (e) {
      debugPrint("Login error: $e");
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
    if (!_canCheckBiometrics) {
      _showSnackBar('Биометрия не поддерживается на этом устройстве');
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
        setState(() {
          isLoading = true;
        });

        var jwt = await attemptLogIn(username, password);
        if (jwt != null) {
          await storage.write(key: "jwt", value: jwt);
          _navigateToMainPage(jwt);
        } else {
          setState(() {
            isLoading = false;
          });
          _showSnackBar(
              'Ошибка входа. Проверьте учетные данные или подключение.');
        }
      } else {
        _showSnackBar('Учетные данные не найдены. Войдите вручную.');
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
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: isLoading ? _buildLoadingView() : _buildLoginView(),
      ),
    );
  }

  Widget _buildLoadingView() {
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
            const Text(
              "Вход в UZTEXPRO",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Пожалуйста, подождите...",
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

  Widget _buildLoginView() {
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
            _buildAppBar(),
            Expanded(
              child: _buildLoginForm(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
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
            child: const Icon(
              Icons.account_balance_wallet,
              color: Colors.white,
              size: 32,
            ),
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
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(1, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
              Text(
                "Платежная система",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Card(
              elevation: 16,
              shadowColor: Colors.black.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.0),
              ),
              child: Container(
                padding: const EdgeInsets.all(28.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24.0),
                  color: cardColor,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    _buildLogo(),
                    const SizedBox(height: 36),
                    _buildWelcomeText(),
                    const SizedBox(height: 32),
                    _buildTextField(
                      controller: _usernameController,
                      icon: Icons.person_outline,
                      label: 'Логин',
                      isPassword: false,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _passwordController,
                      icon: Icons.lock_outline,
                      label: 'Пароль',
                      isPassword: true,
                    ),
                    const SizedBox(height: 32),
                    _buildLoginButton(),
                    if (_canCheckBiometrics) ...[
                      const SizedBox(height: 24),
                      _buildBiometricToggle(),
                      if (_useBiometrics) ...[
                        const SizedBox(height: 20),
                        _buildBiometricLoginButton(),
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
          child: const Icon(
            Icons.security,
            size: 42,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        const Text(
          "Добро пожаловать",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF424242),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Войдите в свой аккаунт",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !isPasswordVisible,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade700),
          floatingLabelStyle:
              TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          prefixIcon: Icon(icon, color: primaryColor),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                    color: accentColor,
                  ),
                  onPressed: () {
                    setState(() {
                      isPasswordVisible = !isPasswordVisible;
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text(
          "ВОЙТИ",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
                  child: Icon(
                    Icons.fingerprint,
                    color: accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Биометрическая аутентификация',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Использовать отпечаток пальца для входа',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
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

  Widget _buildBiometricLoginButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor,
          width: 1.5,
        ),
      ),
      child: ElevatedButton.icon(
        onPressed: () => loginWithBiometrics(context),
        icon: const Icon(
          Icons.fingerprint,
          size: 24,
        ),
        label: const Text(
          'ВОЙТИ С БИОМЕТРИЕЙ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: accentColor,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();

    // Validate fields
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Введите логин и пароль');
      return;
    }

    setState(() {
      isLoading = true;
    });

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
        setState(() {
          isLoading = false;
        });
        _showSnackBar('Неверный логин или пароль');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showSnackBar('Ошибка подключения. Проверьте интернет.');
    }
  }
}
