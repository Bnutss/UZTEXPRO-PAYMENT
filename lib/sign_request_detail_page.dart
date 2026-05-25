import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uztexpro_payment/main.dart';
import 'app_strings.dart';
import 'locale_notifier.dart';

const _kDetailPath = 'texmansys/material-purchase-application';

class SignRequestDetailPage extends StatefulWidget {
  final int appId;
  final String jwtToken;

  const SignRequestDetailPage({
    Key? key,
    required this.appId,
    required this.jwtToken,
  }) : super(key: key);

  @override
  _SignRequestDetailPageState createState() => _SignRequestDetailPageState();
}

class _SignRequestDetailPageState extends State<SignRequestDetailPage> {
  static const Color _g1 = Color(0xFFFF8C00);
  static const Color _g2 = Color(0xFFCC1500);

  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;
  bool _busy = false;

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
    _load();
    localeNotifier.addListener(_onLocale);
  }

  void _onLocale() => setState(() {});

  @override
  void dispose() {
    localeNotifier.removeListener(_onLocale);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final resp = await http
          .get(
            Uri.parse('$API/$_kDetailPath/${widget.appId}/'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final body = json.decode(utf8.decode(resp.bodyBytes));
        setState(() {
          _data = body['data'] ?? body;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = '${S.of(context).loadDataError} (${resp.statusCode})';
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

  List<dynamic> get _pendingDetails {
    if (_data == null) return [];
    return (_data!['details'] as List? ?? [])
        .where((d) => d['status'] == 0 || d['status'] == 1)
        .toList();
  }

  Future<void> _onSign() async {
    final s = S.of(context);
    final ok = await _confirmDialog(
      icon: Icons.draw_rounded,
      iconColor: Colors.green.shade600,
      title: s.approveConfirmTitle,
      message: s.approveConfirmDesc,
      confirmLabel: s.signAll,
      confirmColor: Colors.green.shade600,
    );
    if (!ok) return;
    await _process('sign');
  }

  Future<void> _onReject() async {
    final s = S.of(context);
    final ok = await _confirmDialog(
      icon: Icons.cancel_rounded,
      iconColor: Colors.red.shade600,
      title: s.rejectConfirmTitle,
      message: s.rejectConfirmDesc,
      confirmLabel: s.rejectAll,
      confirmColor: Colors.red.shade600,
    );
    if (!ok) return;
    await _process('reject');
  }

  Future<void> _process(String action) async {
    final s = S.of(context);
    final ids = _pendingDetails.map((d) => d['id']).toList();
    if (ids.isEmpty) {
      _snack(s.signRequestsEmpty, false);
      return;
    }
    setState(() => _busy = true);
    try {
      final uri = action == 'reject'
          ? Uri.parse('$API/$_kDetailPath/${widget.appId}/reject/')
          : Uri.parse('$API/$_kDetailPath/${widget.appId}/');
      final resp = await http
          .patch(uri,
              headers: _headers,
              body: json.encode({'signed_details': ids}))
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        _snack(action == 'reject' ? s.rejectSuccess : s.approveSuccess, true);
        await _load();
      } else {
        _snack(s.signError, false);
        setState(() => _busy = false);
      }
    } catch (_) {
      if (!mounted) return;
      _snack(S.of(context).connectionError, false);
      setState(() => _busy = false);
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
                  style:
                      const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
      backgroundColor:
          ok ? const Color(0xFF43A047) : const Color(0xFFD32F2F),
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? [const Color(0xFF3D1800), const Color(0xFF1F0000)]
        : [_g1, _g2];

    final hasPending =
        !_isLoading && _error == null && _pendingDetails.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            '${s.requestNumber}${widget.appId}',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18),
          ),
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
        bottomNavigationBar: hasPending ? _buildBottomBar(s, isDark) : null,
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
                      : const Color(0xFFF0F2F5),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24)),
                ),
              ),
            ),
            SafeArea(
              child: _isLoading
                  ? _buildShimmer(isDark)
                  : _error != null
                      ? _buildError(s, isDark)
                      : _buildContent(s, isDark, gradientColors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer(bool isDark) {
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlight =
        isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
                color: base, borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          4,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Shimmer.fromColors(
              baseColor: base,
              highlightColor: highlight,
              child: Container(
                height: 88,
                decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(S s, bool isDark) {
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

  Widget _buildContent(
      S s, bool isDark, List<Color> gradientColors) {
    final data = _data!;
    final details = data['details'] as List? ?? [];
    final pendingCount =
        details.where((d) => d['status'] == 0 || d['status'] == 1).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _InfoCard(
            data: data, isDark: isDark, gradientColors: gradientColors),
        const SizedBox(height: 16),
        // Materials header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _g1.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.inventory_2_outlined, color: _g1, size: 17),
            ),
            const SizedBox(width: 10),
            Text(
              s.materials,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey.shade800),
            ),
            const SizedBox(width: 8),
            _CountBadge(
                count: details.length,
                label: 'позиций',
                color: _g1,
                isDark: isDark),
            if (pendingCount > 0) ...[
              const SizedBox(width: 6),
              _CountBadge(
                  count: pendingCount,
                  label: 'ожидают',
                  color: Colors.amber.shade700,
                  isDark: isDark),
            ],
          ],
        ),
        const SizedBox(height: 10),
        ...details.asMap().entries.map((e) => _DetailItemCard(
              item: e.value,
              index: e.key,
              isDark: isDark,
            )),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildBottomBar(S s, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surface
            : Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: _busy
          ? const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation(Color(0xFFFF8C00))),
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: _BottomActionBtn(
                    label: s.rejectAll,
                    icon: Icons.close_rounded,
                    color: const Color(0xFFEF4444),
                    bgColor: const Color(0xFFFEF2F2),
                    isDark: isDark,
                    onTap: _onReject,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BottomActionBtn(
                    label: s.signAll,
                    icon: Icons.draw_rounded,
                    color: const Color(0xFF22C55E),
                    bgColor: const Color(0xFFF0FDF4),
                    isDark: isDark,
                    onTap: _onSign,
                  ),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  final List<Color> gradientColors;

  const _InfoCard({
    required this.data,
    required this.isDark,
    required this.gradientColors,
  });

  String _fmtDate(String? raw) {
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

    final factory = data['factory_name']?.toString() ?? '—';
    final warehouse = data['warehouse_name']?.toString() ?? '—';
    final dept = data['department_name']?.toString() ?? '—';
    final applicant = data['applicant_name']?.toString() ?? '—';
    final arriving = _fmtDate(data['arriving_date']?.toString());
    final notes = data['notes']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.09),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
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
                      color: Colors.white, size: 17),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Информация о заявке',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Info rows
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _InfoRow2(
                    icon: Icons.person_rounded,
                    iconColor: const Color(0xFF6366F1),
                    label: 'Заявитель',
                    value: applicant,
                    isDark: isDark,
                    onSurface: onSurface),
                _divider(isDark),
                _InfoRow2(
                    icon: Icons.account_tree_rounded,
                    iconColor: const Color(0xFF0EA5E9),
                    label: 'Отдел',
                    value: dept,
                    isDark: isDark,
                    onSurface: onSurface),
                _divider(isDark),
                _InfoRow2(
                    icon: Icons.factory_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    label: 'Фабрика',
                    value: factory,
                    isDark: isDark,
                    onSurface: onSurface),
                _divider(isDark),
                _InfoRow2(
                    icon: Icons.warehouse_rounded,
                    iconColor: const Color(0xFF10B981),
                    label: 'Склад',
                    value: warehouse,
                    isDark: isDark,
                    onSurface: onSurface),
                _divider(isDark),
                _InfoRow2(
                    icon: Icons.event_rounded,
                    iconColor: const Color(0xFFEC4899),
                    label: 'Дата прихода',
                    value: arriving,
                    isDark: isDark,
                    onSurface: onSurface),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.amber.withOpacity(0.12)
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isDark
                              ? Colors.amber.withOpacity(0.3)
                              : Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.sticky_note_2_outlined,
                            size: 15,
                            color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            notes,
                            style: TextStyle(
                              fontSize: 13,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) => Divider(
        height: 16,
        thickness: 0.5,
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.grey.shade200,
      );
}

class _InfoRow2 extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isDark;
  final Color onSurface;

  const _InfoRow2({
    required this.icon,
    required this.iconColor,
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
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: onSurface.withOpacity(0.45),
                      letterSpacing: 0.2)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: onSurface),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
class _CountBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final bool isDark;

  const _CountBadge({
    required this.count,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.18) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: color.withOpacity(isDark ? 0.4 : 0.3)),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? color.withOpacity(0.9) : color),
      ),
    );
  }
}

