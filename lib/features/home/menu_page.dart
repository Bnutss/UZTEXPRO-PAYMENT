import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/fade_route.dart';
import '../../core/widgets/floating_notch_bar.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'main_page.dart';
import 'attendance_page.dart';
import '../passes/passes_page.dart';
import '../sign_requests/sign_requests_page.dart';
import '../bonuses/bonuses_page.dart';
import '../product_models/product_models_page.dart';
import '../ai_assistant/ai_assistant_page.dart';
import '../shop/shop_analytics_page.dart';
import '../shop/shop_issued_report_page.dart';
import '../shop/shop_pickup_page.dart';
import '../shop/shop_pvz_stock_page.dart';
import '../settings/settings_screen.dart';
import '../auth/login_page.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/storage/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/stagger_in.dart';
import '../update/app_update_api.dart';
import '../update/app_update_sheet.dart';
import 'package:uztexpro_payment/main.dart';

class MenuPage extends StatefulWidget {
  final String jwtToken;

  const MenuPage({Key? key, required this.jwtToken}) : super(key: key);

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> with TickerProviderStateMixin {
  static const Color _gradientStart = AppColors.brandOrange;
  static const Color _gradientEnd = AppColors.brandRed;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    localeNotifier.addListener(_onLocaleChanged);
    _fetchRates();
    _loadDashboardOverview();
    // iOS ships through the App Store (handled by UpgradeAlert further up
    // the widget tree) — this self-hosted check/download/install flow only
    // applies to the sideloaded Android build.
    if (Platform.isAndroid) _checkForAppUpdate();
  }

