import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uztexpro_payment/main.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import 'sign_request_detail_page.dart';

const _kPath = 'texmansys/material-purchase-application';

class SignRequestsPage extends StatefulWidget {
  final String jwtToken;
  const SignRequestsPage({Key? key, required this.jwtToken}) : super(key: key);

  @override
  _SignRequestsPageState createState() => _SignRequestsPageState();
}

class _SignRequestsPageState extends State<SignRequestsPage>
    with SingleTickerProviderStateMixin {
  static const Color _g1 = Color(0xFFFF8C00);
  static const Color _g2 = Color(0xFFCC1500);
  static const String _kCacheKey = 'sign_requests_v2';

  static List<dynamic>? _memCache;
  static DateTime? _memCacheTime;
  static const Duration _kCacheTTL = Duration(minutes: 5);

  List<dynamic> _all = [];
  List<dynamic> _shown = [];
  bool _isLoading = true;
  bool _refreshing = false;
  String? _error;

  String _statusFilter = 'all';

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
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _searchCtrl.addListener(() => _filter(_searchCtrl.text));
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

  Future<void> _load({bool forceRefresh = false}) async {
    if (!forceRefresh && _memCache != null && _memCacheTime != null) {
      final age = DateTime.now().difference(_memCacheTime!);
      if (age < _kCacheTTL) {
        _all = List.from(_memCache!);
        _filter(_searchCtrl.text);
        if (mounted) setState(() { _isLoading = false; _refreshing = false; });
        _animCtrl.forward(from: 0);
        return;
      }
      _all = List.from(_memCache!);
      _filter(_searchCtrl.text);
      if (mounted) setState(() { _isLoading = false; _refreshing = true; _error = null; });
      _animCtrl.forward(from: 0);
      await _fetchFromNetwork(silent: true);
      return;
    }

    if (!forceRefresh) {
      try {
        final cached = await storage.read(key: _kCacheKey);
        if (cached != null && mounted) {
          final body = json.decode(cached);
          final List raw = body is List ? body : (body['results'] ?? body['data'] ?? []);
          _all = raw.where((a) => a['status'] == 0 || a['status'] == 1).toList();
          _filter(_searchCtrl.text);
          setState(() { _isLoading = false; _refreshing = true; _error = null; });
          _animCtrl.forward(from: 0);
          await _fetchFromNetwork(silent: true);
          return;
        }
      } catch (_) {}
    }

    setState(() { _isLoading = true; _error = null; _refreshing = false; });
    await _fetchFromNetwork(silent: false);
  }

  Future<void> _fetchFromNetwork({required bool silent}) async {
    try {
      final resp = await http
          .get(Uri.parse('$API/$_kPath/?limit=1000'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        storage.write(key: _kCacheKey, value: utf8.decode(resp.bodyBytes));
        final body = json.decode(utf8.decode(resp.bodyBytes));
        final List raw = body is List ? body : (body['results'] ?? body['data'] ?? []);
        final filtered = raw.where((a) => a['status'] == 0 || a['status'] == 1).toList();
        _memCache = filtered;
        _memCacheTime = DateTime.now();
        _all = filtered;
        _filter(_searchCtrl.text);
        setState(() { _isLoading = false; _refreshing = false; });
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
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = S.of(context).connectionError;
          _isLoading = false;
        });
      } else {
        setState(() => _refreshing = false);
      }
    }
  }

  void _filter(String q) {
    final trimmed = q.trim().toLowerCase();
    final byStatus = _statusFilter == 'all'
        ? _all
        : _all
            .where((a) => a['status'] == (_statusFilter == 'pending' ? 0 : 1))
            .toList();
    setState(() {
      _shown = trimmed.isEmpty
          ? byStatus
          : byStatus.where((a) {
              return a['id'].toString().contains(trimmed) ||
                  (a['applicant_name']?.toString().toLowerCase().contains(trimmed) ?? false) ||
                  (a['department_name']?.toString().toLowerCase().contains(trimmed) ?? false) ||
                  (a['factory_name']?.toString().toLowerCase().contains(trimmed) ?? false);
            }).toList();
    });
  }

  void _setFilter(String f) {
    setState(() => _statusFilter = f);
    _filter(_searchCtrl.text);
  }

  Future<void> _onSign(Map<String, dynamic> app) async {
    final s = S.of(context);
    final ok = await _dialog(
      icon: Icons.draw_rounded,
      iconColor: Colors.green.shade600,
      title: s.approveConfirmTitle,
      message: s.approveConfirmDesc,
      confirmLabel: s.approve,
      confirmColor: Colors.green.shade600,
    );
    if (!ok) return;
    await _process(app, 'sign');
  }

  Future<void> _onReject(Map<String, dynamic> app) async {
    final s = S.of(context);
    final ok = await _dialog(
      icon: Icons.cancel_rounded,
      iconColor: Colors.red.shade600,
      title: s.rejectConfirmTitle,
      message: s.rejectConfirmDesc,
      confirmLabel: s.reject,
      confirmColor: Colors.red.shade600,
    );
    if (!ok) return;
    await _process(app, 'reject');
  }

  Future<void> _process(Map<String, dynamic> app, String action) async {
    final s = S.of(context);
    final id = app['id'];
    setState(() => app['_busy'] = true);
    try {
      final detResp = await http
          .get(Uri.parse('$API/$_kPath/$id/'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (detResp.statusCode != 200) {
        _snack(s.loadDataError, false);
        setState(() => app['_busy'] = false);
        return;
      }
      final detBody = json.decode(utf8.decode(detResp.bodyBytes));
      final details = ((detBody['data'] ?? detBody)['details'] as List? ?? []);
      final ids = details
          .where((d) => d['status'] == 0 || d['status'] == 1)
          .map((d) => d['id'])
          .toList();

      if (ids.isEmpty) {
        _snack(s.signRequestsEmpty, false);
        setState(() => app['_busy'] = false);
        return;
      }

      final patchUri = action == 'reject'
          ? Uri.parse('$API/$_kPath/$id/reject/')
          : Uri.parse('$API/$_kPath/$id/');
      final patchResp = await http
          .patch(patchUri, headers: _headers, body: json.encode({'signed_details': ids}))
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (patchResp.statusCode == 200 || patchResp.statusCode == 201) {
        _snack(action == 'reject' ? s.rejectSuccess : s.approveSuccess, true);
        _memCache = null;
        _memCacheTime = null;
        await _load(forceRefresh: true);
      } else {
        _snack(s.signError, false);
        setState(() => app['_busy'] = false);
      }
    } catch (_) {
      if (!mounted) return;
      _snack(S.of(context).connectionError, false);
      setState(() => app['_busy'] = false);
    }
  }

  Future<bool> _dialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final s = S.of(context);
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
                    color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 30),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: onSurface)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: onSurface.withOpacity(0.6))),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: onSurface.withOpacity(0.2)),
                      ),
                      child: Text(s.cancel,
                          style: TextStyle(
                              color: onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(confirmLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.error, color: Colors.white, size: 16),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
      backgroundColor: ok ? const Color(0xFF43A047) : const Color(0xFFD32F2F),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ));
  }

  int get _pendingCount => _all.where((a) => a['status'] == 0).length;
  int get _signingCount => _all.where((a) => a['status'] == 1).length;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
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
          title: Text(s.signRequestsTitle,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
                        valueColor: AlwaysStoppedAnimation(Colors.white70)),
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: _isLoading ? null : () => _load(forceRefresh: true),
              ),
          ],
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
        ),
        body: Column(
          children: [
            // Gradient header — count badge
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                  child: Row(
                    children: [
                      const Spacer(),
                      if (!_isLoading && _error == null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.35)),
                          ),
                          child: Text('${_shown.length}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Search bar
            Container(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: _SearchBar(
                controller: _searchCtrl,
                isDark: isDark,
              ),
            ),
            // Filter chips
            if (!_isLoading && _error == null)
              Container(
                color: isDark
                    ? Theme.of(context).colorScheme.surface
                    : const Color(0xFFF4F4F4),
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: _FilterBar(
                  selected: _statusFilter,
                  allCount: _all.length,
                  pendingCount: _pendingCount,
                  signingCount: _signingCount,
                  isDark: isDark,
                  onSelect: _setFilter,
                ),
              ),
            // List
            Expanded(
              child: Container(
                color: isDark
                    ? Theme.of(context).colorScheme.surface
                    : const Color(0xFFF4F4F4),
                child: _buildBody(s, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(S s, bool isDark) {
    if (_isLoading) return _shimmer(isDark);

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 56,
                  color: isDark ? Colors.white54 : Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                      fontSize: 14)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _load(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(s.refresh),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _g1,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
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
                color: isDark ? Colors.white12 : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox_rounded,
                  size: 40,
                  color: isDark ? Colors.white54 : Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text(s.signRequestsEmpty,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey.shade700)),
            const SizedBox(height: 6),
            Text(s.signRequestsEmptyDesc,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.grey.shade500)),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: RefreshIndicator(
        onRefresh: () => _load(forceRefresh: true),
        color: _g1,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: _shown.length,
          itemBuilder: (_, i) => _AppCard(
            app: _shown[i],
            isDark: isDark,
            onSign: () => _onSign(_shown[i]),
            onReject: () => _onReject(_shown[i]),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SignRequestDetailPage(
                  appId: _shown[i]['id'] as int,
                  jwtToken: widget.jwtToken,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _shimmer(bool isDark) {
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final highlight = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
                color: base, borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;

  const _SearchBar({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.07) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade200),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: onSurface, fontSize: 14),
        decoration: InputDecoration(
          hintText: S.of(context).searchHintSignRequests,
          hintStyle:
              TextStyle(color: onSurface.withOpacity(0.38), fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded,
              color: onSurface.withOpacity(0.38), size: 20),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, __) => v.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: Icon(Icons.clear_rounded,
                        size: 18, color: onSurface.withOpacity(0.4)),
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

// ─── Filter bar ───────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final String selected;
  final int allCount;
  final int pendingCount;
  final int signingCount;
  final bool isDark;
  final void Function(String) onSelect;

  const _FilterBar({
    required this.selected,
    required this.allCount,
    required this.pendingCount,
    required this.signingCount,
    required this.isDark,
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
          _chip(context, 'all', S.of(context).filterAll, allCount),
          const SizedBox(width: 6),
          _chip(context, 'pending', S.of(context).pending, pendingCount,
              color: const Color(0xFFF59E0B)),
          const SizedBox(width: 6),
          _chip(context, 'signing', S.of(context).filterForSigning, signingCount,
              color: const Color(0xFF3B82F6)),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String value, String label, int count,
      {Color? color}) {
    final isSelected = selected == value;
    final chipColor = color ?? const Color(0xFFFF8C00);
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withOpacity(isDark ? 0.25 : 0.12)
              : (isDark ? Colors.white.withOpacity(0.07) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? chipColor.withOpacity(isDark ? 0.6 : 0.5)
                : (isDark ? Colors.white24 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? chipColor
                    : (isDark ? Colors.white60 : Colors.grey.shade600),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? chipColor.withOpacity(isDark ? 0.3 : 0.15)
                      : (isDark ? Colors.white12 : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? chipColor
                        : (isDark
                            ? Colors.white54
                            : Colors.grey.shade500),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Info row (label + value) ─────────────────────────────────────────────────
class _Row2 extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color onSurface;

  const _Row2({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: onSurface.withOpacity(0.45),
                      letterSpacing: 0.2)),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── App card ─────────────────────────────────────────────────────────────────
class _AppCard extends StatelessWidget {
  static const Color _g1 = Color(0xFFFF8C00);

  final Map<String, dynamic> app;
  final bool isDark;
  final VoidCallback onSign;
  final VoidCallback onReject;
  final VoidCallback? onTap;

  const _AppCard({
    required this.app,
    required this.isDark,
    required this.onSign,
    required this.onReject,
    this.onTap,
  });

  bool get _busy => app['_busy'] == true;

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

    final id = app['id']?.toString() ?? '—';
    final applicant = app['applicant_name'] ?? '—';
    final dept = app['department_name'] ?? '—';
    final factory = app['factory_name'] ?? '—';
    final arriving = _fmt(app['arriving_date']?.toString());
    final notes = app['notes']?.toString() ?? '';
    final statusTitle = app['status_title'] ?? '—';
    final status = app['status'] as int? ?? 0;

    final statusColor =
        status == 1 ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B);
    final statusIcon = status == 1
        ? Icons.pending_rounded
        : Icons.hourglass_empty_rounded;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: statusColor, width: 4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.22 : 0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: icon + id + status badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _g1.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.assignment_rounded,
                          color: _g1, size: 15),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Заявка №$id',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: statusColor.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 10, color: statusColor),
                          const SizedBox(width: 3),
                          Text(statusTitle,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _Row2(
                  icon: Icons.person_outline_rounded,
                  iconColor: const Color(0xFF6366F1),
                  label: S.of(context).requestApplicant,
                  value: applicant,
                  onSurface: onSurface,
                ),
                const SizedBox(height: 6),
                _Row2(
                  icon: Icons.domain_rounded,
                  iconColor: const Color(0xFF0EA5E9),
                  label: S.of(context).requestDepartment,
                  value: dept,
                  onSurface: onSurface,
                ),
                const SizedBox(height: 6),
                _Row2(
                  icon: Icons.factory_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  label: S.of(context).factoryLabel2,
                  value: factory,
                  onSurface: onSurface,
                ),
                const SizedBox(height: 6),
                _Row2(
                  icon: Icons.event_rounded,
                  iconColor: const Color(0xFF10B981),
                  label: S.of(context).arrivalDate,
                  value: arriving,
                  onSurface: onSurface,
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.amber.withOpacity(0.1)
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isDark
                              ? Colors.amber.withOpacity(0.25)
                              : Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes_rounded,
                            size: 13, color: Colors.amber.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            notes,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: isDark
                                  ? Colors.amber.shade200
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Divider(
                    height: 1,
                    color: theme.colorScheme.outline.withOpacity(0.4)),
                const SizedBox(height: 8),
                if (_busy)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(
                                Color(0xFFFF8C00))),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _ActionBtn(
                          label: S.of(context).reject,
                          icon: Icons.close_rounded,
                          color: const Color(0xFFEF4444),
                          bgColor: const Color(0xFFFEF2F2),
                          isDark: isDark,
                          onTap: onReject,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionBtn(
                          label: S.of(context).approve,
                          icon: Icons.draw_rounded,
                          color: const Color(0xFF22C55E),
                          bgColor: const Color(0xFFF0FDF4),
                          isDark: isDark,
                          onTap: onSign,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 6),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.list_alt_rounded,
                          size: 11,
                          color: onSurface.withOpacity(0.28)),
                      const SizedBox(width: 4),
                      Text(
                        S.of(context).tapToViewMaterials,
                        style: TextStyle(
                            fontSize: 10,
                            color: onSurface.withOpacity(0.32)),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded,
                          size: 13,
                          color: onSurface.withOpacity(0.28)),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),
        ),
      ),
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? color.withOpacity(0.15) : bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: color.withOpacity(isDark ? 0.4 : 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