// ─────────────────────────────────────────
class _DetailItemCard extends StatelessWidget {
  static const Color _g1 = Color(0xFFFF8C00);

  static const _statusConfig = <int, _StatusCfg>{
    0: _StatusCfg('Ожидает', 0xFFF59E0B, Icons.hourglass_empty_rounded),
    1: _StatusCfg('На подписи', 0xFF3B82F6, Icons.pending_rounded),
    2: _StatusCfg('Подписано', 0xFF22C55E, Icons.check_circle_rounded),
    3: _StatusCfg('Распределено', 0xFF06B6D4, Icons.inventory_rounded),
    4: _StatusCfg('Отклонено', 0xFFEF4444, Icons.cancel_rounded),
  };

  final Map<String, dynamic> item;
  final int index;
  final bool isDark;

  const _DetailItemCard({
    required this.item,
    required this.index,
    required this.isDark,
  });

  String _fmtNum(dynamic v, {bool allowZero = false}) {
    if (v == null) return '—';
    final d = (v as num).toDouble();
    if (!allowZero && d == 0) return '—';
    if (d == d.roundToDouble()) {
      return NumberFormat('#,##0').format(d.toInt());
    }
    return NumberFormat('#,##0.##').format(d);
  }

  String _fmtDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      return DateFormat('dd.MM.yyyy HH:mm')
          .format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final cardBg = isDark ? theme.colorScheme.surface : Colors.white;

