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

  static List<dynamic>? _memCache;
  static DateTime? _memCacheTime;
  static const Duration _kCacheTTL = Duration(minutes: 5);

  List<dynamic> _shown = [];
  bool _isLoading = true;
  bool _refreshing = false;
  String? _error;

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
    _load();
    localeNotifier.addListener(_onLocale);
  }

  void _onLocale() => setState(() {});

  @override
  void dispose() {
    _animCtrl.dispose();
    localeNotifier.removeListener(_onLocale);
    super.dispose();
  }

  List<dynamic> _filterPending(List<dynamic> raw) => raw
      .where((e) =>
          e['is_change'] == true && (e['status'] as int? ?? 0) != 4)
      .toList();

  Future<void> _load({bool forceRefresh = false}) async {
    // Show memory cache instantly on repeat opens
    if (!forceRefresh && _memCache != null) {
      setState(() {
        _shown = _memCache!;
        _isLoading = false;
        _refreshing = false;
      });
      _animCtrl.forward(from: 0);
      // Background refresh if TTL expired
      if (_memCacheTime != null &&
          DateTime.now().difference(_memCacheTime!) < _kCacheTTL) return;
    } else {
      setState(() {
        _isLoading = _memCache == null;
        _error = null;
        _refreshing = false;
      });
    }

    try {
      final resp = await http
          .get(Uri.parse('$API/$_kBonusPath/?limit=500'), headers: _headers)
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final bodyBytes = resp.bodyBytes;
        final List raw = await Future(() {
          final body = json.decode(utf8.decode(bodyBytes));
          return body is List ? body : (body['results'] ?? body['data'] ?? []);
        });
        final pending = _filterPending(raw);
        _memCache = pending;
        _memCacheTime = DateTime.now();
        setState(() {
          _shown = pending;
          _isLoading = false;
        });
        _animCtrl.forward(from: 0);
      } else {
        if (_shown.isEmpty) {
          setState(() {
            _error = '${S.of(context).loadDataError} (${resp.statusCode})';
            _isLoading = false;
          });
        }
      }
    } on TimeoutException {
      if (!mounted) return;
      if (_shown.isEmpty) {
        setState(() {
          _error = S.of(context).timeoutError;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (_shown.isEmpty) {
        setState(() {
          _error = S.of(context).connectionError;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onApprove(Map<String, dynamic> item) async {
    final s = S.of(context);
    final ok = await _confirmDialog(
      icon: Icons.check_circle_rounded,
      iconColor: Colors.green.shade600,
      title: s.bonusApproveTitle,
      message: s.bonusApproveDesc,
      confirmLabel: s.bonusApproveBtn,
      confirmColor: Colors.green.shade600,
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
        await _load(forceRefresh: true);
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
    final s = S.of(context);
    final ok = await _confirmDialog(
      icon: Icons.delete_rounded,
      iconColor: Colors.red.shade600,
      title: s.bonusDeleteTitle,
      message: s.bonusDeleteDesc,
      confirmLabel: s.deleteBtn,
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
        await _load(forceRefresh: true);
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

  Future<bool> _confirmDialog({
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
                      fontSize: 13, color: onSurface.withOpacity(0.6))),
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                  style:
                      const TextStyle(fontWeight: FontWeight.w500))),
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
          title: Text(S.of(context).bonusesTitle,
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
              icon: _refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white70)),
                    )
                  : const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: (_isLoading || _refreshing)
                  ? null
                  : () => _load(forceRefresh: true),
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
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
            ),
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
                  if (!_isLoading && _error == null)
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 16, bottom: 8),
                      child: Row(
                        children: [
                          _CountChip(
                              count: _shown.length, isDark: isDark),
                        ],
                      ),
                    ),
                  Expanded(
                      child: _buildBody(isDark, gradientColors)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark, List<Color> gradientColors) {
    final s = S.of(context);

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
                  color:
                      isDark ? Colors.white54 : Colors.grey.shade400),
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
                color: isDark
                    ? Colors.white12
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.card_giftcard_rounded,
                  size: 40,
                  color: isDark
                      ? Colors.white54
                      : Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text(s.noData,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? Colors.white
                        : Colors.grey.shade700)),
            const SizedBox(height: 6),
            Text(s.bonusesEmpty,
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
        onRefresh: () => _load(forceRefresh: true),
        color: _g1,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          itemCount: _shown.length,
          itemBuilder: (_, i) => _BonusCard(
            item: _shown[i],
            isDark: isDark,
            gradientColors: gradientColors,
            onApprove: () => _onApprove(_shown[i]),
            onDelete: () => _onDelete(_shown[i]),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BonusDetailPage(
                    item: _shown[i] as Map<String, dynamic>),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _shimmer(bool isDark) {
    final base =
        isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final highlight =
        isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: Container(
            height: 210,
            decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(16)),
          ),
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
        color: isDark ? Colors.white12 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark
                ? Colors.white24
                : Colors.orange.shade200),
      ),
      child: Text(
        '${S.of(context).recordsCount}: $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color:
              isDark ? Colors.white70 : Colors.orange.shade800,
        ),
      ),
    );
  }
}

