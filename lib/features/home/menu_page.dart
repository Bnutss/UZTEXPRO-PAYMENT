import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'main_page.dart';
import '../passes/passes_page.dart';
import '../sign_requests/sign_requests_page.dart';
import '../bonuses/bonuses_page.dart';
import '../product_models/product_models_page.dart';
import '../settings/settings_screen.dart';
import '../auth/login_page.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/storage/app_storage.dart';
import 'package:uztexpro_payment/main.dart';

class MenuPage extends StatefulWidget {
  final String jwtToken;

  const MenuPage({Key? key, required this.jwtToken}) : super(key: key);

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> with TickerProviderStateMixin {
  static const Color _gradientStart = Color(0xFFFF8C00);
  static const Color _gradientEnd = Color(0xFFCC1500);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late AnimationController _shimmerController;
  late Animation<double> _shimmer;

  int _currentIndex = 0;

  String? _usdRate;
  String? _rubRate;
  bool _usdUp = true;
  bool _rubUp = true;
  bool _ratesLoaded = false;

  bool _statsLoading = true;
  bool _statsError = false;
  int _pendingSignRequests = 0;
  int _newPaymentReports = 0;

  // Each category is "loaded" once either a cached value or a fresh network
  // response has populated it — used to tell a genuinely-empty dashboard
  // apart from one where a slow backend just hasn't answered yet.
  bool _signRequestsLoaded = false;
  bool _paymentsLoaded = false;

  bool get _dashboardHasGaps => !_signRequestsLoaded || !_paymentsLoaded;

  final AppStorage _dashStorage = const AppStorage();
  static const _kSignRequestsCacheKey = 'dashboard_sign_stats_v1';
  static const _kPaymentsCacheKey = 'dashboard_payments_stats_v1';

  String get _apiToken {
    try {
      return jsonDecode(widget.jwtToken)['token'] as String;
    } catch (_) {
      return widget.jwtToken;
    }
  }

  Map<String, String> get _apiHeaders => {
    'Authorization': 'Bearer $_apiToken',
    'Content-Type': 'application/json',
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
    _animationController.forward();
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    // Only Android renders our hand-rolled glass bar (iOS uses the native
    // Liquid Glass tab bar instead) — keep this animation idle elsewhere so
    // we're not driving a CustomPaint repaint loop next to a platform view
    // for a widget that never gets mounted.
    if (!Platform.isIOS) _shimmerController.repeat();
    _shimmer = Tween<double>(begin: 0.0, end: 1.0).animate(_shimmerController);
    localeNotifier.addListener(_onLocaleChanged);
    _fetchRates();
    _loadDashboardStats();
  }

  Future<void> _fetchRates() async {
    try {
      final res = await http
          .get(Uri.parse('https://cbu.uz/ru/arkhiv-kursov-valyut/json/'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          final code = map['Code']?.toString();
          final rate = double.tryParse(map['Rate']?.toString() ?? '');
          final diff = double.tryParse(map['Diff']?.toString() ?? '');
          if (rate == null) continue;
          if (code == '840') {
            _usdRate = _fmtRate(rate);
            _usdUp = (diff ?? 0) >= 0;
          } else if (code == '643') {
            _rubRate = _fmtRate(rate);
            _rubUp = (diff ?? 0) >= 0;
          }
        }
        if (mounted) setState(() => _ratesLoaded = true);
      }
    } catch (_) {}
  }

  String _fmtRate(double rate) {
    if (rate >= 1000) {
      final s = rate.round().toString();
      return s.length > 3
          ? '${s.substring(0, s.length - 3)} ${s.substring(s.length - 3)}'
          : s;
    }
    return rate.toStringAsFixed(1);
  }

  Future<void> _loadDashboardStats() async {
    if (!_hasFullAccess) {
      if (mounted) setState(() => _statsLoading = false);
      return;
    }
    // Cache-first: show whatever we last saw immediately (matching how the
    // Bonuses/ProductModels screens themselves feel instant off their own
    // cache) instead of blocking every launch on a live round-trip to a
    // backend that sometimes takes longer than we'd like.
    await _loadCachedStats();
    if (mounted) {
      setState(() {
        _statsError = false;
        if (_signRequestsLoaded && _paymentsLoaded) {
          _statsLoading = false;
        }
      });
    }
    // Run in parallel: these hit independent endpoints, and if any one of
    // them is genuinely slow/timing out server-side, awaiting them one at a
    // time would serialize the timeouts instead of bounding total wait to
    // the single slowest request.
    await Future.wait([
      _fetchSignRequestsStats(),
      _fetchPaymentsStats(),
    ]);
    if (mounted) setState(() => _statsLoading = false);
  }

  Future<void> _loadCachedStats() async {
    final cached = await Future.wait([
      _dashStorage.read(key: _kSignRequestsCacheKey),
      _dashStorage.read(key: _kPaymentsCacheKey),
    ]);
    if (!mounted) return;
    setState(() {
      final signRequests = cached[0];
      if (signRequests != null) {
        _pendingSignRequests = int.tryParse(signRequests) ?? 0;
        _signRequestsLoaded = true;
      }
      final payments = cached[1];
      if (payments != null) {
        _newPaymentReports = int.tryParse(payments) ?? 0;
        _paymentsLoaded = true;
      }
    });
  }

  void _retryDashboardStats() {
    setState(() {
      _statsLoading = true;
      _statsError = false;
    });
    _loadDashboardStats();
  }

  List _asItemList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) return (decoded['results'] ?? decoded['data'] ?? []) as List;
    return const [];
  }

  void _markStatsFailed(String source, Object error) {
    debugPrint('[dashboard] $source failed: $error');
    // A slow/timed-out refresh isn't worth flagging if we're already showing
    // a cached number for every category — only surface the error banner
    // when something has never loaded at all.
    if (mounted && _dashboardHasGaps) setState(() => _statsError = true);
  }

  Future<void> _fetchSignRequestsStats() async {
    try {
      final res = await http
          .get(
            Uri.parse(
              '$API/texmansys/material-purchase-application/?limit=1000',
            ),
            headers: _apiHeaders,
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        _markStatsFailed('sign requests', 'HTTP ${res.statusCode}');
        return;
      }
      final items = _asItemList(json.decode(utf8.decode(res.bodyBytes)));
      final pending = items.where((raw) => (raw as Map)['status'] == 0).length;
      unawaited(
        _dashStorage.write(key: _kSignRequestsCacheKey, value: '$pending'),
      );
      if (!mounted) return;
      setState(() {
        _pendingSignRequests = pending;
        _signRequestsLoaded = true;
      });
    } catch (e) {
      _markStatsFailed('sign requests', e);
    }
  }

  Future<void> _fetchPaymentsStats() async {
    try {
      final res = await http
          .get(
            Uri.parse('$API/edo/payment-raport/?for_mobile=1'),
            headers: _apiHeaders,
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        _markStatsFailed('payments', 'HTTP ${res.statusCode}');
        return;
      }
      final items = _asItemList(json.decode(utf8.decode(res.bodyBytes)));
      final newCount = items.where((raw) => (raw as Map)['status'] == 1).length;
      unawaited(
        _dashStorage.write(key: _kPaymentsCacheKey, value: '$newCount'),
      );
      if (!mounted) return;
      setState(() {
        _newPaymentReports = newCount;
        _paymentsLoaded = true;
      });
    } catch (e) {
      _markStatsFailed('payments', e);
    }
  }

  void _onLocaleChanged() => setState(() {});

  @override
  void dispose() {
    _animationController.dispose();
    _shimmerController.dispose();
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

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
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
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: Colors.red.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                s.logOut,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.logOutConfirm,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: AdaptiveButton(
                        onPressed: () => Navigator.of(context).pop(),
                        label: s.cancel,
                        textColor: onSurface,
                        style: AdaptiveButtonStyle.glass,
                        size: AdaptiveButtonSize.large,
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: AdaptiveButton(
                        onPressed: () async {
                          final nav = Navigator.of(context);
                          try {
                            await storage.delete(key: "jwt");
                          } catch (_) {}
                          nav.pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                            (route) => false,
                          );
                        },
                        label: s.logOutBtn,
                        color: Colors.redAccent,
                        textColor: Colors.redAccent,
                        style: AdaptiveButtonStyle.glass,
                        size: AdaptiveButtonSize.large,
                        borderRadius: BorderRadius.circular(11),
                      ),
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
        statusBarBrightness: Brightness.dark,
      ),
      // adaptive_platform_ui's native iOS 26 tab bar reads its light/dark
      // style purely from ambient platformBrightness. The system's real
      // light-mode Liquid Glass renders pale/washed out on our colored
      // gradient, while the dark variant reads as noticeably more contrasty
      // glass on either background — so force the tab bar (built directly
      // by AdaptiveScaffold, outside `body`) to always use the dark style,
      // then restore the *real* app brightness just for `body` so every
      // other native control (switch, dialogs, buttons) still follows the
      // actual selected theme correctly.
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(platformBrightness: Brightness.dark),
        child: AdaptiveScaffold(
          body: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              platformBrightness: isDark ? Brightness.dark : Brightness.light,
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(top: -70, right: -50, child: _circle(200, 0.07)),
                  Positioned(top: 80, left: -70, child: _circle(160, 0.05)),
                  Positioned(
                    bottom: 160,
                    right: -40,
                    child: _circle(130, 0.06),
                  ),
                  Positioned(bottom: -50, left: -30, child: _circle(180, 0.05)),
                  SafeArea(
                    bottom: false,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            _buildHeader(s),
                            const SizedBox(height: 16),
                            Expanded(
                              child: IndexedStack(
                                index: _currentIndex,
                                children: [
                                  _buildHomeTab(s),
                                  _buildConfirmationsTab(s),
                                  _buildProductionTab(s),
                                  const SettingsScreen(),
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
          bottomNavigationBar: AdaptiveBottomNavigationBar(
            items: [
              AdaptiveNavigationDestination(
                icon: 'house.fill',
                label: s.navHome,
              ),
              AdaptiveNavigationDestination(
                icon: 'checkmark.seal.fill',
                label: s.navConfirmations,
              ),
              AdaptiveNavigationDestination(
                icon: 'shippingbox.fill',
                label: s.navProduction,
              ),
              AdaptiveNavigationDestination(icon: 'gear', label: s.navSettings),
            ],
            selectedIndex: _currentIndex,
            onTap: _onTabTap,
            useNativeBottomBar: true,
            selectedItemColor: _gradientStart,
            // The tab bar always renders with the forced-dark native style
            // (see the MediaQuery override above), so its unselected tint
            // should match that dark chrome regardless of the app's actual
            // theme — not flip with isDark like the rest of the screen.
            unselectedItemColor: Colors.white.withOpacity(0.75),
            // Android has no native Liquid Glass UITabBar to fall back to, so
            // it keeps our own hand-rolled glass bar. On iOS this is ignored
            // by the package anyway, so skip building it — an unused
            // CustomPaint + AnimatedBuilder tree sitting next to the real
            // native tab bar's platform view is exactly the kind of thing
            // that can confuse the semantics tree.
            bottomNavigationBar: Platform.isIOS ? null : _buildBottomNav(s),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(S s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/icon/uztexpro.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'UztexPro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  s.paymentSystem,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: 36,
      height: 36,
      child: AdaptiveButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          _showLogoutDialog();
        },
        icon: Icons.logout_rounded,
        iconColor: Colors.redAccent,
        color: Colors.redAccent,
        style: AdaptiveButtonStyle.glass,
        size: AdaptiveButtonSize.medium,
        borderRadius: BorderRadius.circular(10),
        minSize: const Size(36, 36),
      ),
    );
  }

  // ── Главная ──────────────────────────────────────────

  Widget _buildHomeTab(S s) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.welcome,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.paymentSystem,
            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13),
          ),
          if (_usdRate != null || _rubRate != null) ...[
            const SizedBox(height: 28),
            _sectionLabel(s.exchangeRates),
            const SizedBox(height: 10),
            AnimatedOpacity(
              opacity: _ratesLoaded ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 600),
              child: Row(
                children: [
                  if (_usdRate != null)
                    Expanded(child: _rateCard('\$', _usdRate!, _usdUp)),
                  if (_usdRate != null && _rubRate != null)
                    const SizedBox(width: 12),
                  if (_rubRate != null)
                    Expanded(child: _rateCard('₽', _rubRate!, _rubUp)),
                ],
              ),
            ),
          ],
          if (_hasFullAccess) ...[
            if (_statsError && !_statsLoading) ...[
              const SizedBox(height: 20),
              _buildStatsErrorBanner(s),
            ],
            const SizedBox(height: 28),
            _sectionLabel(s.reportsSection),
            const SizedBox(height: 10),
            _buildReportsRow(s),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsErrorBanner(S s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.connectionError,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
          GestureDetector(
            onTap: _retryDashboardStats,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Colors.white.withOpacity(0.55),
      ),
    );
  }

  Widget _statSkeleton({double height = 104}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        ),
      ),
    );
  }

  Widget _buildReportsRow(S s) {
    if (_statsLoading) {
      return Row(
        children: List.generate(2, (i) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 1 ? 10 : 0),
              child: _statSkeleton(),
            ),
          );
        }),
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _reportStatTile(
              icon: Icons.draw_rounded,
              accent: const Color(0xFF3B82F6),
              value: '$_pendingSignRequests',
              label: s.dashboardSignPending,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _reportStatTile(
              icon: Icons.receipt_long_rounded,
              accent: const Color(0xFF43A047),
              value: '$_newPaymentReports',
              label: s.dashboardNewReports,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportStatTile({
    required IconData icon,
    required Color accent,
    required String value,
    required String label,
    String? caption,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.22),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: accent, size: 17),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10.5,
              height: 1.2,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 3),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rateCard(String symbol, String rate, bool isUp) {
    final trendColor = isUp ? const Color(0xFF69F0AE) : const Color(0xFFFF6B6B);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                symbol,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isUp ? Icons.north_rounded : Icons.south_rounded,
                  size: 12,
                  color: trendColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rate,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ── Подтверждения ────────────────────────────────────

  Widget _buildConfirmationsTab(S s) {
    final cards = _buildMenuCards(s);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: cards.isEmpty ? _NoAccessCard() : Column(children: cards),
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
          builder: (_) => PassesPage(jwtToken: widget.jwtToken),
        ),
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
            builder: (_) => MainPageScreen(jwtToken: widget.jwtToken),
          ),
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
            builder: (_) => SignRequestsPage(jwtToken: widget.jwtToken),
          ),
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
            builder: (_) => BonusesPage(jwtToken: widget.jwtToken),
          ),
        ),
      ),
    ];
  }

  // ── Производство ─────────────────────────────────────

  Widget _buildProductionTab(S s) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: !_hasFullAccess
          ? _NoAccessCard()
          : _MenuCard(
              icon: Icons.checkroom_rounded,
              label: s.menuProductModels,
              description: s.menuProductModelsDesc,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductModelsPage(jwtToken: widget.jwtToken),
                ),
              ),
            ),
    );
  }

  // ── Нижняя навигация ─────────────────────────────────

  Widget _buildBottomNav(S s) {
    final items = <_NavItemData>[
      _NavItemData(Icons.home_rounded, s.navHome),
      _NavItemData(Icons.fact_check_rounded, s.navConfirmations),
      _NavItemData(Icons.precision_manufacturing_rounded, s.navProduction),
      _NavItemData(Icons.settings_rounded, s.navSettings),
    ];

    const radius = 26.0;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            // A light blur reads as "refractive glass"; a heavy one just
            // reads as frosted paper and hides the sheen/rim-light detail.
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.20),
                    Colors.white.withOpacity(0.08),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.35),
                  width: 1,
                ),
              ),
              child: AnimatedBuilder(
                animation: _shimmer,
                builder: (_, child) => CustomPaint(
                  painter: _GlassSheenPainter(
                    sweep: _shimmer.value,
                    radius: radius,
                  ),
                  child: child,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: List.generate(items.length, (i) {
                      return Expanded(
                        child: _NavBarButton(
                          icon: items[i].icon,
                          label: items[i].label,
                          selected: i == _currentIndex,
                          onTap: () => _onTabTap(i),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
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
}

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData(this.icon, this.label);
}

/// Paints a slow-moving diagonal specular streak plus a soft top rim-light,
/// the two cues that read as "glass" instead of "tinted blur".
class _GlassSheenPainter extends CustomPainter {
  final double sweep;
  final double radius;
  const _GlassSheenPainter({required this.sweep, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipRRect(rrect);

    final x = -1.3 + sweep * 2.6;
    final streakPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = LinearGradient(
        begin: Alignment(x, -1.2),
        end: Alignment(x - 0.7, 1.2),
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(0.22),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, streakPaint);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.5)
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.9),
          Colors.white.withOpacity(0),
        ],
        stops: const [0.0, 0.5],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rrect.deflate(0.6), rimPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlassSheenPainter oldDelegate) =>
      oldDelegate.sweep != sweep || oldDelegate.radius != radius;
}

class _NavBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavBarButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: EdgeInsets.symmetric(horizontal: selected ? 14 : 0),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.92) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? const Color(0xFFFF8C00)
                  : Colors.white.withOpacity(0.65),
            ),
            if (selected)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF8C00),
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
            border: Border.all(
              color: Colors.white.withOpacity(0.22),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
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
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.6),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoAccessCard extends StatelessWidget {
  _NoAccessCard();

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
            child: const Icon(
              Icons.lock_outline_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            S.of(context).accessRestricted,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context).noAccessMessage,
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
