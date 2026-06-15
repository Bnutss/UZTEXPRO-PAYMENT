import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'package:uztexpro_payment/main.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import 'bonus_detail_page.dart';

const _kBonusPath = 'edo/bonus-employee';

// ─── Status config ────────────────────────────────────────────────────────────

class BonusStatusCfg {
  final String label;
  final String short;
  final Color color;
  final IconData icon;

  const BonusStatusCfg(this.label, this.short, this.color, this.icon);
}

BonusStatusCfg bonusStatusConfig(int code) {
  switch (code) {
    case 1:
      return const BonusStatusCfg(
        'Новый',
        'Новый',
        Color(0xFF1E88E5),
        Icons.fiber_new_rounded,
      );
    case 5:
      return const BonusStatusCfg(
        'На проверке',
        'Проверка',
        Color(0xFF00ACC1),
        Icons.rate_review_outlined,
      );
    case 2:
      return const BonusStatusCfg(
        'Одобрен',
        'Одобрен',
        Color(0xFFFF8C00),
        Icons.thumb_up_outlined,
      );
    case 3:
      return const BonusStatusCfg(
        'Утверждён',
        'Утверждён',
        Color(0xFF43A047),
        Icons.verified_outlined,
      );
    case 4:
      return const BonusStatusCfg(
        'Оплачен',
        'Оплачен',
        Color(0xFF7B1FA2),
        Icons.paid_outlined,
      );
    default:
      return BonusStatusCfg(
        'Статус $code',
        '$code',
        Colors.grey,
        Icons.help_outline,
      );
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class BonusesPage extends StatefulWidget {
  final String jwtToken;

  const BonusesPage({Key? key, required this.jwtToken}) : super(key: key);

  @override
  _BonusesPageState createState() => _BonusesPageState();
}

class _BonusesPageState extends State<BonusesPage>
    with SingleTickerProviderStateMixin {
  static const Color _g1 = Color(0xFFFF8C00);
  static const Color _g2 = Color(0xFFCC1500);

  static const String _kStage = 'stage';
  static const String _kCacheKey = 'bonuses_v2';

  static List<dynamic>? _memCache;
  static DateTime? _memCacheTime;
  static const Duration _kCacheTTL = Duration(minutes: 5);

  List<dynamic> _all = [];
  List<dynamic> _shown = [];
  bool _isLoading = true;
  bool _refreshing = false;
  String? _error;

  String _viewMode = _kStage;
  int? _statusFilter;

  final _searchCtrl = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), _filter);
    });
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

  // ── Data ─────────────────────────────────────────────────────────────────────

  Future<void> _load({bool forceRefresh = false}) async {
    if (!forceRefresh && _memCache != null && _memCacheTime != null) {
      final age = DateTime.now().difference(_memCacheTime!);
      if (age < _kCacheTTL) {
        _all = List.from(_memCache!);
        _filter();
        if (mounted)
          setState(() {
            _isLoading = false;
            _refreshing = false;
          });
        _animCtrl.forward(from: 0);
        return;
      }
      _all = List.from(_memCache!);
      _filter();
      if (mounted)
        setState(() {
          _isLoading = false;
          _refreshing = true;
          _error = null;
        });
      _animCtrl.forward(from: 0);
      await _fetchFromNetwork(silent: true);
      return;
    }

    if (!forceRefresh) {
      try {
        final raw = await storage.read(key: _kCacheKey);
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
          _animCtrl.forward(from: 0);
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
          .get(Uri.parse('$API/$_kBonusPath/?limit=500'), headers: _headers)
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final decoded = utf8.decode(resp.bodyBytes);
        storage.write(key: _kCacheKey, value: decoded);
        final body = json.decode(decoded);
        final List items = body is List
            ? body
            : (body['results'] ?? body['data'] ?? []);
        _memCache = items;
        _memCacheTime = DateTime.now();
        _all = items;
        _filter();
        setState(() {
          _isLoading = false;
          _refreshing = false;
        });
        if (!silent) _animCtrl.forward(from: 0);
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
      _shown = _all.where((item) {
        final status = item['status'] as int? ?? 0;
        if (_viewMode == _kStage) {
          if (item['is_change'] != true) return false;
          if (status == 4) return false;
        }
        final matchStatus = _statusFilter == null || status == _statusFilter;
        final matchSearch =
            q.isEmpty ||
            (item['factory_name']?.toString().toLowerCase().contains(q) ??
                false) ||
            (item['month_text']?.toString().toLowerCase().contains(q) ??
                false) ||
            (item['create_by_name']?.toString().toLowerCase().contains(q) ??
                false) ||
            (item['id']?.toString().contains(q) ?? false);
        return matchStatus && matchSearch;
      }).toList();
    });
  }

  void _switchView(String mode) {
    if (_viewMode == mode) return;
    setState(() {
      _viewMode = mode;
      _statusFilter = null;
    });
    _filter();
  }

  void _invalidateAndLoad() {
    _memCache = null;
    _memCacheTime = null;
    _load(forceRefresh: true);
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _onApprove(Map<String, dynamic> item) async {
    final ok = await _confirmDialog(
      icon: Icons.check_circle_outline_rounded,
      iconColor: const Color(0xFF43A047),
      title: S.of(context).bonusApproveTitle,
      message: S.of(context).bonusApproveDesc,
      confirmLabel: S.of(context).bonusApproveBtn,
      confirmColor: const Color(0xFF43A047),
    );
    if (!ok) return;
    setState(() => item['_busy'] = true);
    try {
      final id = item['id'];
      final resp = await http
          .patch(Uri.parse('$API/$_kBonusPath/$id/'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        _snack(S.of(context).bonusApproveSuccess, true);
        _invalidateAndLoad();
      } else {
        _snack(S.of(context).signError, false);
        setState(() => item['_busy'] = false);
      }
    } catch (_) {
      if (!mounted) return;
      _snack(S.of(context).connectionError, false);
      setState(() => item['_busy'] = false);
    }
  }

  Future<void> _onDelete(Map<String, dynamic> item) async {
    final ok = await _confirmDialog(
      icon: Icons.delete_outline_rounded,
      iconColor: Colors.red.shade600,
      title: S.of(context).bonusDeleteTitle,
      message: S.of(context).bonusDeleteDesc,
      confirmLabel: S.of(context).deleteBtn,
      confirmColor: Colors.red.shade600,
    );
    if (!ok) return;
    setState(() => item['_busy'] = true);
    try {
      final id = item['id'];
      final resp = await http
          .delete(Uri.parse('$API/$_kBonusPath/$id/'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (resp.statusCode == 200 || resp.statusCode == 204) {
        _snack(S.of(context).bonusDeleteSuccess, true);
        _invalidateAndLoad();
      } else {
        _snack(S.of(context).updateError, false);
        setState(() => item['_busy'] = false);
      }
    } catch (_) {
      if (!mounted) return;
      _snack(S.of(context).connectionError, false);
      setState(() => item['_busy'] = false);
    }
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────────

  Future<bool> _confirmDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: onSurface.withOpacity(0.2)),
                      ),
                      child: Text(
                        S.of(context).cancel,
                        style: TextStyle(
                          color: onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
    return result ?? false;
  }

  void _snack(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: ok ? const Color(0xFF43A047) : const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradColors = isDark
        ? [const Color(0xFF3D1800), const Color(0xFF1F0000)]
        : [_g1, _g2];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            s.bonusesTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (_refreshing)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white70),
                    ),
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: _isLoading ? null : _invalidateAndLoad,
              ),
          ],
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // ── Gradient header: toggle + count ──────────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Row(
                    children: [
                      _ViewToggle(selected: _viewMode, onChanged: _switchView),
                      const Spacer(),
                      if (!_isLoading && _error == null)
                        _CountBadge(count: _shown.length),
                    ],
                  ),
                ),
              ),
            ),
            // ── Search ───────────────────────────────────────────────────────
            Container(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: _SearchBar(
                controller: _searchCtrl,
                hintText: S.of(context).bonusSearchHint,
                isDark: isDark,
              ),
            ),
            // ── Status filter chips ──────────────────────────────────────────
            Container(
              color: isDark
                  ? Theme.of(context).colorScheme.surface
                  : const Color(0xFFF4F4F4),
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
            // ── List ─────────────────────────────────────────────────────────
            Expanded(
              child: Container(
                color: isDark
                    ? Theme.of(context).colorScheme.surface
                    : const Color(0xFFF4F4F4),
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
              FilledButton.icon(
                onPressed: _invalidateAndLoad,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(s.refresh),
                style: FilledButton.styleFrom(
                  backgroundColor: _g1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                Icons.card_giftcard_rounded,
                size: 38,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s.bonusesEmpty,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _viewMode == _kStage
                  ? s.noRecordsForSigning
                  : s.bonusListEmpty,
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
      child: RefreshIndicator(
        onRefresh: () async => _invalidateAndLoad(),
        color: _g1,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 32),
          itemCount: _shown.length,
          itemBuilder: (_, i) {
            final item = _shown[i] as Map<String, dynamic>;
            final status = item['status'] as int? ?? 0;
            final isChange = item['is_change'] == true && status != 4;
            final isDelete = item['is_delete'] == true;

            return _BonusCard(
              item: item,
              isDark: isDark,
              showApprove: isChange,
              showDelete: isDelete,
              onApprove: () => _onApprove(item),
              onDelete: () => _onDelete(item),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BonusDetailPage(
                    item: item,
                    jwtToken: widget.jwtToken,
                    canSign: isChange,
                    canDelete: isDelete,
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

// ─── Bonus Card ───────────────────────────────────────────────────────────────

class _BonusCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDark;
  final bool showApprove;
  final bool showDelete;
  final VoidCallback onApprove;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _BonusCard({
    required this.item,
    required this.isDark,
    required this.showApprove,
    required this.showDelete,
    required this.onApprove,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final cardBg = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : Colors.white;

    final id = item['id']?.toString() ?? '—';
    final factory = item['factory_name']?.toString() ?? '—';
    final month = item['month_text']?.toString() ?? '—';
    final status = item['status'] as int? ?? 0;
    final statusDisp = item['status_text']?.toString();
    final creator = item['create_by_name']?.toString() ?? '—';
    final totalBonus = item['total_bonus']?.toString() ?? '—';
    final createdAt = item['created_at']?.toString() ?? '—';
    final notes = item['notes']?.toString() ?? '';
    final busy = item['_busy'] == true;
    final hasActions = showApprove || showDelete;

    final cfg = bonusStatusConfig(status);
    final statusLabel = statusDisp ?? cfg.label;

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
                // ── Header ────────────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${S.of(context).bonusNumber}$id',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              _MonthPill(month),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 11,
                                color: onSurface.withOpacity(0.4),
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  createdAt,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: onSurface.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _BonusStatusBadge(cfg: cfg, label: statusLabel),
                  ],
                ),
                const SizedBox(height: 10),
                _CardDivider(isDark: isDark),
                const SizedBox(height: 8),
                // ── Info ──────────────────────────────────────────────────────
                _InfoLine(
                  icon: Icons.factory_outlined,
                  label: S.of(context).factoryLabel,
                  text: factory,
                  onSurface: onSurface,
                ),
                const SizedBox(height: 5),
                _InfoLine(
                  icon: Icons.person_outline_rounded,
                  label: S.of(context).createdByLabel,
                  text: creator,
                  onSurface: onSurface,
                ),
                const SizedBox(height: 5),
                _InfoLine(
                  icon: Icons.payments_outlined,
                  label: S.of(context).totalLabel,
                  text: '$totalBonus UZS',
                  onSurface: onSurface,
                  highlight: true,
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  _NoteRow(text: notes, isDark: isDark),
                ],
                const SizedBox(height: 10),
                _CardDivider(isDark: isDark),
                const SizedBox(height: 8),
                _BonusStatusProgress(status: status, isDark: isDark),
                // ── Actions ───────────────────────────────────────────────────
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
                  else
                    Row(
                      children: [
                        if (showDelete) ...[
                          Expanded(
                            child: _ActionBtn(
                              label: S.of(context).deleteBtn,
                              icon: Icons.delete_outline_rounded,
                              color: const Color(0xFFE53935),
                              bgColor: const Color(0xFFFFEBEE),
                              isDark: isDark,
                              onTap: onDelete,
                            ),
                          ),
                          if (showApprove) const SizedBox(width: 8),
                        ],
                        if (showApprove)
                          Expanded(
                            child: _ActionBtn(
                              label: S.of(context).bonusApproveBtn,
                              icon: Icons.check_rounded,
                              color: const Color(0xFF43A047),
                              bgColor: const Color(0xFFE8F5E9),
                              isDark: isDark,
                              onTap: onApprove,
                            ),
                          ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class _BonusStatusBadge extends StatelessWidget {
  final BonusStatusCfg cfg;
  final String label;

  const _BonusStatusBadge({required this.cfg, required this.label});

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
            constraints: const BoxConstraints(maxWidth: 90),
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

class _BonusStatusProgress extends StatelessWidget {
  final int status;
  final bool isDark;

  const _BonusStatusProgress({required this.status, required this.isDark});

  List<(int, String, Color)> _steps(S s) => [
    (1, s.bonusStatusNew, Color(0xFF1E88E5)),
    (5, s.bonusStatusReview, Color(0xFF00ACC1)),
    (2, s.bonusStatusApproved, Color(0xFFFF8C00)),
    (3, s.bonusStatusConfirmed, Color(0xFF43A047)),
    (4, s.bonusStatusPaid, Color(0xFF7B1FA2)),
  ];

  int _idx(List<(int, String, Color)> steps) {
    for (int i = 0; i < steps.length; i++) {
      if (steps[i].$1 == status) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final steps = _steps(S.of(context));
    final idx = _idx(steps);
    final inactiveDot = isDark ? Colors.white12 : Colors.grey.shade200;
    final inactiveLine = isDark ? Colors.white10 : Colors.grey.shade200;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              _Dot(
                done: idx >= 0 && i < idx,
                current: i == idx,
                color: steps[i].$3,
                inactiveColor: inactiveDot,
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: (idx >= 0 && i < idx)
                          ? steps[i].$3
                          : inactiveLine,
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
                  fontWeight: i == idx ? FontWeight.w700 : FontWeight.w400,
                  color: (idx >= 0 && i <= idx)
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _VTab(
            label: S.of(context).forSigning,
            active: selected == 'stage',
            onTap: () => onChanged('stage'),
          ),
          _VTab(
            label: S.of(context).filterAll,
            active: selected == 'all',
            onTap: () => onChanged('all'),
          ),
        ],
      ),
    );
  }
}

class _VTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _VTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active
                ? const Color(0xFFCC1500)
                : Colors.white.withOpacity(0.8),
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _SChip(
            label: allLabel,
            selected: selected == null,
            color: isDark ? Colors.white70 : Colors.grey.shade600,
            isDark: isDark,
            onTap: () => onSelect(null),
          ),
          for (final code in [1, 5, 2, 3, 4]) ...[
            const SizedBox(width: 6),
            _SChip(
              label: bonusStatusConfig(code).short,
              selected: selected == code,
              color: bonusStatusConfig(code).color,
              isDark: isDark,
              onTap: () => onSelect(code),
            ),
          ],
        ],
      ),
    );
  }
}

class _SChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _SChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? color
              : (isDark ? Colors.white.withOpacity(0.07) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? color
                : (isDark ? Colors.white12 : Colors.grey.shade200),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!selected)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────

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
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// ─── Count badge ──────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─── Month pill ───────────────────────────────────────────────────────────────

class _MonthPill extends StatelessWidget {
  final String label;

  const _MonthPill(this.label);

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

// ─── Info line ────────────────────────────────────────────────────────────────

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final Color onSurface;
  final bool highlight;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.text,
    required this.onSurface,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 13,
          color: highlight
              ? const Color(0xFFFF8C00)
              : onSurface.withOpacity(0.35),
        ),
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
              color: highlight
                  ? const Color(0xFFFF8C00)
                  : onSurface.withOpacity(0.85),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Note row ─────────────────────────────────────────────────────────────────

class _NoteRow extends StatelessWidget {
  final String text;
  final bool isDark;

  const _NoteRow({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.notes_rounded,
          size: 13,
          color: isDark ? Colors.amber.shade300 : Colors.amber.shade700,
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
              color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Card divider ─────────────────────────────────────────────────────────────

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

// ─── Action button ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? color.withOpacity(0.15) : bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(isDark ? 0.35 : 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
