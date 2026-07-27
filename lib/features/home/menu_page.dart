import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
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

  final AppStorage _dashStorage = const AppStorage();

  // Production overview (KPIs / productions / factories) — kept fully
  // separate from the sign/payment stats above: it hits a different
  // endpoint that needs its own `view_employee` permission, which not every
  // full-access mobile role is guaranteed to carry. A 401/403 here just
  // hides the section instead of tripping the shared error banner.
  bool _dashOverviewLoading = true;
  bool _dashOverviewLoaded = false;
  bool _dashOverviewUnavailable = false;
  Map<String, dynamic>? _dashOverview;
  static const _kDashOverviewCacheKey = 'dashboard_overview_v1';

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
    _loadDashboardOverview();
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

  Future<void> _loadDashboardOverview() async {
    if (!_hasFullAccess) {
      if (mounted) setState(() => _dashOverviewLoading = false);
      return;
    }
    final cached = await _dashStorage.read(key: _kDashOverviewCacheKey);
    if (cached != null && mounted) {
      try {
        setState(() {
          _dashOverview = jsonDecode(cached) as Map<String, dynamic>;
          _dashOverviewLoaded = true;
        });
      } catch (_) {}
    }
    await _fetchDashboardOverview();
    if (mounted) setState(() => _dashOverviewLoading = false);
  }

  Future<void> _fetchDashboardOverview() async {
    try {
      final res = await http
          .get(
            Uri.parse('$API/texmansys/professional-dashboard/'),
            headers: _apiHeaders,
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 401 || res.statusCode == 403) {
        if (mounted) setState(() => _dashOverviewUnavailable = true);
        return;
      }
      if (res.statusCode != 200) return;
      final decoded = json.decode(utf8.decode(res.bodyBytes));
      final results = decoded is Map ? decoded['results'] : null;
      if (results is! Map<String, dynamic>) return;
      unawaited(
        _dashStorage.write(
          key: _kDashOverviewCacheKey,
          value: jsonEncode(results),
        ),
      );
      if (!mounted) return;
      setState(() {
        _dashOverview = results;
        _dashOverviewLoaded = true;
      });
    } catch (e) {
      debugPrint('[dashboard] overview failed: $e');
    }
  }

  List<Map<String, dynamic>> get _dashFactories =>
      ((_dashOverview?['factories'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();

  List<Map<String, dynamic>> get _dashProductions =>
      ((_dashOverview?['productions'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();

  int get _dashTotalEmployees =>
      (_dashOverview?['total_employees'] as num?)?.toInt() ?? 0;

  int get _dashInTerritory => _dashFactories.fold<int>(
    0,
    (sum, f) => sum + ((f['in_territory'] as num?)?.toInt() ?? 0),
  );

  double get _dashProducedYesterday =>
      _dashFactories.fold<double>(
        0,
        (sum, f) => sum + ((f['sewing_yesterday'] as num?)?.toDouble() ?? 0),
      ) /
      1000;

  String get _dashYesterdayDate =>
      (_dashOverview?['yesterday_date'] as String?) ?? '—';

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
                                  _buildShopTab(s),
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
            // Labels intentionally empty: icons-only tab bar. adaptive_platform_ui's
            // AdaptiveNavigationDestination.label is required and doubles as the
            // native tab's accessibility label, so VoiceOver support is traded
            // away here too — there's no separate visual/semantic label knob
            // exposed by the plugin.
            items: const [
              AdaptiveNavigationDestination(icon: 'house.fill', label: ''),
              AdaptiveNavigationDestination(
                icon: 'checkmark.seal.fill',
                label: '',
              ),
              AdaptiveNavigationDestination(
                icon: 'shippingbox.fill',
                label: '',
              ),
              AdaptiveNavigationDestination(icon: 'bag.fill', label: ''),
              AdaptiveNavigationDestination(icon: 'gear', label: ''),
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
    final showRates = _ratesLoaded && (_usdRate != null || _rubRate != null);
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
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: showRates
                      ? _headerRateStrip(key: const ValueKey('rates'))
                      : Text(
                          s.paymentSystem,
                          key: const ValueKey('subtitle'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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

  // Compact currency strip that swaps in for the header subtitle once rates
  // land — kept small enough to sit in the app bar row instead of taking a
  // full section in the scrolling body.
  Widget _headerRateStrip({Key? key}) {
    return Row(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_usdRate != null) _headerRateChip('\$', _usdRate!, _usdUp),
        if (_usdRate != null && _rubRate != null) const SizedBox(width: 10),
        if (_rubRate != null) _headerRateChip('₽', _rubRate!, _rubUp),
      ],
    );
  }

  Widget _headerRateChip(String symbol, String rate, bool isUp) {
    final trendColor = isUp ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          symbol,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          rate,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        Icon(
          isUp ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
          size: 14,
          color: trendColor,
        ),
      ],
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

  // ── Общий заголовок раздела ───────────────────────────
  //
  // Every tab gets the same left-aligned section title (matching the
  // Settings tab's own header) so it's always clear which section is open —
  // previously only Settings had one, and it was centered instead of sitting
  // next to the edge like the rest of the app's content.
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w800,
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
          _buildSectionTitle(s.navHome),
          const SizedBox(height: 4),
          Text(
            s.paymentSystem,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 13,
            ),
          ),
          if (_hasFullAccess &&
              !_dashOverviewUnavailable &&
              (_dashOverviewLoading || _dashOverviewLoaded)) ...[
            const SizedBox(height: 26),
            _dashSectionHeader(
              Icons.dashboard_customize_rounded,
              s.dashboardOverview,
            ),
            const SizedBox(height: 12),
            _dashOverviewLoaded ? _buildDashOverview(s) : _dashSkeletonBlock(),
          ],
        ],
      ),
    );
  }

  // ── "Wow" production dashboard ──────────────────────────────────────
  //
  // Hero attendance ring + compact KPI tiles + horizontally-scrolling
  // production/factory cards, all on an elevated glass treatment (layered
  // gradient fill instead of flat opacity, soft accent glows, count-up
  // numbers, staggered entrance). Reduced-motion is honored throughout via
  // `_StaggerIn`/`_CountUpText`, which both check the platform accessibility
  // flag and skip straight to the end state.

  BoxDecoration _glassDecoration({
    double radius = 16,
    double borderOpacity = 0.22,
    List<BoxShadow>? shadow,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.19),
          Colors.white.withOpacity(0.08),
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withOpacity(borderOpacity),
        width: 1,
      ),
      boxShadow: shadow,
    );
  }

  Widget _dashSectionHeader(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.white.withOpacity(0.55)),
        const SizedBox(width: 6),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Colors.white.withOpacity(0.55),
          ),
        ),
      ],
    );
  }

  Widget _dashSkeletonBlock() {
    final base = Colors.white.withOpacity(0.10);
    final hi = Colors.white.withOpacity(0.24);
    Widget block({double height = 92, double? width}) => Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(18),
      ),
    );
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          block(height: 110),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: block(height: 78)),
              const SizedBox(width: 10),
              Expanded(child: block(height: 78)),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: List.generate(
                3,
                (i) => Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
                  child: block(height: 118, width: 118),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashOverview(S s) {
    final productions = _dashProductions;
    final factories = _dashFactories;
    final total = _dashTotalEmployees;
    final onSite = _dashInTerritory;
    final attendance = total > 0 ? onSite / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StaggerIn(
          child: _dashHeroCard(
            s,
            total: total,
            onSite: onSite,
            attendance: attendance,
          ),
        ),
        if (productions.isNotEmpty) ...[
          const SizedBox(height: 24),
          _StaggerIn(
            delay: const Duration(milliseconds: 140),
            child: _dashSectionHeader(
              Icons.insights_rounded,
              s.dashboardProductionIndicators,
            ),
          ),
          const SizedBox(height: 10),
          _StaggerIn(
            delay: const Duration(milliseconds: 160),
            child: SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: productions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _dashProductionCard(productions[i], s),
              ),
            ),
          ),
        ],
        if (factories.isNotEmpty) ...[
          const SizedBox(height: 24),
          _StaggerIn(
            delay: const Duration(milliseconds: 200),
            child: _dashSectionHeader(
              Icons.factory_rounded,
              s.dashboardFactoriesDetail,
            ),
          ),
          const SizedBox(height: 10),
          _StaggerIn(
            delay: const Duration(milliseconds: 220),
            child: SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: factories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _dashFactoryCard(factories[i], s),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _dashHeroCard(
    S s, {
    required int total,
    required int onSite,
    required double attendance,
  }) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _glassDecoration(
        radius: 22,
        shadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: attendance.clamp(0.0, 1.0)),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(84, 84),
                        painter: _RingPainter(
                          progress: value,
                          trackColor: Colors.white.withOpacity(0.16),
                          colors: const [Color(0xFFFFE08A), Color(0xFFFF8C42)],
                        ),
                      ),
                      Text(
                        '${(value * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.dashboardInTerritory.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        _CountUpText(
                          target: onSite.toDouble(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        Text(
                          ' / $total',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        s.dashboardOutOf(total),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withOpacity(0.14)),
          const SizedBox(height: 12),
          // Two secondary metrics tucked into the hero card itself instead
          // of a card of their own — keeps the section to three visual
          // blocks (hero, productions, factories) rather than four.
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _dashCompactStat(
                    icon: Icons.local_shipping_rounded,
                    accent: const Color(0xFF34D399),
                    numericValue: _dashProducedYesterday.roundToDouble(),
                    suffix: 'K',
                    label: s.dashboardProductionYesterday,
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 13),
                  color: Colors.white.withOpacity(0.16),
                ),
                Expanded(
                  child: _dashCompactStat(
                    icon: Icons.event_rounded,
                    accent: const Color(0xFF60A5FA),
                    textValue: _dashYesterdayDate,
                    label: s.dashboardReportDate,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashCompactStat({
    required IconData icon,
    required Color accent,
    required String label,
    double? numericValue,
    String? textValue,
    String suffix = '',
  }) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [accent, accent.withOpacity(0.75)],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.4),
                blurRadius: 9,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (numericValue != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    _CountUpText(
                      target: numericValue,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (suffix.isNotEmpty)
                      Text(
                        suffix,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                )
              else
                Text(
                  textValue ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dashProductionCard(Map<String, dynamic> prod, S s) {
    final planned = (prod['planned'] as num?)?.toDouble() ?? 0;
    final actual = (prod['actual'] as num?)?.toDouble() ?? 0;
    final planPercent = (prod['plan_percent'] as num?)?.toDouble() ?? 0;
    final unit = prod['unit']?.toString() ?? '';
    final code = prod['code']?.toString() ?? prod['name']?.toString() ?? '';
    final pct = planned > 0
        ? (actual / planned * 100).clamp(0, 100).round()
        : 0;
    final over = actual >= planned;
    final trendColor = over ? const Color(0xFF34D399) : const Color(0xFFFB7185);

    String fmt(double v) => NumberFormat(
      v == v.roundToDouble() ? '#,##0' : '#,##0.0',
      'ru',
    ).format(v);

    return Container(
      width: 118,
      clipBehavior: Clip.antiAlias,
      decoration: _glassDecoration(radius: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: trendColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              code,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (unit.isNotEmpty)
                              Text(
                                unit,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        over
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 12,
                        color: trendColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _dashStatLine(
                    s.dashboardPlan,
                    fmt(planned),
                    emphasize: false,
                  ),
                  const SizedBox(height: 2),
                  _dashStatLine(s.dashboardFact, fmt(actual), emphasize: true),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        '$pct%',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 9.5,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: trendColor.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${planPercent.round()}%',
                          style: TextStyle(
                            color: trendColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _dashProgressBar(pct / 100, trendColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashFactoryCard(Map<String, dynamic> f, S s) {
    final name = f['name']?.toString() ?? '';
    final employeeCount = (f['employee_count'] as num?)?.toInt() ?? 0;
    final entered = (f['today_total_enter'] as num?)?.toInt() ?? 0;
    final inTerritory = (f['in_territory'] as num?)?.toInt() ?? 0;
    final producedYesterday = (f['sewing_yesterday'] as num?)?.toDouble() ?? 0;
    final pct = employeeCount > 0
        ? (inTerritory / employeeCount * 100).clamp(0, 100).round()
        : 0;
    final good = pct > 70;
    final color = good ? const Color(0xFF34D399) : const Color(0xFFFB7185);

    return Container(
      width: 122,
      clipBehavior: Clip.antiAlias,
      decoration: _glassDecoration(radius: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: color),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 11, 11, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(
                        good
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 12,
                        color: color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _dashStatLine(
                    s.dashboardFactoryTotal,
                    NumberFormat('#,##0', 'ru').format(employeeCount),
                    emphasize: false,
                  ),
                  const SizedBox(height: 2),
                  _dashStatLine(
                    s.dashboardEntered,
                    NumberFormat('#,##0', 'ru').format(entered),
                    emphasize: true,
                  ),
                  const SizedBox(height: 2),
                  _dashStatLine(
                    s.dashboardProductionShort,
                    '${NumberFormat('#,##0', 'ru').format(producedYesterday / 1000)}K',
                    emphasize: false,
                  ),
                  const Spacer(),
                  Text(
                    '$pct%',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 9.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _dashProgressBar(pct / 100, color),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashStatLine(String label, String value, {required bool emphasize}) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(
              fontSize: 9.5,
              color: Colors.white.withOpacity(0.55),
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.white.withOpacity(emphasize ? 1 : 0.85),
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashProgressBar(double fraction, Color color) {
    final clamped = fraction.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            height: 5,
            width: constraints.maxWidth * clamped,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.7), color]),
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.55), blurRadius: 5),
              ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(s.navConfirmations),
          const SizedBox(height: 20),
          if (cards.isEmpty) _NoAccessCard() else ...cards,
        ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(s.navProduction),
          const SizedBox(height: 20),
          !_hasFullAccess
              ? _NoAccessCard()
              : _MenuCard(
                  icon: Icons.checkroom_rounded,
                  label: s.menuProductModels,
                  description: s.menuProductModelsDesc,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProductModelsPage(jwtToken: widget.jwtToken),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ── Магазин ───────────────────────────────────────────

  Widget _buildShopTab(S s) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(s.navShop),
          const SizedBox(height: 20),
          _ComingSoonCard(
            icon: Icons.storefront_rounded,
            title: s.shopComingSoonTitle,
            message: s.shopComingSoonMessage,
          ),
        ],
      ),
    );
  }

  // ── Нижняя навигация ─────────────────────────────────

  Widget _buildBottomNav(S s) {
    final items = <_NavItemData>[
      _NavItemData(Icons.home_rounded, s.navHome),
      _NavItemData(Icons.fact_check_rounded, s.navConfirmations),
      _NavItemData(Icons.precision_manufacturing_rounded, s.navProduction),
      _NavItemData(Icons.storefront_rounded, s.navShop),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
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

/// Fades + slides a child in once, after [delay]. Skips straight to the
/// visible end state when the OS accessibility setting for reduced motion
/// is on, instead of running the animation anyway.
class _StaggerIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _StaggerIn({required this.child, this.delay = Duration.zero});

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations) {
      _visible = true;
      return;
    }
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 0.06),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Animates from 0 up to [target] once on mount, formatted with thousands
/// separators. Renders [target] immediately when reduced motion is on.
class _CountUpText extends StatelessWidget {
  final double target;
  final TextStyle style;

  const _CountUpText({required this.target, required this.style});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, value, _) =>
          Text(NumberFormat('#,##0', 'ru').format(value), style: style),
    );
  }
}

/// Sweep-gradient attendance ring for the dashboard hero card.
class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final List<Color> colors;
  static const double strokeWidth = 9;

  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep <= 0) return;
    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: [...colors, colors.first],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.colors != colors;
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
        colors: [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0)],
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
    // Icons-only bar: the label is kept as a Semantics annotation so
    // TalkBack/VoiceOver users still hear what each tab is, even though it's
    // no longer drawn.
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          width: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withOpacity(0.92)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            size: 22,
            color: selected
                ? const Color(0xFFFF8C00)
                : Colors.white.withOpacity(0.65),
          ),
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

class _ComingSoonCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _ComingSoonCard({
    required this.icon,
    required this.title,
    required this.message,
  });

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
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