    final materialName = item['material_name']?.toString() ?? '—';
    final amount = item['amount'];
    final unit = item['m_unit_name']?.toString() ?? '';
    final plannedCost = item['planned_cost'];
    final colorName = item['color_name']?.toString() ?? '';
    final itemNotes = item['notes']?.toString() ?? '';
    final status = item['status'] as int? ?? 0;
    final signerName = item['signer_name']?.toString() ?? '';
    final rejecterName = item['rejecter_name']?.toString() ?? '';
    final signTime = _fmtDateTime(item['sign_time']?.toString());
    final rejectedTime = _fmtDateTime(item['rejected_time']?.toString());

    final cfg = _statusConfig[status] ??
        const _StatusCfg('Ожидает', 0xFFF59E0B, Icons.hourglass_empty_rounded);
    final statusColor = Color(cfg.colorValue);
    final statusLabel = item['status_title']?.toString()?.isNotEmpty == true
        ? item['status_title'].toString()
        : cfg.label;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left status accent bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: statusColor,
                gradient: LinearGradient(
                  colors: [statusColor, statusColor.withOpacity(0.5)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: index + material name + status badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: _g1.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _g1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            materialName,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: onSurface,
                                height: 1.3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: statusColor.withOpacity(0.4),
                                width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(cfg.icon,
                                  size: 10, color: statusColor),
                              const SizedBox(width: 3),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Color badge (if present)
                    if (colorName.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.purple.withOpacity(0.15)
                              : Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: isDark
                                  ? Colors.purple.withOpacity(0.35)
                                  : Colors.purple.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.palette_outlined,
                                size: 11,
                                color: Colors.purple.shade600),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                colorName,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.purple.shade700,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Amount + cost row
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : const Color(0xFFF8F9FB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _DataCell(
                              icon: Icons.scale_outlined,
                              iconColor: const Color(0xFF0EA5E9),
                              label: 'Количество',
                              value: amount != null
                                  ? '${_fmtNum(amount, allowZero: true)} $unit'.trim()
                                  : '—',
                              onSurface: onSurface,
                              isDark: isDark,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.grey.shade200,
                            margin:
                                const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          Expanded(
                            child: _DataCell(
                              icon: Icons.payments_outlined,
                              iconColor: const Color(0xFF10B981),
                              label: 'Стоимость',
                              value: _fmtNum(plannedCost),
                              onSurface: onSurface,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Notes per item
                    if (itemNotes.isNotEmpty) ...[
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
                                size: 13,
                                color: Colors.amber.shade700),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                itemNotes,
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
                    // Signer info
                    if (signerName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _ActionInfo(
                        icon: Icons.draw_rounded,
                        color: const Color(0xFF22C55E),
                        name: signerName,
                        time: signTime,
                        isDark: isDark,
                      ),
                    ],
                    // Rejecter info
                    if (rejecterName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _ActionInfo(
                        icon: Icons.cancel_rounded,
                        color: const Color(0xFFEF4444),
                        name: rejecterName,
                        time: rejectedTime,
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCfg {
  final String label;
  final int colorValue;
  final IconData icon;
  const _StatusCfg(this.label, this.colorValue, this.icon);
}

class _DataCell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color onSurface;
  final bool isDark;

  const _DataCell({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onSurface,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: onSurface.withOpacity(0.45))),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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

class _ActionInfo extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String name;
  final String time;
  final bool isDark;

  const _ActionInfo({
    required this.icon,
    required this.color,
    required this.name,
    required this.time,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: color.withOpacity(isDark ? 0.3 : 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(time,
                style: TextStyle(
                    fontSize: 10, color: color.withOpacity(0.7))),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
class _BottomActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool isDark;
  final VoidCallback onTap;

  const _BottomActionBtn({
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? color.withOpacity(0.15) : bgColor,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: color.withOpacity(isDark ? 0.4 : 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