class _BonusCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDark;
  final List<Color> gradientColors;
  final VoidCallback onApprove;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _BonusCard({
    required this.item,
    required this.isDark,
    required this.gradientColors,
    required this.onApprove,
    required this.onDelete,
    required this.onTap,
  });

  bool get _busy => item['_busy'] == true;

  Color _statusColor(int status) {
    switch (status) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.green;
      case 4:
        return Colors.purple;
      case 5:
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final cardBg =
        isDark ? theme.colorScheme.surface : Colors.white;
    final outline = theme.colorScheme.outline;

    final id = item['id']?.toString() ?? '—';
    final factory = item['factory_name'] ?? '—';
    final month = item['month_text'] ?? '—';
    final status = item['status'] as int? ?? 0;
    final statusText = item['status_text'] ?? '—';
    final creator = item['create_by_name'] ?? '—';
    final totalBonus = item['total_bonus']?.toString() ?? '—';
    final createdAt = item['created_at'] ?? '—';
    final approveBy = item['approve_by']?.toString() ?? '';
    final confirmBy = item['confirm_by']?.toString() ?? '';
    final notes = item['notes']?.toString() ?? '';
    final isChange = item['is_change'] == true && status != 4;
    final isDelete = item['is_delete'] == true;
    final statusColor = _statusColor(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(isDark ? 0.25 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient header
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
                  child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: Colors.white,
                      size: 15),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${S.of(context).bonusNumber}$id',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.4)),
                  ),
                  child: Text(statusText,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding:
                const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _InfoRow(
                          icon: Icons.factory_outlined,
                          label: S.of(context).factoryLabel,
                          value: factory,
                          isDark: isDark,
                          onSurface: onSurface),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InfoRow(
                          icon: Icons.calendar_month_rounded,
                          label: S.of(context).monthLabel,
                          value: month,
                          isDark: isDark,
                          onSurface: onSurface),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _InfoRow(
                          icon: Icons.person_outline_rounded,
                          label: S.of(context).createdByLabel,
                          value: creator,
                          isDark: isDark,
                          onSurface: onSurface),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InfoRow(
                          icon: Icons.access_time_rounded,
                          label: S.of(context).dateLabel,
                          value: createdAt,
                          isDark: isDark,
                          onSurface: onSurface),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.payments_outlined,
                  label: S.of(context).totalLabel,
                  value: '$totalBonus UZS',
                  isDark: isDark,
                  onSurface: onSurface,
                  highlight: true,
                ),
                if (approveBy.isNotEmpty &&
                    approveBy != ' ') ...[
                  const SizedBox(height: 6),
                  _InfoRow(
                      icon: Icons.approval_rounded,
                      label: S.of(context).approvedByLabel,
                      value: approveBy,
                      isDark: isDark,
                      onSurface: onSurface),
                ],
                if (confirmBy.isNotEmpty &&
                    confirmBy != ' ') ...[
                  const SizedBox(height: 6),
                  _InfoRow(
                      icon: Icons.verified_rounded,
                      label: S.of(context).confirmedByLabel,
                      value: confirmBy,
                      isDark: isDark,
                      onSurface: onSurface),
                ],
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
                if (isChange || isDelete) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: outline),
                  const SizedBox(height: 10),
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
                        if (isDelete) ...[
                          Expanded(
                            child: _ActionBtn(
                              label: S.of(context).deleteBtn,
                              icon: Icons
                                  .delete_outline_rounded,
                              color: const Color(0xFFEF4444),
                              bgColor:
                                  const Color(0xFFFEF2F2),
                              isDark: isDark,
                              onTap: onDelete,
                            ),
                          ),
                          if (isChange)
                            const SizedBox(width: 10),
                        ],
                        if (isChange)
                          Expanded(
                            child: _ActionBtn(
                              label: S.of(context).bonusApproveBtn,
                              icon: Icons
                                  .check_circle_outline_rounded,
                              color: const Color(0xFF22C55E),
                              bgColor:
                                  const Color(0xFFF0FDF4),
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
        ],
      ),
    ),  // GestureDetector
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color onSurface;
  final bool highlight;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    required this.onSurface,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 14,
            color: highlight
                ? const Color(0xFFFF8C00)
                : onSurface.withOpacity(0.4)),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                      fontSize: 12,
                      color: onSurface.withOpacity(0.5)),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: highlight
                        ? FontWeight.bold
                        : FontWeight.w600,
                    color: highlight
                        ? const Color(0xFFFF8C00)
                        : onSurface,
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
            color: isDark ? color.withOpacity(0.15) : bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color:
                    color.withOpacity(isDark ? 0.4 : 0.3)),
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
