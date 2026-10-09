import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
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
import '../../core/widgets/app_segmented_control.dart';
import 'widgets/brand_transition_screen.dart';
import 'widgets/ios_notification_banner.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

/// Outcome of a login request. A rejected password and an unreachable server
/// need different messages, so the page can't treat them both as "null".
class _LoginResult {
  final String? jwt;
  final bool wrongCredentials;

  const _LoginResult.ok(String this.jwt) : wrongCredentials = false;
  const _LoginResult.rejected() : jwt = null, wrongCredentials = true;
  const _LoginResult.unreachable() : jwt = null, wrongCredentials = false;
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late final AnimationController _shakeController;
  final LocalAuthentication auth = LocalAuthentication();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final AppStorage storage = AppStorage();

  bool isLoading = false;
  bool isPasswordVisible = false;
  bool _canCheckBiometrics = false;
  bool _useBiometrics = false;
  bool _showSuccessTransition = false;

  // Which fields to outline in red after a failed attempt. Cleared as soon
  // as the user edits the field again.
  bool _usernameError = false;
  bool _passwordError = false;

  final Color primaryColor = AppColors.brandOrange;

  static const _kLanguages = [
    ('ru', 'Русский'),
    ('en', 'English'),
    ('uz', "O'zbekcha"),
  ];

  @override
  void initState() {
    super.initState();
    _initializeApp();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
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

    _usernameController.addListener(() {
      if (_usernameError) setState(() => _usernameError = false);
    });
    _passwordController.addListener(() {
      if (_passwordError) setState(() => _passwordError = false);
    });
  }

  void _onLocaleChanged() => setState(() {});

  Future<void> _initializeApp() async {
    await fetchSecureStorageData();
    await checkBiometrics();
    await loadBiometricPreference();

    if (_useBiometrics && _canCheckBiometrics) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) loginWithBiometrics(context);
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
    if (!mounted) return;
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

  Future<_LoginResult> attemptLogIn(String username, String password) async {
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
      if (res.statusCode == 200) return _LoginResult.ok(res.body);
      if (res.statusCode == 400 ||
          res.statusCode == 401 ||
          res.statusCode == 403) {
        return const _LoginResult.rejected();
      }
      return const _LoginResult.unreachable();
    } catch (e) {
      return const _LoginResult.unreachable();
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
      _notify(s.biometricNotSupported);
      return;
    }

