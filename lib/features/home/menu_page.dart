import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main_page.dart';
import '../passes/passes_page.dart';
import '../sign_requests/sign_requests_page.dart';
import '../bonuses/bonuses_page.dart';
import '../settings/settings_screen.dart';
import '../auth/login_page.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import 'package:uztexpro_payment/main.dart';

class MenuPage extends StatefulWidget {
  final String jwtToken;

  const MenuPage({Key? key, required this.jwtToken}) : super(key: key);

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage>
    with SingleTickerProviderStateMixin {
  static const Color _gradientStart = Color(0xFFFF8C00);
  static const Color _gradientEnd = Color(0xFFCC1500);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _animationController, curve: Curves.easeOut));
    _animationController.forward();
    localeNotifier.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() => setState(() {});

  @override
  void dispose() {
    _animationController.dispose();
    localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  static const _passOnlyGroups = {
    'acc_sign_pass',
    'release_sign_pass',
    'security_sign_pass',
    'seo_sign_pass',
  };

  Map<String, dynamic> _parsedToken() {
    try {
      return jsonDecode(widget.jwtToken) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  bool get _hasFullAccess {
    final body = _parsedToken();
    final user = body['user'];
    if (user is Map && user['is_super'] == true) return true;
    final groups = _extractGroups(body);
    return groups.contains('AI_Permission');
  }

  bool get _isPassOnly {
    if (_hasFullAccess) return false;
    final groups = _extractGroups(_parsedToken());
    return groups.any(_passOnlyGroups.contains);
  }

  Set<String> _extractGroups(Map<String, dynamic> body) {
    final user = body['user'];
    if (user is Map) {
      final raw = user['groups'];
      if (raw is List) return raw.map((e) => e.toString()).toSet();
    }
    final raw = body['groups'];
    if (raw is List) return raw.map((e) => e.toString()).toSet();
    return {};
  }

  void _showLogoutDialog() {
    final s = S.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.red.shade50, shape: BoxShape.circle),
                child: Icon(Icons.logout_rounded,
                    color: Colors.red.shade700, size: 28),
              ),
              const SizedBox(height: 14),
              Text(s.logOut,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: onSurface)),
              const SizedBox(height: 8),
              Text(s.logOutConfirm,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: onSurface.withOpacity(0.6))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(s.cancel,
                          style: TextStyle(
                              fontSize: 13,
                              color: onSurface.withOpacity(0.6),
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        try {
                          await storage.delete(key: "jwt");
                        } catch (_) {}
                        nav.pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(s.logOutBtn,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? [const Color(0xFF3D1800), const Color(0xFF1F0000)]
        : [_gradientStart, _gradientEnd];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -70,
                right: -50,
                child: _circle(200, 0.07),
              ),
              Positioned(
                top: 80,
                left: -70,
                child: _circle(160, 0.05),
              ),
              Positioned(
                bottom: 160,
                right: -40,
                child: _circle(130, 0.06),
              ),
              Positioned(
                bottom: -50,
                left: -30,
                child: _circle(180, 0.05),
              ),
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        const SizedBox(height: 28),
                        // Logo
                        Container(
                          width: 82,
                          height: 82,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 16,
                                  offset: Offset(0, 6)),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset('assets/images/fon.png',
                                fit: BoxFit.contain),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'UzTexPro',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.paymentSystem,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
                              letterSpacing: 0.4),
                        ),
                        const SizedBox(height: 32),
                        // Menu cards
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Builder(builder: (_) {
                            final cards = _buildMenuCards(s);
                            return cards.isEmpty
                                ? const _NoAccessCard()
                                : Column(children: cards);
                          }),
                        ),
                        const Spacer(),
                        // Bottom action buttons
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ActionButton(
                                  icon: Icons.settings_rounded,
                                  label: s.settingsTooltip,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => SettingsScreen()),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ActionButton(
                                  icon: Icons.logout_rounded,
                                  label: s.exitTooltip,
                                  isDestructive: true,
                                  onTap: _showLogoutDialog,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMenuCards(S s) {
    final passOnly = _isPassOnly;

    Widget passCard() => _MenuCard(
          icon: Icons.badge_rounded,
          label: s.menuPasses,
          description: s.menuPassesDesc,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => PassesPage(jwtToken: widget.jwtToken)),
          ),
        );

    if (passOnly) {
      return [passCard()];
    }

    if (!_hasFullAccess) {
      return [];
    }

    return [
      _MenuCard(
        icon: Icons.receipt_long_rounded,
        label: s.menuPayments,
        description: s.menuPaymentsDesc,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => MainPageScreen(jwtToken: widget.jwtToken)),
        ),
      ),
      const SizedBox(height: 12),
      passCard(),
      const SizedBox(height: 12),
      _MenuCard(
        icon: Icons.draw_rounded,
        label: s.menuSignRequests,
        description: s.menuSignRequestsDesc,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  SignRequestsPage(jwtToken: widget.jwtToken)),
        ),
      ),
      const SizedBox(height: 12),
      _MenuCard(
        icon: Icons.card_giftcard_rounded,
        label: s.menuBonuses,
        description: s.menuBonusesDesc,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => BonusesPage(jwtToken: widget.jwtToken)),
        ),
      ),
    ];
  }

  Widget _circle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
        ),
      );
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.13),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: Colors.white.withOpacity(0.22), width: 1.2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(description,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.6), size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.withOpacity(0.18)
                : Colors.white.withOpacity(0.13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDestructive
                  ? Colors.red.withOpacity(0.35)
                  : Colors.white.withOpacity(0.22),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoAccessCard extends StatelessWidget {
  const _NoAccessCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.20), width: 1.2),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline_rounded,
                color: Colors.white, size: 30),
          ),
          const SizedBox(height: 16),
          const Text(
            'Доступ ограничен',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'У вас нет доступа ни к одному разделу.\nОбратитесь к администратору.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => launchUrl(
              Uri.parse('https://t.me/b_narzullaev'),
              mode: LaunchMode.externalApplication,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF229ED9).withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.telegram, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Bakhrom Narzullaev',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
