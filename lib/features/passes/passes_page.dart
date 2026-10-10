import '../../core/widgets/fade_route.dart';
import '../../core/widgets/app_button.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:uztexpro_payment/main.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/adaptive_back_button.dart';
import '../../core/widgets/app_refresh.dart';
import '../../core/widgets/app_segmented_control.dart';
import '../../core/widgets/search_toggle.dart';
import 'pass_detail_page.dart';

const _kPassPath = 'common/pass';

// ─── Status config ────────────────────────────────────────────────────────────

class PassStatusCfg {
  final String label;
  final String short;
  final Color color;
  final IconData icon;
  const PassStatusCfg(this.label, this.short, this.color, this.icon);
}

PassStatusCfg passStatusConfig(int code) {
  switch (code) {
    case -1:
      return const PassStatusCfg(
        'Отменён',
        'Отменён',
        Color(0xFF757575),
        Icons.cancel_outlined,
      );
    case 0:
      return const PassStatusCfg(
        'Новый',
        'Новый',
        Color(0xFF1E88E5),
        Icons.fiber_new_rounded,
      );
    case 1:
      return const PassStatusCfg(
        'Выдан (Отпустил подписал)',
        'Выдан',
        Color(0xFFFF8C00),
        Icons.how_to_reg_rounded,
      );
    case 2:
      return const PassStatusCfg(
        'Подписан гл. бухгалтером',
        'Бухгалтер',
        Color(0xFFF57C00),
        Icons.account_balance_outlined,
      );
    case 3:
      return const PassStatusCfg(
        'Подписан руководителем',
        'Руководитель',
        Color(0xFF43A047),
        Icons.verified_outlined,
      );
    case 4:
      return const PassStatusCfg(
        'Завершён',
        'Завершён',
        Color(0xFF2E7D32),
        Icons.check_circle_outlined,
      );
    default:
      return PassStatusCfg(
        'Статус $code',
        '$code',
        Colors.grey,
        Icons.help_outline,
      );
  }
}

