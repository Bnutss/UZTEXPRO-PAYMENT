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

  // 'all' | 'pending' (0) | 'signing' (1)
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
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(s.signRequestsTitle,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (_refreshing)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white70)),
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
        body: Stack(
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
            ),
            Positioned.fill(
              top: 140,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Theme.of(context).colorScheme.surface
                      : const Color(0xFFF2F3F7),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SearchBar(
                      controller: _searchCtrl,
                      isDark: isDark,
                      hint: s.requestNumber,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Filter chips
                  if (!_isLoading && _error == null)
                    _FilterBar(
                      selected: _statusFilter,
                      allCount: _all.length,
                      pendingCount: _pendingCount,
                      signingCount: _signingCount,
                      shownCount: _shown.length,
                      isDark: isDark,
                      onSelect: _setFilter,
                    ),
                  const SizedBox(height: 4),
                  Expanded(child: _buildBody(s, isDark, gradientColors)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(S s, bool isDark, List<Color> gradientColors) {
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          itemCount: _shown.length,
          itemBuilder: (_, i) => _AppCard(
            app: _shown[i],
            isDark: isDark,
            gradientColors: gradientColors,
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: Container(
            height: 195,
            decoration:
                BoxDecoration(color: base, borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────
class _SearchBar extends StatefulWidget {
  final TextEditingController controller;
  final bool isDark;
  final String hint;

  const _SearchBar(
      {required this.controller, required this.isDark, required this.hint});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar>
    with SingleTickerProviderStateMixin {
  static const Color _orange = Color(0xFFFF8C00);

  late final FocusNode _focus;
  late final AnimationController _glowCtrl;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _glow = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOut);
    _focus.addListener(() {
      if (_focus.hasFocus) {
        _glowCtrl.forward();
      } else {
        _glowCtrl.reverse();
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) {
        final focused = _glow.value;
        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: isDark
                ? Color.lerp(
                    Colors.white.withOpacity(0.10),
                    Colors.white.withOpacity(0.16),
                    focused)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Color.lerp(Colors.white.withOpacity(0.12),
                      _orange.withOpacity(0.7), focused)!
                  : Color.lerp(Colors.transparent,
                      _orange.withOpacity(0.6), focused)!,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
              if (focused > 0)
                BoxShadow(
                  color: _orange.withOpacity(0.22 * focused),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.grey.shade800,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Поиск по заявке, заявителю, отделу...',
              hintStyle: TextStyle(
                color: isDark
                    ? Colors.white.withOpacity(0.35)
                    : Colors.grey.shade400,
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(13),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: focused > 0.5
                        ? _orange.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    color: isDark
                        ? Color.lerp(Colors.white54, _orange, focused)
                        : Color.lerp(
                            Colors.grey.shade400, _orange, focused),
                    size: 20,
                  ),
                ),
              ),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (_, v, __) => v.text.isEmpty
                    ? const SizedBox.shrink()
                    : GestureDetector(
                        onTap: widget.controller.clear,
                        child: Container(
                          margin: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.12)
                                : Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: isDark
                                ? Colors.white60
                                : Colors.grey.shade500,
                          ),
                        ),
                      ),
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            ),
          ),
        );
      },
    );
  }
}

// ─── Filter bar ───────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final String selected;
  final int allCount;
  final int pendingCount;
  final int signingCount;
  final int shownCount;
  final bool isDark;
  final void Function(String) onSelect;

  const _FilterBar({
    required this.selected,
    required this.allCount,
    required this.pendingCount,
    required this.signingCount,
    required this.shownCount,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _chip(context, 'all', 'Все', allCount),
          const SizedBox(width: 8),
          _chip(context, 'pending', 'Ожидает', pendingCount),
          const SizedBox(width: 8),
          _chip(context, 'signing', 'На подписи', signingCount),
          const Spacer(),
          if (shownCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isDark ? Colors.white24 : Colors.orange.shade200),
              ),
              child: Text(
                '$shownCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.orange.shade800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String value, String label, int count) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFFF8C00), Color(0xFFCC1500)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? Colors.white12 : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? null
              : Border.all(
                  color: isDark ? Colors.white24 : Colors.grey.shade300),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF8C00).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white60 : Colors.grey.shade600),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.25)
                      : (isDark
                          ? Colors.white12
                          : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white54 : Colors.grey.shade500),
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

// ─── App Card ─────────────────────────────────────────────────────────────────
class _AppCard extends StatelessWidget {
  final Map<String, dynamic> app;
  final bool isDark;
  final List<Color> gradientColors;
  final VoidCallback onSign;
  final VoidCallback onReject;
  final VoidCallback? onTap;

  const _AppCard({
    required this.app,
    required this.isDark,
    required this.gradientColors,
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
    final cardBg = isDark ? theme.colorScheme.surface : Colors.white;
    final outline = theme.colorScheme.outline;

    final id = app['id']?.toString() ?? '—';
    final applicant = app['applicant_name'] ?? '—';
    final dept = app['department_name'] ?? '—';
    final factory = app['factory_name'] ?? '—';
    final arriving = _fmt(app['arriving_date']?.toString());
    final notes = app['notes']?.toString() ?? '';
    final statusTitle = app['status_title'] ?? '—';
    final status = app['status'] as int? ?? 0;

    final statusColor = status == 1 ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B);
    final statusIcon = status == 1 ? Icons.pending_rounded : Icons.hourglass_empty_rounded;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.22 : 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Gradient header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.assignment_rounded,
                        color: Colors.white, size: 15),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Заявка №$id',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: Colors.white, size: 11),
                        const SizedBox(width: 4),
                        Text(statusTitle,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── Body ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заявитель + Отдел
                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.person_outline_rounded,
                          iconColor: const Color(0xFF6366F1),
                          label: 'Заявитель',
                          value: applicant,
                          isDark: isDark,
                          onSurface: onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.domain_rounded,
                          iconColor: const Color(0xFF0EA5E9),
                          label: 'Отдел',
                          value: dept,
                          isDark: isDark,
                          onSurface: onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Фабрика + Дата
                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.factory_outlined,
                          iconColor: const Color(0xFFF59E0B),
                          label: 'Фабрика',
                          value: factory,
                          isDark: isDark,
                          onSurface: onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.event_rounded,
                          iconColor: const Color(0xFF10B981),
                          label: 'Дата',
                          value: arriving,
                          isDark: isDark,
                          onSurface: onSurface,
                        ),
                      ),
                    ],
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
                  const SizedBox(height: 12),
                  Divider(height: 1, color: outline.withOpacity(0.5)),
                  const SizedBox(height: 10),
                  // ── Action buttons ──
                  if (_busy)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation(Color(0xFFFF8C00))),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _ActionBtn(
                            label: 'Отклонить',
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
                            label: 'Подписать',
                            icon: Icons.draw_rounded,
                            color: const Color(0xFF22C55E),
                            bgColor: const Color(0xFFF0FDF4),
                            isDark: isDark,
                            onTap: onSign,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.list_alt_rounded,
                            size: 11,
                            color: onSurface.withOpacity(0.28)),
                        const SizedBox(width: 4),
                        Text(
                          'Нажмите для просмотра материалов',
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
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Info tile ────────────────────────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isDark;
  final Color onSurface;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isDark,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? iconColor.withOpacity(0.08)
            : iconColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: iconColor.withOpacity(isDark ? 0.2 : 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: onSurface.withOpacity(0.45))),
                const SizedBox(height: 1),
                Text(value,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
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
            border:
                Border.all(color: color.withOpacity(isDark ? 0.4 : 0.3)),
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