  Future<void> _checkForAppUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final versionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      final update = await AppUpdateApi.check(versionCode);
      if (update == null || !mounted) return;
      showAppUpdateSheet(context, update);
    } catch (_) {
      // Update check is a best-effort background convenience — never worth
      // interrupting app startup over.
    }
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

  /// Группы, дающие доступ к магазину (см. shop/views.py и миграцию
  /// 0737_shop_sale_pickup_groups на бэкенде).
  static const _shopGroups = {'shop_sale', 'shop_pickup', 'shop_accounting'};

  /// Суперпользователь и группы `full` / `AI_Permission` видят магазин целиком,
  /// как и на бэкенде (`_has_full_shop_access`).
  bool get _hasFullShopAccess =>
      _hasFullAccess || _extractGroups(_parsedToken()).contains('full');

  bool get _canSeeShop =>
      _hasFullShopAccess ||
      _extractGroups(_parsedToken()).any(_shopGroups.contains);

  /// Группа `Podpis` на бэкенде даёт право подписывать заявки на закупку.
  static const _signGroup = 'Podpis';

  bool get _canSignRequests =>
      _extractGroups(_parsedToken()).contains(_signGroup);

  /// Группа `attendance_view` на бэкенде (hr.views.MobileAttendanceView)
  /// открывает окно посещаемости; полный доступ видит его целиком.
  static const _attendanceGroup = 'attendance_view';

  bool get _canSeeAttendance =>
      _hasFullShopAccess ||
      _extractGroups(_parsedToken()).contains(_attendanceGroup);

  void _openAttendance() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      FadeRoute(builder: (_) => AttendancePage(jwtToken: widget.jwtToken)),
    );
  }

  bool get _canSeePasses =>
      _extractGroups(_parsedToken()).any(_passOnlyGroups.contains);

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

    Future<void> confirmLogout() async {
      final nav = Navigator.of(context);
      try {
        await storage.delete(key: "jwt");
      } catch (_) {}
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }

    if (!Platform.isIOS) {
      showConfirmDialog(
        context,
        icon: Icons.logout_rounded,
        title: s.logOut,
        message: s.logOutConfirm,
        cancelLabel: s.cancel,
        confirmLabel: s.logOutBtn,
        onConfirm: confirmLogout,
      );
      return;
    }

    // Native platform alert (real Liquid Glass chrome on iOS 26+) instead of
    // a hand-rolled Dialog stacking its own AdaptiveButtons on top of the
    // header's own native glass button — that double platform-view overlap
    // was what caused the flash when the sheet opened.
    AdaptiveAlertDialog.show(
      context: context,
      title: s.logOut,
      message: s.logOutConfirm,
      actions: [
        AlertAction(
          title: s.cancel,
          onPressed: () {},
          style: AlertActionStyle.cancel,
        ),
        AlertAction(
          title: s.logOutBtn,
          onPressed: confirmLogout,
          style: AlertActionStyle.destructive,
        ),
      ],
    );
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
      child: AdaptiveScaffold(
        body: SafeArea(
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
            AdaptiveNavigationDestination(icon: 'shippingbox.fill', label: ''),
            AdaptiveNavigationDestination(icon: 'cart.fill', label: ''),
            AdaptiveNavigationDestination(icon: 'gear', label: ''),
          ],
          selectedIndex: _currentIndex,
          onTap: _onTabTap,
          useNativeBottomBar: true,
          selectedItemColor: _gradientStart,
          // Native tab bar follows the app's real (light) theme; leave the
          // unselected tint unset so it picks up the platform's own default.
          unselectedItemColor: null,
          // Android has no native Liquid Glass UITabBar, so it gets the
          // floating notch bar. On iOS the package ignores this anyway, so
          // skip building it.
          bottomNavigationBar: Platform.isIOS
              ? null
              : FloatingNotchBar(
                  selected: _currentIndex,
                  onSelected: _onTabTap,
                  items: [
                    NotchBarItem(
                      CupertinoIcons.house,
                      CupertinoIcons.house_fill,
                      s.navHome,
                    ),
                    NotchBarItem(
                      CupertinoIcons.checkmark_seal,
                      CupertinoIcons.checkmark_seal_fill,
                      s.navConfirmations,
                    ),
                    NotchBarItem(
                      CupertinoIcons.cube_box,
                      CupertinoIcons.cube_box_fill,
                      s.navProduction,
                    ),
                    NotchBarItem(
                      CupertinoIcons.cart,
                      CupertinoIcons.cart_fill,
                      s.navShop,
                    ),
                    NotchBarItem(
                      CupertinoIcons.gear,
                      CupertinoIcons.gear_solid,
                      s.navSettings,
                    ),
                  ],
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
              'assets/icon/logo.png',
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
                    color: Color(0xFF1C1C1E),
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
                          style: const TextStyle(
                            color: Color(0xFF8A8A8E),
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
          if (_hasFullAccess) ...[_buildAiButton(), const SizedBox(width: 8)],
          _buildLogoutButton(),
        ],
      ),
    );
  }

  void _openAiAssistant() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      FadeRoute(builder: (_) => AiAssistantPage(jwtToken: widget.jwtToken)),
    );
  }

  Widget _buildAiButton() {
    if (Platform.isIOS) {
      return SizedBox(
        width: 46,
        height: 46,
        child: AdaptiveButton.icon(
          onPressed: _openAiAssistant,
          icon: Icons.auto_awesome_rounded,
          iconColor: const Color(0xFF1C1C1E),
          color: const Color(0xFF1C1C1E),
          style: AdaptiveButtonStyle.glass,
          size: AdaptiveButtonSize.medium,
          useSmoothRectangleBorder: false,
          minSize: const Size(46, 46),
        ),
      );
    }

    // Android has no native Liquid Glass material, so this approximates it:
    // a neutral frosted-looking circle with a standard dark glyph — same
    // visual language as the real glass button (neutral material, no color).
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openAiAssistant,
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFF2F2F2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFF1C1C1E),
            size: 22,
          ),
        ),
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
    final trendColor = isUp ? const Color(0xFF2E9E5B) : const Color(0xFFE0453C);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          symbol,
          style: const TextStyle(
            color: Color(0xFF8A8A8E),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          rate,
          style: const TextStyle(
            color: Color(0xFF1C1C1E),
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
    void onPressed() {
      HapticFeedback.lightImpact();
      _showLogoutDialog();
    }

    if (Platform.isIOS) {
      return SizedBox(
        width: 46,
        height: 46,
        child: AdaptiveButton.icon(
          onPressed: onPressed,
          icon: Icons.logout_rounded,
          iconColor: const Color(0xFF1C1C1E),
          color: const Color(0xFF1C1C1E),
          style: AdaptiveButtonStyle.glass,
          size: AdaptiveButtonSize.medium,
          useSmoothRectangleBorder: false,
          minSize: const Size(46, 46),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFF2F2F2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.logout_rounded,
            color: Color(0xFF1C1C1E),
            size: 22,
          ),
        ),
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
        color: Color(0xFF1C1C1E),
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
            style: const TextStyle(color: Color(0xFF8A8A8E), fontSize: 13),
          ),
          if (!_dashOverviewUnavailable &&
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
  // `StaggerIn`/`_CountUpText`, which both check the platform accessibility
  // flag and skip straight to the end state.

  BoxDecoration _cardDecoration({double radius = 16, List<BoxShadow>? shadow}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFEDEDED), width: 1),
      boxShadow:
          shadow ??
          [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
    );
  }

  Widget _dashSectionHeader(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: const Color(0xFF8A8A8E)),
        const SizedBox(width: 6),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Color(0xFF8A8A8E),
          ),
        ),
      ],
    );
  }

  Widget _dashSkeletonBlock() {
    final base = const Color(0xFFEDEDED);
    final hi = const Color(0xFFF8F8F8);
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
        StaggerIn(
          child: _dashHeroCard(
            s,
            total: total,
            onSite: onSite,
            attendance: attendance,
          ),
        ),
        if (productions.isNotEmpty) ...[
          const SizedBox(height: 24),
          StaggerIn(
            delay: const Duration(milliseconds: 140),
            child: _dashSectionHeader(
              Icons.insights_rounded,
              s.dashboardProductionIndicators,
            ),
          ),
          const SizedBox(height: 10),
          StaggerIn(
            delay: const Duration(milliseconds: 160),
            child: SizedBox(
              height: 118,
              child: LayoutBuilder(
                builder: (_, constraints) {
                  final cardWidth = _dashCardWidth(constraints.maxWidth);
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: productions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) =>
                        _dashProductionCard(productions[i], s, cardWidth),
                  );
                },
              ),
            ),
          ),
        ],
        if (factories.isNotEmpty) ...[
          const SizedBox(height: 24),
          StaggerIn(
            delay: const Duration(milliseconds: 200),
            child: _dashSectionHeader(
              Icons.factory_rounded,
              s.dashboardFactoriesDetail,
            ),
          ),
          const SizedBox(height: 10),
          StaggerIn(
            delay: const Duration(milliseconds: 220),
            child: SizedBox(
              height: 118,
              child: LayoutBuilder(
                builder: (_, constraints) {
                  final cardWidth = _dashCardWidth(constraints.maxWidth);
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: factories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) =>
                        _dashFactoryCard(factories[i], s, cardWidth),
                  );
                },
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
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(
        radius: 22,
        shadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
                          trackColor: const Color(0xFFEDEDED),
                          colors: const [_gradientStart, _gradientEnd],
                        ),
                      ),
                      Text(
                        '${(value * 100).round()}%',
                        style: const TextStyle(
                          color: Color(0xFF1C1C1E),
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
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: Color(0xFF8A8A8E),
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
                            color: Color(0xFF1C1C1E),
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        Text(
                          ' / $total',
                          style: const TextStyle(
                            color: Color(0xFF8A8A8E),
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
                        color: _gradientStart.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        s.dashboardOutOf(total),
                        style: TextStyle(
                          color: _gradientEnd,
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
          Container(height: 1, color: const Color(0xFFEDEDED)),
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
                  color: const Color(0xFFEDEDED),
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
    if (!_canSeeAttendance) return card;
    return _TappableHeroCard(
      label: s.attendanceTitle,
      onTap: _openAttendance,
      child: card,
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
                        color: Color(0xFF1C1C1E),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (suffix.isNotEmpty)
                      Text(
                        suffix,
                        style: const TextStyle(
                          color: Color(0xFF8A8A8E),
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
                    color: Color(0xFF1C1C1E),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF8A8A8E),
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

  static const double _dashCardSpacing = 10;

  // Sizes the horizontally-scrolling production/factory cards to exactly
  // fill the section with 2 whole cards (plus the separator between them).
  // A fractional divisor left a sliver of a third card poking out at the
  // trailing edge at rest, which read as a half-cut, unfinished-looking
  // block rather than an intentional "swipe for more" hint — sizing for an
  // exact fit removes that leftover peek; scrolling still reveals further
  // cards normally.
  double _dashCardWidth(double availableWidth) =>
      ((availableWidth - _dashCardSpacing) / 2).clamp(130.0, 200.0);

  Widget _dashProductionCard(Map<String, dynamic> prod, S s, double width) {
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
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration(radius: 14),
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
                                color: Color(0xFF1C1C1E),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (unit.isNotEmpty)
                              Text(
                                unit,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF8A8A8E),
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
                        style: const TextStyle(
                          color: Color(0xFF8A8A8E),
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

  Widget _dashFactoryCard(Map<String, dynamic> f, S s, double width) {
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
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration(radius: 14),
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
                            color: Color(0xFF1C1C1E),
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
                    style: const TextStyle(
                      color: Color(0xFF8A8A8E),
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
            style: const TextStyle(
              fontSize: 9.5,
              color: Color(0xFF8A8A8E),
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 10.5,
              color: emphasize
                  ? const Color(0xFF1C1C1E)
                  : const Color(0xFF636366),
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
              color: const Color(0xFFEDEDED),
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
    Widget passCard() => _MenuCard(
      icon: Icons.badge_rounded,
      label: s.menuPasses,
      description: s.menuPassesDesc,
      onTap: () => Navigator.push(
        context,
        FadeRoute(builder: (_) => PassesPage(jwtToken: widget.jwtToken)),
      ),
    );

    Widget signCard() => _MenuCard(
      icon: Icons.draw_rounded,
      label: s.menuSignRequests,
      description: s.menuSignRequestsDesc,
      onTap: () => Navigator.push(
        context,
        FadeRoute(builder: (_) => SignRequestsPage(jwtToken: widget.jwtToken)),
      ),
    );

    if (!_hasFullAccess) {
      final cards = <Widget>[
        if (_canSeePasses) passCard(),
        if (_canSignRequests) signCard(),
      ];
      return [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          cards[i],
        ],
      ];
    }

    return [
      _MenuCard(
        icon: Icons.receipt_long_rounded,
        label: s.menuPayments,
        description: s.menuPaymentsDesc,
        onTap: () => Navigator.push(
          context,
          FadeRoute(builder: (_) => MainPageScreen(jwtToken: widget.jwtToken)),
        ),
      ),
      const SizedBox(height: 12),
      passCard(),
      const SizedBox(height: 12),
      signCard(),
      const SizedBox(height: 12),
      _MenuCard(
        icon: Icons.card_giftcard_rounded,
        label: s.menuBonuses,
        description: s.menuBonusesDesc,
        onTap: () => Navigator.push(
          context,
          FadeRoute(builder: (_) => BonusesPage(jwtToken: widget.jwtToken)),
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
                    FadeRoute(
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
          if (!_canSeeShop)
            _NoAccessCard()
          else ...[
            _MenuCard(
              icon: Icons.storefront_rounded,
              label: s.shopPickupTitle,
              description: s.shopPickupDesc,
              onTap: () => Navigator.push(
                context,
                FadeRoute(
                  builder: (_) => ShopPickupPage(jwtToken: widget.jwtToken),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.inventory_2_rounded,
              label: s.shopStockTitle,
              description: s.shopStockDesc,
              onTap: () => Navigator.push(
                context,
                FadeRoute(
                  builder: (_) => ShopPvzStockPage(jwtToken: widget.jwtToken),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.insights_rounded,
              label: s.shopAnalyticsTitle,
              description: s.shopAnalyticsDesc,
              onTap: () => Navigator.push(
                context,
                FadeRoute(
                  builder: (_) => ShopAnalyticsPage(jwtToken: widget.jwtToken),
                ),
              ),
            ),
            if (_hasFullShopAccess) ...[
              const SizedBox(height: 12),
              _MenuCard(
                icon: Icons.fact_check_rounded,
                label: s.shopIssuedTitle,
                description: s.shopIssuedDesc,
                onTap: () => Navigator.push(
                  context,
                  FadeRoute(
                    builder: (_) =>
                        ShopIssuedReportPage(jwtToken: widget.jwtToken),
                  ),
                ),
              ),
            ],
          ],
        ],
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
    const brandOrange = AppColors.brandOrange;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: brandOrange.withOpacity(0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEDEDED), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
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
                  color: brandOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: brandOrange, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF1C1C1E),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
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
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFFC7C7CC),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDEDED), width: 1.2),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFF8A8A8E),
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            S.of(context).accessRestricted,
            style: const TextStyle(
              color: Color(0xFF1C1C1E),
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context).noAccessMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8A8A8E),
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


/// Marks the hero card as tappable: a round chevron button in the corner
/// that nudges sideways a few times on first show (skipped with
/// reduced motion), plus a subtle press-scale with haptic feedback.
class _TappableHeroCard extends StatefulWidget {
  final Widget child;
  final String label;
  final VoidCallback onTap;

  const _TappableHeroCard({
    required this.child,
    required this.label,
    required this.onTap,
  });

  @override
  State<_TappableHeroCard> createState() => _TappableHeroCardState();
}

class _TappableHeroCardState extends State<_TappableHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _nudge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  bool _pressed = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) return;
    Future<void>.delayed(const Duration(milliseconds: 900), () async {
      for (var i = 0; i < 3 && mounted; i++) {
        await _nudge.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          setState(() => _pressed = false);
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.975 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Stack(
            children: [
              widget.child,
              Positioned(top: 12, right: 12, child: _pill()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill() {
    // Icon-only on purpose: a text pill would collide with the "НА
    // ТЕРРИТОРИИ" caption on narrow phones.
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _MenuPageState._gradientStart.withOpacity(0.14),
      ),
      child: AnimatedBuilder(
        animation: _nudge,
        builder: (_, child) => Transform.translate(
          offset: Offset(math.sin(_nudge.value * math.pi) * 3, 0),
          child: child,
        ),
        child: const Icon(
          Icons.chevron_right_rounded,
          size: 22,
          color: _MenuPageState._gradientEnd,
        ),
      ),
    );
  }
}