    bool authenticated = await authenticateWithBiometrics();
    if (!mounted) return;
    if (authenticated) {
      final username = await storage.read(key: 'username');
      final password = await storage.read(key: 'password');
      if (username != null &&
          password != null &&
          username.isNotEmpty &&
          password.isNotEmpty) {
        setState(() => isLoading = true);
        final result = await attemptLogIn(username, password);
        if (!mounted) return;
        if (result.jwt != null) {
          await storage.write(key: "jwt", value: result.jwt!);
          await _completeLogin(result.jwt!);
        } else {
          setState(() => isLoading = false);
          _notify(result.wrongCredentials ? s.loginError : s.connectionError);
        }
      } else {
        _notify(s.credentialsNotFound);
      }
    }
  }

  void _notify(String message) {
    IosNotificationBanner.show(context, title: 'UztexPro', message: message);
  }

  /// Error feedback in the iOS "wrong password" style: the form shakes and
  /// the device taps twice.
  void _shakeForm() {
    _shakeController.forward(from: 0);
    HapticFeedback.heavyImpact();
    Future.delayed(
      const Duration(milliseconds: 110),
      HapticFeedback.heavyImpact,
    );
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
    _shakeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  // ── UI ──────────────────────────────────────────────────────────────────

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
        backgroundColor: AppColors.groupedBackground,
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
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 32,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: _buildLoginForm(s),
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

  Widget _buildLoginForm(S s) {
    final showBiometric = _useBiometrics && _canCheckBiometrics;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLogo(),
        const SizedBox(height: 20),
        _buildWelcomeText(s),
        const SizedBox(height: 32),
        AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final t = _shakeController.value;
            final dx = math.sin(t * math.pi * 5) * 12 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: _buildCredentialsCard(s),
        ),
        const SizedBox(height: 24),
        _buildLoginButton(s),
        if (showBiometric) ...[
          const SizedBox(height: 8),
          _buildBiometricButton(s),
        ],
        const SizedBox(height: 28),
        _buildLanguagePicker(),
      ],
    );
  }

  Widget _buildLogo() {
    // Shrinks while the keyboard is up so the fields and the button stay on
    // screen on small phones.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final size = keyboardOpen ? 64.0 : 100.0;
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.23),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.23),
          child: Image.asset('assets/icon/logo.png', fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildWelcomeText(S s) {
    return Column(
      children: [
        Text(
          s.welcome,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: Color(0xFF1C1C1E),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          s.signInAccount,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: Color(0xFF8A8A8E)),
        ),
      ],
    );
  }

  /// Both fields in one grouped card separated by a hairline — the same
  /// shape iOS uses for sign-in forms. Turns red as a whole on error.
  Widget _buildCredentialsCard(S s) {
    final hasError = _usernameError || _passwordError;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasError ? const Color(0xFFFF3B30) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: AutofillGroup(
        child: Column(
          children: [
            _buildField(
              controller: _usernameController,
              focusNode: _usernameFocus,
              icon: Icons.person_outline_rounded,
              label: s.loginField,
              isPassword: false,
              hasError: _usernameError,
              hints: const [AutofillHints.username],
              action: TextInputAction.next,
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const Divider(
              height: 1,
              thickness: 0.6,
              indent: 52,
              color: Color(0xFFE5E5EA),
            ),
            _buildField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              icon: Icons.lock_outline_rounded,
              label: s.passwordField,
              isPassword: true,
              hasError: _passwordError,
              hints: const [AutofillHints.password],
              action: TextInputAction.done,
              onSubmitted: (_) => _login(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required String label,
    required bool isPassword,
    required bool hasError,
    required Iterable<String> hints,
    required TextInputAction action,
    required ValueChanged<String> onSubmitted,
  }) {
    final iconColor = hasError
        ? const Color(0xFFFF3B30)
        : const Color(0xFF8A8A8E);
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 4),
      child: Row(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: isPassword && !isPasswordVisible,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              keyboardType: isPassword
                  ? TextInputType.visiblePassword
                  : TextInputType.text,
              keyboardAppearance: Brightness.light,
              textInputAction: action,
              autofillHints: hints,
              onSubmitted: onSubmitted,
              cursorColor: primaryColor,
              style: const TextStyle(fontSize: 17, color: Color(0xFF1C1C1E)),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF8A8A8E),
                ),
                floatingLabelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: hasError ? const Color(0xFFFF3B30) : primaryColor,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (isPassword)
            // 48x48 hit area for the show/hide toggle.
            IconButton(
              tooltip: isPasswordVisible ? 'Hide' : 'Show',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: Icon(
                isPasswordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 22,
                color: const Color(0xFF8A8A8E),
              ),
              onPressed: () =>
                  setState(() => isPasswordVisible = !isPasswordVisible),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildLoginButton(S s) {
    return SizedBox(
      height: 54,
      child: AdaptiveButton(
        onPressed: _login,
        label: s.signIn,
        color: primaryColor,
        textColor: Colors.white,
        style: AdaptiveButtonStyle.filled,
        size: AdaptiveButtonSize.large,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildBiometricButton(S s) {
    return TextButton.icon(
      onPressed: () => loginWithBiometrics(context),
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(
        Platform.isIOS ? Icons.face_unlock_outlined : Icons.fingerprint_rounded,
        size: 22,
      ),
      label: Text(
        s.biometricSignInLabel,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildLanguagePicker() {
    final current = localeNotifier.value.languageCode;
    final index = _kLanguages
        .indexWhere((l) => l.$1 == current)
        .clamp(0, _kLanguages.length - 1);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: AppSegmentedControl(
          labels: [for (final l in _kLanguages) l.$2],
          selectedIndex: index,
          minSegmentWidth: 0,
          padding: EdgeInsets.zero,
          onChanged: (i) {
            final code = _kLanguages[i].$1;
            localeNotifier.value = Locale(code);
            storage.write(key: 'locale', value: code);
          },
        ),
      ),
    );
  }

  Future<void> _login() async {
    final s = S.of(context);
    FocusScope.of(context).unfocus();

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _usernameError = username.isEmpty;
        _passwordError = password.isEmpty;
      });
      _shakeForm();
      _notify(s.enterLoginPassword);
      (username.isEmpty ? _usernameFocus : _passwordFocus).requestFocus();
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await attemptLogIn(username, password);
      if (!mounted) return;
      if (result.jwt != null) {
        await storage.write(key: "username", value: username);
        await storage.write(key: "password", value: password);
        await storage.write(key: "jwt", value: result.jwt!);
        // Lets iOS / Android offer to save the credentials to the system
        // password manager.
        TextInput.finishAutofillContext();
        await _completeLogin(result.jwt!);
      } else if (result.wrongCredentials) {
        setState(() {
          isLoading = false;
          _usernameError = true;
          _passwordError = true;
        });
        _shakeForm();
        _notify(s.wrongCredentials);
        // Ready to retype: password focused and fully selected.
        _passwordFocus.requestFocus();
        _passwordController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _passwordController.text.length,
        );
      } else {
        setState(() => isLoading = false);
        _notify(s.connectionError);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _notify(s.connectionError);
    }
  }
}