String? _roleForStatus(int status) {
  switch (status) {
    case 0:
      return 'release';
    case 1:
      return 'accountant';
    case 2:
      return 'director';
    case 3:
      return 'security';
    default:
      return null;
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class PassesPage extends StatefulWidget {
  final String jwtToken;
  const PassesPage({Key? key, required this.jwtToken}) : super(key: key);

  @override
  _PassesPageState createState() => _PassesPageState();
}

class _PassesPageState extends State<PassesPage>
    with SingleTickerProviderStateMixin {
  static const Color _g1 = AppColors.brandOrange;

  static const String _kStage = 'stage';
  static const String _kMy = 'my';
  static const String _kAll = 'all';

  static final Map<String, List<dynamic>> _memCache = {};
  static final Map<String, DateTime> _memCacheTime = {};
  static const Duration _kCacheTTL = Duration(minutes: 5);

  List<dynamic> _all = [];
  List<dynamic> _shown = [];
  bool _isLoading = true;
  bool _refreshing = false;
  String? _error;

  String _viewMode = _kStage;
  int? _statusFilter;

  final _searchCtrl = TextEditingController();
  bool _searching = false;

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _searchCtrl.clear();
    });
  }

  Timer? _debounce;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  String get _token {
    try {
      return jsonDecode(widget.jwtToken)['token'] as String;
    } catch (_) {
      return widget.jwtToken;
    }
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_token',
    'Content-Type': 'application/json',
  };

  String get _cacheKey => 'passes_v4_$_viewMode';

  String get _fetchUrl {
    switch (_viewMode) {
      case _kMy:
        return '$API/$_kPassPath/?view=my';
      case _kAll:
        return '$API/$_kPassPath/?view=all';
      default:
        return '$API/$_kPassPath/';
    }
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      // Start fully visible: fading in from 0 after the shimmer left a blank
      // frame between shimmer and list, which read as screen flicker.
      value: 1,
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), _filter);
    });
    // Fresh in-memory cache: render the list on the very first frame instead
    // of flashing the shimmer for one frame first.
    final cached = _memCache[_viewMode];
    final cachedAt = _memCacheTime[_viewMode];
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _kCacheTTL) {
      _all = List.from(cached);
      _shown = _all.where((p) {
        final status = p['status'] as int? ?? 0;
        return _viewMode != _kStage || _signerStatuses.contains(status);
      }).toList();
      _isLoading = false;
    }
    _load();
    localeNotifier.addListener(_onLocale);
  }

  void _onLocale() => setState(() {});

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    localeNotifier.removeListener(_onLocale);
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  Future<void> _load({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _memCache[_viewMode];
      final cachedAt = _memCacheTime[_viewMode];
      if (cached != null && cachedAt != null) {
        final age = DateTime.now().difference(cachedAt);
        if (age < _kCacheTTL) {
          _all = List.from(cached);
          _filter();
          if (mounted)
            setState(() {
              _isLoading = false;
              _refreshing = false;
            });
          return;
        }
        _all = List.from(cached);
        _filter();
        if (mounted)
          setState(() {
            _isLoading = false;
            _refreshing = true;
            _error = null;
          });
        await _fetchFromNetwork(silent: true);
        return;
      }
    }

    if (!forceRefresh) {
      try {
        final raw = await storage.read(key: _cacheKey);
        if (raw != null && mounted) {
          final body = json.decode(raw);
          final List items = body is List
              ? body
              : (body['results'] ?? body['data'] ?? []);
          _all = items;
          _filter();
          setState(() {
            _isLoading = false;
            _refreshing = true;
            _error = null;
          });
          await _fetchFromNetwork(silent: true);
          return;
        }
      } catch (_) {}
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _refreshing = false;
    });
    await _fetchFromNetwork(silent: false);
  }

  Future<void> _fetchFromNetwork({required bool silent}) async {
    try {
      final resp = await http
          .get(Uri.parse(_fetchUrl), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        storage.write(key: _cacheKey, value: utf8.decode(resp.bodyBytes));
        final body = json.decode(utf8.decode(resp.bodyBytes));
        final List items = body is List
            ? body
            : (body['results'] ?? body['data'] ?? []);
        _memCache[_viewMode] = items;
        _memCacheTime[_viewMode] = DateTime.now();
        _all = items;
        _filter();
        setState(() {
          _isLoading = false;
          _refreshing = false;
        });
      } else {
        if (!silent) {
          setState(() {
            _error = '${S.of(context).loadDataError} (${resp.statusCode})';
            _isLoading = false;
          });
        } else {
          if (mounted) setState(() => _refreshing = false);
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = '${S.of(context).connectionError}\n$e';
          _isLoading = false;
        });
      } else {
        setState(() => _refreshing = false);
      }
    }
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _shown = _all.where((p) {
        final status = p['status'] as int? ?? 0;
        if (_viewMode == _kStage && !_signerStatuses.contains(status))
          return false;
        final matchStatus = _statusFilter == null || status == _statusFilter;
        final matchSearch =
            q.isEmpty ||
            (p['number']?.toString().toLowerCase().contains(q) ?? false) ||
            (p['client']?.toString().toLowerCase().contains(q) ?? false);
        return matchStatus && matchSearch;
      }).toList();
    });
  }

  void _switchView(String mode) {
    if (_viewMode == mode) return;
    setState(() {
      _viewMode = mode;
      _statusFilter = null;
      _isLoading = true;
      _error = null;
    });
    _load();
  }

  void _invalidateAndLoad() {
    _memCache.remove(_viewMode);
    _memCacheTime.remove(_viewMode);
    _load(forceRefresh: true);
  }

  // ── User sign roles ──────────────────────────────────────────────────────────

  static const _kGroupToStatus = {
    'release_sign_pass': 0,
    'acc_sign_pass': 1,
    'seo_sign_pass': 2,
    'security_sign_pass': 3,
  };

  Set<int>? _cachedSignerStatuses;

  Set<int> get _signerStatuses {
    if (_cachedSignerStatuses != null) return _cachedSignerStatuses!;
    _cachedSignerStatuses = _computeSignerStatuses();
    return _cachedSignerStatuses!;
  }

  Set<int> _computeSignerStatuses() {
    // Try JSON login response body (e.g. {"token": "...", "groups": [...]})
    try {
      final body = jsonDecode(widget.jwtToken) as Map<String, dynamic>;
      final raw =
          body['groups'] ??
          ((body['user'] is Map) ? (body['user'] as Map)['groups'] : null);
      if (raw is List && raw.isNotEmpty) {
        return _groupsToStatuses(raw.map((e) => e.toString()).toSet());
      }
    } catch (_) {}

    // Try JWT payload (some backends embed groups in JWT claims)
    try {
      final parts = _token.split('.');
      if (parts.length == 3) {
        var seg = parts[1];
        while (seg.length % 4 != 0) seg += '=';
        final payload = jsonDecode(utf8.decode(base64.decode(seg)));
        final raw = payload['groups'] ?? payload['user_groups'];
        if (raw is List && raw.isNotEmpty) {
          return _groupsToStatuses(raw.map((e) => e.toString()).toSet());
        }
      }
    } catch (_) {}

    // Could not determine groups — show buttons for all sign statuses (backend will reject if unauthorised)
    return const {0, 1, 2, 3};
  }

  Set<int> _groupsToStatuses(Set<String> groups) {
    final result = <int>{};
    for (final g in groups) {
      final s = _kGroupToStatus[g];
      if (s != null) result.add(s);
    }
    return result.isEmpty ? const {0, 1, 2, 3} : result;
  }

  // ── Sign actions ─────────────────────────────────────────────────────────────

  Future<void> _onApprove(Map<String, dynamic> pass) async {
    final number = pass['number']?.toString() ?? '';
    await AdaptiveAlertDialog.show(
      context: context,
      title: S.of(context).confirmPass,
      message: S.of(context).confirmPassNumber(number),
      icon: PlatformInfo.isIOS26OrHigher()
          ? 'checkmark.circle.fill'
          : Icons.check_circle_outline_rounded,
      iconColor: const Color(0xFF43A047),
      actions: [
        AlertAction(
          title: S.of(context).cancel,
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: S.of(context).confirm,
          style: AlertActionStyle.primary,
          onPressed: () => _doSign(pass, 'approve'),
        ),
      ],
    );
  }

  Future<void> _onReject(Map<String, dynamic> pass) async {
    final number = pass['number']?.toString() ?? '';
    final comment = await AdaptiveAlertDialog.inputShow(
      context: context,
      title: S.of(context).rejectPass,
      message: number,
      icon: PlatformInfo.isIOS26OrHigher()
          ? 'xmark.circle.fill'
          : Icons.cancel_outlined,
      iconColor: Colors.red,
      input: AdaptiveAlertDialogInput(
        placeholder: S.of(context).rejectionReasonHint,
      ),
      actions: [
        AlertAction(
          title: S.of(context).cancel,
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: S.of(context).reject,
          style: AlertActionStyle.destructive,
          onPressed: () {},
        ),
      ],
    );
    if (comment == null) return;
    await _doSign(pass, 'reject', comment: comment);
  }

  Future<void> _onCancel(Map<String, dynamic> pass) async {
    final number = pass['number']?.toString() ?? '';
    await AdaptiveAlertDialog.show(
      context: context,
      title: S.of(context).cancelPass,
      message: S.of(context).cancelPassMessage(number),
      icon: PlatformInfo.isIOS26OrHigher()
          ? 'xmark.circle.fill'
          : Icons.cancel_outlined,
      iconColor: Colors.grey.shade600,
      actions: [
        AlertAction(
          title: S.of(context).cancel,
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: S.of(context).cancelBtn,
          style: AlertActionStyle.destructive,
          onPressed: () => _doSign(pass, 'cancel'),
        ),
      ],
    );
  }

  Future<void> _doSign(
    Map<String, dynamic> pass,
    String action, {
    String? comment,
  }) async {
    final id = pass['id'];
    final status = pass['status'] as int? ?? -1;
    final role = action == 'cancel' ? 'cancel' : _roleForStatus(status);
    if (role == null) return;

    setState(() => pass['_busy'] = true);
    try {
      final Map<String, dynamic> body = action == 'cancel'
          ? {}
          : action == 'reject'
          ? {'action': 'reject', 'comment': comment ?? ''}
          : {'action': 'approve'};

      final resp = await http
          .post(
            Uri.parse('$API/$_kPassPath/$id/sign/$role/'),
            headers: _headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        _snack(
          action == 'reject'
              ? S.of(context).passRejected
              : action == 'cancel'
              ? S.of(context).passCancelled
              : S.of(context).passConfirmed,
          true,
        );
        _memCache.remove(_viewMode);
        _memCacheTime.remove(_viewMode);
        await _load(forceRefresh: true);
      } else {
        String errMsg = S.of(context).errorWithCode(resp.statusCode);
        try {
          final err = json.decode(utf8.decode(resp.bodyBytes));
          errMsg = err['error'] ?? err['detail'] ?? errMsg;
        } catch (_) {}
        _snack(errMsg, false);
        setState(() => pass['_busy'] = false);
      }
    } catch (e) {
      if (!mounted) return;
      _snack(S.of(context).errorWithMessage(e.toString()), false);
      setState(() => pass['_busy'] = false);
    }
  }

  void _snack(String msg, bool ok) {
    AdaptiveSnackBar.show(
      context,
      message: msg,
      type: ok ? AdaptiveSnackBarType.success : AdaptiveSnackBarType.error,
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: kBackButtonLeadingWidth,
          leading: const AdaptiveBackButton(),
          title: Text(
            s.menuPasses,
            style: const TextStyle(
              color: Color(0xFF1C1C1E),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: false,
          backgroundColor: isDark
              ? Theme.of(context).colorScheme.surface
              : AppColors.groupedBackground,
          foregroundColor: const Color(0xFF1C1C1E),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          actions: [
            if (!_isLoading && _error == null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(child: _CountBadge(count: _shown.length)),
              ),
            SearchToggleButton(active: _searching, onPressed: _toggleSearch),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: isDark
                  ? Theme.of(context).colorScheme.surface
                  : AppColors.groupedBackground,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: _ViewToggle(selected: _viewMode, onChanged: _switchView),
            ),
            AnimatedSearchSlot(
              open: _searching,
              child: Container(
                color: isDark
                    ? Theme.of(context).colorScheme.surface
                    : AppColors.groupedBackground,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: _SearchBar(
                  controller: _searchCtrl,
                  hintText: s.passSearchHint,
                  isDark: isDark,
                ),
              ),
            ),
            Container(
              color: isDark
                  ? Theme.of(context).colorScheme.surface
                  : AppColors.groupedBackground,
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: _StatusFilterRow(
                selected: _statusFilter,
                isDark: isDark,
                allLabel: s.filterAll,
                onSelect: (code) {
                  setState(
                    () => _statusFilter = _statusFilter == code ? null : code,
                  );
                  _filter();
                },
              ),
            ),
            Expanded(
              child: Container(
                color: isDark
                    ? Theme.of(context).colorScheme.surface
                    : AppColors.groupedBackground,
                child: _buildBody(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    final s = S.of(context);
    if (_isLoading) return _shimmer(isDark);

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 36,
                  color: isDark ? Colors.white38 : Colors.red.shade300,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              // minSize is required here: the real native iOS 26 button (see
              // `.child` mode) has no way to report its UIKit content size
              // back to Flutter's layout, so without an explicit width it
              // would stretch to fill this Column's full loose width instead
              // of hugging the icon+label like a normal button.
              SizedBox(
                width: 160,
                height: 46,
                child: AppButton(
                  onPressed: _invalidateAndLoad,
                  style: AdaptiveButtonStyle.filled,
                  color: _g1,
                  borderRadius: BorderRadius.circular(12),
                  minSize: const Size(160, 46),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.refresh,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_shown.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.white,
                shape: BoxShape.circle,
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                        ),
                      ],
              ),
              child: Icon(
                Icons.badge_outlined,
                size: 38,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s.passesEmpty,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              s.passesEmptyDesc,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: AppRefresh(
        onRefresh: () async => _invalidateAndLoad(),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 32),
          itemCount: _shown.length,
          itemBuilder: (_, i) {
            final pass = _shown[i];
            final status = pass['status'] as int? ?? 0;

            // В режиме "На подпись" кнопка показывается только для статуса,
            // соответствующего группе текущего пользователя.
            final showApproveReject =
                _viewMode == _kStage && _signerStatuses.contains(status);
            final showCancel = _viewMode == _kMy && status == 0;

            return _PassCard(
              pass: pass,
              isDark: isDark,
              showApproveReject: showApproveReject,
              showCancel: showCancel,
              onApprove: () => _onApprove(pass),
              onReject: () => _onReject(pass),
              onCancel: () => _onCancel(pass),
              onTap: () => Navigator.push(
                context,
                FadeRoute(
                  builder: (_) => PassDetailPage(
                    passId: pass['id'] as int,
                    jwtToken: widget.jwtToken,
                    // Можно подписать только если пришли из "На подпись"
                    canSign: showApproveReject,
                    canCancel: showCancel,
                    onActionDone: _invalidateAndLoad,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _shimmer(bool isDark) {
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final hi = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Shimmer.fromColors(
          baseColor: base,
          highlightColor: hi,
          child: Container(
            height: 148,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Pass Card ────────────────────────────────────────────────────────────────

class _PassCard extends StatelessWidget {
  final Map<String, dynamic> pass;
  final bool isDark;
  final bool showApproveReject;
  final bool showCancel;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCancel;
  final VoidCallback onTap;

  const _PassCard({
    required this.pass,
    required this.isDark,
    required this.showApproveReject,
    required this.showCancel,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
    required this.onTap,
  });

  String _fmt(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      return DateFormat('dd.MM.yyyy').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final cardBg = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : Colors.white;

    final number = pass['number']?.toString() ?? '—';
    final date = _fmt(pass['date']?.toString());
    final client = pass['client']?.toString() ?? '—';
    final factory = pass['factory_name']?.toString() ?? '—';
    final typeName = pass['pass_type_name']?.toString() ?? '—';
    final status = pass['status'] as int? ?? 0;
    final statusDisp = pass['status_display']?.toString();
    final itemsCount = (pass['items'] as List?)?.length ?? 0;
    final createdBy = pass['create_by_name']?.toString() ?? '—';
    final comment = pass['comment']?.toString() ?? '';
    final rejComment = pass['rejection_comment']?.toString() ?? '';
    final busy = pass['_busy'] == true;

    final cfg = passStatusConfig(status);
    final statusLabel = statusDisp ?? cfg.label;
    final hasActions = showApproveReject || showCancel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: cfg.color, width: 4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            number,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              _TypePill(typeName),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 11,
                                color: onSurface.withOpacity(0.4),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                date,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: onSurface.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(cfg: cfg, label: statusLabel),
                  ],
                ),
                const SizedBox(height: 10),
                _CardDivider(isDark: isDark),
                const SizedBox(height: 8),
                // ── Info ──────────────────────────────────────
                _InfoLine(
                  icon: Icons.business_outlined,
                  label: S.of(context).client,
                  text: client,
                  onSurface: onSurface,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: _InfoLine(
                        icon: Icons.factory_outlined,
                        label: S.of(context).factoryLabel2,
                        text: factory,
                        onSurface: onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ItemsChip(count: itemsCount, isDark: isDark),
                  ],
                ),
                const SizedBox(height: 5),
                _InfoLine(
                  icon: Icons.person_outline_rounded,
                  label: S.of(context).createdByLabel2,
                  text: createdBy,
                  onSurface: onSurface,
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  _NoteRow(text: comment, isDark: isDark, isError: false),
                ],
                if (rejComment.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _NoteRow(
                    text: S.of(context).reasonWithText(rejComment),
                    isDark: isDark,
                    isError: true,
                  ),
                ],
                const SizedBox(height: 10),
                _CardDivider(isDark: isDark),
                const SizedBox(height: 8),
                _StatusProgress(status: status, isDark: isDark),
                // ── Actions ───────────────────────────────────
                if (hasActions) ...[
                  const SizedBox(height: 10),
                  _CardDivider(isDark: isDark),
                  const SizedBox(height: 10),
                  if (busy)
                    const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Color(0xFFFF8C00)),
                        ),
                      ),
                    )
                  else if (showApproveReject)
                    _SignButtons(
                      status: status,
                      onApprove: onApprove,
                      onReject: onReject,
                      isDark: isDark,
                    )
                  else if (showCancel)
                    _CancelButton(onCancel: onCancel, isDark: isDark),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sign buttons ─────────────────────────────────────────────────────────────

class _SignButtons extends StatelessWidget {
  final int status;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool isDark;

  const _SignButtons({
    required this.status,
    required this.onApprove,
    required this.onReject,
    required this.isDark,
  });

  String _approveLabel(BuildContext context) {
    final s = S.of(context);
    switch (status) {
      case 0:
        return s.issue;
      case 1:
        return s.accountantSign;
      case 2:
        return s.directorSign;
      case 3:
        return s.securitySign;
      default:
        return s.confirm;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionBtn(
          label: _approveLabel(context),
          icon: Icons.check_rounded,
          color: const Color(0xFF43A047),
          isDark: isDark,
          onTap: onApprove,
        ),
        const SizedBox(height: 7),
        _ActionBtn(
          label: S.of(context).reject,
          icon: Icons.close_rounded,
          color: const Color(0xFFE53935),
          isDark: isDark,
          onTap: onReject,
        ),
      ],
    );
  }
}

class _CancelButton extends StatelessWidget {
  final VoidCallback onCancel;
  final bool isDark;
  const _CancelButton({required this.onCancel, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return _ActionBtn(
      label: S.of(context).cancelPass,
      icon: Icons.cancel_outlined,
      color: Colors.grey.shade600,
      isDark: isDark,
      onTap: onCancel,
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Plain Flutter button: a native AdaptiveButton is a platform view that
    // ignores the FadeRoute opacity and flashes when the page closes.
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 15),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final PassStatusCfg cfg;
  final String label;
  const _StatusBadge({required this.cfg, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: cfg.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cfg.color.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cfg.icon, size: 12, color: cfg.color),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cfg.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status progress bar ──────────────────────────────────────────────────────

class _StatusProgress extends StatelessWidget {
  final int status;
  final bool isDark;
  const _StatusProgress({required this.status, required this.isDark});

  List<(int, String, Color)> _steps(S s) => [
    (0, s.progressNew, Color(0xFF1E88E5)),
    (1, s.progressIssued, Color(0xFFFF8C00)),
    (2, s.passStatusAccountant, Color(0xFFF57C00)),
    (3, s.passStatusShortDir, Color(0xFF43A047)),
    (4, s.progressCompleted, Color(0xFF2E7D32)),
  ];

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final steps = _steps(S.of(context));
    if (status == -1) {
      return Row(
        children: [
          const Icon(Icons.cancel_outlined, size: 14, color: Color(0xFF757575)),
          const SizedBox(width: 6),
          Text(
            S.of(context).passCancelled,
            style: TextStyle(
              fontSize: 11,
              color: onSurface.withOpacity(0.4),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }
    final inactiveDot = isDark ? Colors.white12 : Colors.grey.shade200;
    final inactiveLine = isDark ? Colors.white10 : Colors.grey.shade200;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              _Dot(
                done: status > steps[i].$1,
                current: status == steps[i].$1,
                color: steps[i].$3,
                inactiveColor: inactiveDot,
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: status > steps[i].$1 ? steps[i].$3 : inactiveLine,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              Text(
                steps[i].$2,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: status == steps[i].$1
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: status >= steps[i].$1
                      ? steps[i].$3
                      : onSurface.withOpacity(0.28),
                ),
              ),
              if (i < steps.length - 1) const Spacer(),
            ],
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final bool done;
  final bool current;
  final Color color;
  final Color inactiveColor;
  const _Dot({
    required this.done,
    required this.current,
    required this.color,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final size = current ? 18.0 : 14.0;
    final active = done || current;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : inactiveColor,
        border: Border.all(
          color: active ? color : Colors.grey.shade300,
          width: current ? 2.5 : 1.5,
        ),
        boxShadow: current
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: active
          ? Icon(Icons.check_rounded, size: size * 0.58, color: Colors.white)
          : null,
    );
  }
}

// ─── View toggle ──────────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _ViewToggle({required this.selected, required this.onChanged});

  static const _modes = ['stage', 'my', 'all'];

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    return AppSegmentedControl(
      labels: [t.forSigning, t.my, t.filterAll],
      selectedIndex: _modes.indexOf(selected).clamp(0, _modes.length - 1),
      onChanged: (i) => onChanged(_modes[i]),
      minSegmentWidth: 0,
      padding: EdgeInsets.zero,
    );
  }
}

// ─── Status filter chips ──────────────────────────────────────────────────────

class _StatusFilterRow extends StatelessWidget {
  final int? selected;
  final bool isDark;
  final String allLabel;
  final ValueChanged<int?> onSelect;
  const _StatusFilterRow({
    required this.selected,
    required this.isDark,
    required this.allLabel,
    required this.onSelect,
  });

  static const _codes = <int?>[null, 0, 1, 2, 3, 4, -1];

  @override
  Widget build(BuildContext context) {
    return AppSegmentedControl(
      labels: [
        allLabel,
        for (final code in _codes.skip(1)) passStatusConfig(code!).short,
      ],
      selectedIndex: _codes.indexOf(selected).clamp(0, _codes.length - 1),
      onChanged: (i) => onSelect(_codes[i]),
    );
  }
}

// ─── Micro widgets ────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isDark;
  const _SearchBar({
    required this.controller,
    required this.hintText,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.07) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: TextField(
        autofocus: true,
        controller: controller,
        style: TextStyle(color: onSurface, fontSize: 14),
        decoration: InputDecoration(
          hintText: '$hintText...',
          hintStyle: TextStyle(
            color: onSurface.withOpacity(0.38),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: onSurface.withOpacity(0.38),
            size: 20,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, __) => v.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      size: 18,
                      color: onSurface.withOpacity(0.4),
                    ),
                    onPressed: controller.clear,
                  ),
          ),
          // Without this the field inherits filled+fillColor from the
          // app's global InputDecorationTheme and paints its own
          // sharp-cornered fill on top of this widget's rounded outer
          // Container.
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandOrange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.brandRed,
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String label;
  const _TypePill(this.label);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white60 : Colors.grey.shade600,
        ),
      ),
    );
  }
}

class _ItemsChip extends StatelessWidget {
  final int count;
  final bool isDark;
  const _ItemsChip({required this.count, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFFFF8C00).withOpacity(0.15)
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? const Color(0xFFFF8C00).withOpacity(0.3)
              : Colors.orange.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.layers_outlined,
            size: 12,
            color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            '$count поз.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final Color onSurface;
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.text,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: onSurface.withOpacity(0.35)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.45)),
        ),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: onSurface.withOpacity(0.85),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoteRow extends StatelessWidget {
  final String text;
  final bool isDark;
  final bool isError;
  const _NoteRow({
    required this.text,
    required this.isDark,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final c = isError ? Colors.red : Colors.amber;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isError ? Icons.warning_amber_rounded : Icons.notes_rounded,
          size: 13,
          color: isDark ? c.shade300 : c.shade700,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: isDark ? c.shade300 : c.shade800,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardDivider extends StatelessWidget {
  final bool isDark;
  const _CardDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? Colors.white10 : Colors.grey.shade100,
    );
  }
}
