import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uztexpro_payment/main.dart';
import 'app_strings.dart';
import 'locale_notifier.dart';

// GET  $API/texmansys/material-purchase-application/?limit=1000
// GET  $API/texmansys/material-purchase-application/{id}/        → full detail
// PATCH $API/texmansys/material-purchase-application/{id}/         sign   {signed_details:[...]}
// PATCH $API/texmansys/material-purchase-application/{id}/reject/  reject {signed_details:[...]}
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

  List<dynamic> _all = [];
  List<dynamic> _shown = [];
  bool _isLoading = true;
  String? _error;

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
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
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

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uri =
          Uri.parse('$API/$_kPath/?limit=1000');
      final resp = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final body = json.decode(utf8.decode(resp.bodyBytes));
        final List raw =
            body is List ? body : (body['results'] ?? body['data'] ?? []);
        // Show only applications that need signing (status 0 or 1)
        _all = raw.where((a) => a['status'] == 0 || a['status'] == 1).toList();
        _filter(_searchCtrl.text);
        setState(() => _isLoading = false);
        _animCtrl.forward(from: 0);
      } else {
        setState(() {
          _error =
              '${S.of(context).loadDataError} (${resp.statusCode})';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = S.of(context).connectionError;
        _isLoading = false;
      });
    }
  }

  void _filter(String q) {
    final trimmed = q.trim();
    setState(() {
      _shown = trimmed.isEmpty
          ? List.from(_all)
          : _all
              .where((a) =>
                  a['id'].toString().contains(trimmed))
              .toList();
    });
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
      // Fetch full detail to get pending detail IDs
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
      final details =
          ((detBody['data'] ?? detBody)['details'] as List? ?? []);
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
          .patch(patchUri,
              headers: _headers,
              body: json.encode({'signed_details': ids}))
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (patchResp.statusCode == 200 || patchResp.statusCode == 201) {
        _snack(
          action == 'reject' ? s.rejectSuccess : s.approveSuccess,
          true,
        );
        await _load();
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 30),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: onSurface)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: onSurface.withOpacity(0.6))),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(
                            color: onSurface.withOpacity(0.2)),
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
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(confirmLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
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
          Icon(ok ? Icons.check_circle : Icons.error,
              color: Colors.white, size: 16),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
      backgroundColor:
          ok ? const Color(0xFF43A047) : const Color(0xFFD32F2F),
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ));
  }

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
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _isLoading ? null : _load,
            ),
          ],
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20)),
            ),
          ),
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
        ),
        body: Stack(
          children: [
            // Gradient header background
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
            ),
            // White/surface body
            Positioned.fill(
              top: 120,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Theme.of(context).colorScheme.surface
                      : const Color(0xFFF5F5F5),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24)),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SearchBar(
                      controller: _searchCtrl,
                      hintText: s.requestNumber,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Counter chip
                  if (!_isLoading && _error == null)
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 16, bottom: 8),
                      child: Row(
                        children: [
                          _CountChip(
                            count: _shown.length,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  Expanded(child: _buildBody(s, isDark, gradientColors)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
      S s, bool isDark, List<Color> gradientColors) {
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
                  color: isDark
                      ? Colors.white54
                      : Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: isDark
                          ? Colors.white70
                          : Colors.grey.shade600,
                      fontSize: 14)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _load,
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
                color: isDark
                    ? Colors.white12
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox_rounded,
                  size: 40,
                  color: isDark
                      ? Colors.white54
                      : Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text(s.signRequestsEmpty,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? Colors.white
                        : Colors.grey.shade700)),
            const SizedBox(height: 6),
            Text(s.signRequestsEmptyDesc,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? Colors.white54
                        : Colors.grey.shade500)),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: RefreshIndicator(
        onRefresh: _load,
        color: _g1,
        child: ListView.builder(
          padding:
              const EdgeInsets.fromLTRB(16, 4, 16, 32),
          itemCount: _shown.length,
          itemBuilder: (_, i) => _AppCard(
            app: _shown[i],
            isDark: isDark,
            gradientColors: gradientColors,
            onSign: () => _onSign(_shown[i]),
            onReject: () => _onReject(_shown[i]),
          ),
        ),
      ),
    );
  }

  Widget _shimmer(bool isDark) {
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final highlight =
        isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: Container(
            height: 180,
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

// ─────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  const _SearchBar(
      {required this.controller, required this.hintText});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.12)
            : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.grey.shade800,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: '${hintText}...',
          hintStyle: TextStyle(
            color: isDark
                ? Colors.white38
                : Colors.grey.shade400,
            fontSize: 14,
          ),
          prefixIcon: Icon(Icons.search_rounded,
              color: isDark ? Colors.white54 : Colors.grey.shade400,
              size: 20),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, __) => v.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: Icon(Icons.clear_rounded,
                        size: 18,
                        color: isDark
                            ? Colors.white54
                            : Colors.grey.shade400),
                    onPressed: controller.clear,
                  ),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final int count;
  final bool isDark;
  const _CountChip({required this.count, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white12
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark
                ? Colors.white24
                : Colors.orange.shade200),
      ),
      child: Text(
        'Заявок: $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark
              ? Colors.white70
              : Colors.orange.shade800,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
class _AppCard extends StatelessWidget {
  final Map<String, dynamic> app;
  final bool isDark;
  final List<Color> gradientColors;
  final VoidCallback onSign;
  final VoidCallback onReject;

  const _AppCard({
    required this.app,
    required this.isDark,
    required this.gradientColors,
    required this.onSign,
    required this.onReject,
  });

  bool get _busy => app['_busy'] == true;

  IconData get _statusIcon =>
      app['status'] == 1 ? Icons.remove_done_rounded : Icons.hourglass_empty_rounded;

  String _fmt(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      return DateFormat('dd.MM.yyyy')
          .format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final cardBg = isDark
        ? theme.colorScheme.surface
        : Colors.white;
    final outline = theme.colorScheme.outline;

    final id = app['id']?.toString() ?? '—';
    final applicant =
        app['applicant_name'] ?? '—';
    final dept = app['department_name'] ?? '—';
    final factory = app['factory_name'] ?? '—';
    final arriving = _fmt(app['arriving_date']?.toString());
    final notes = app['notes']?.toString() ?? '';
    final statusTitle = app['status_title'] ?? '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gradient header ──
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
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
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon,
                          color: Colors.white, size: 12),
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Заявитель',
                  value: applicant,
                  isDark: isDark,
                  onSurface: onSurface,
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.domain_rounded,
                  label: 'Отдел',
                  value: dept,
                  isDark: isDark,
                  onSurface: onSurface,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _InfoRow(
                        icon: Icons.factory_outlined,
                        label: 'Фабрика',
                        value: factory,
                        isDark: isDark,
                        onSurface: onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InfoRow(
                        icon: Icons.calendar_today_rounded,
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
                        horizontal: 10, vertical: 8),
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
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes_rounded,
                            size: 14,
                            color: Colors.amber.shade700),
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
                Divider(height: 1, color: outline),
                const SizedBox(height: 10),
                // ── Action buttons ──
                if (_busy)
                  const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(
                              Color(0xFFFF8C00))),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color onSurface;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 14,
            color: onSurface.withOpacity(0.4)),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurface.withOpacity(0.5),
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

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
            color: isDark
                ? color.withOpacity(0.15)
                : bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: color.withOpacity(isDark ? 0.4 : 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
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
