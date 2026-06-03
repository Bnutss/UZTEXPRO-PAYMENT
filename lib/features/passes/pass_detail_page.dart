import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uztexpro_payment/main.dart';
import 'passes_page.dart' show passStatusConfig;
import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';

const _kDP = 'common/pass';

String? _roleFor(int status) {
  switch (status) {
    case 0: return 'release';
    case 1: return 'accountant';
    case 2: return 'director';
    case 3: return 'security';
    default: return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class PassDetailPage extends StatefulWidget {
  final int passId;
  final String jwtToken;
  final bool canSign;
  final bool canCancel;
  final VoidCallback onActionDone;

  const PassDetailPage({
    Key? key,
    required this.passId,
    required this.jwtToken,
    required this.canSign,
    required this.canCancel,
    required this.onActionDone,
  }) : super(key: key);

  @override
  State<PassDetailPage> createState() => _PassDetailPageState();
}

class _PassDetailPageState extends State<PassDetailPage> {
  static const _g1 = Color(0xFFFF8C00);
  static const _g2 = Color(0xFFCC1500);

  Map<String, dynamic>? _pass;
  bool _isLoading = true;
  String? _error;
  bool _busy = false;

  String get _token {
    try { return jsonDecode(widget.jwtToken)['token'] as String; }
    catch (_) { return widget.jwtToken; }
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_token',
    'Content-Type': 'application/json',
  };

  bool get _canSignNow {
    if (!widget.canSign || _pass == null) return false;
    final s = _pass!['status'] as int? ?? -1;
    return s >= 0 && s <= 3;
  }

  bool get _canCancelNow {
    if (!widget.canCancel || _pass == null) return false;
    return (_pass!['status'] as int? ?? -1) == 0;
  }

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
    setState(() { _isLoading = true; _error = null; });
    try {
      final resp = await http
          .get(Uri.parse('$API/$_kDP/${widget.passId}/'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final rawBody = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        setState(() {
          _pass = (rawBody['data'] as Map<String, dynamic>?) ?? rawBody;
          _isLoading = false;
        });
      } else {
        setState(() { _error = 'Ошибка ${resp.statusCode}'; _isLoading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Ошибка подключения:\n$e'; _isLoading = false; });
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  String _approveLabel(int status) {
    switch (status) {
      case 0: return 'Выдать';
      case 1: return 'Подписать (Бухгалтер)';
      case 2: return 'Подписать (Руководитель)';
      case 3: return 'Подписать (Охрана)';
      default: return 'Подтвердить';
    }
  }

  Future<void> _onApprove() async {
    final status = _pass!['status'] as int? ?? 0;
    final number = _pass!['number']?.toString() ?? '';
    final label = _approveLabel(status);
    final ok = await _confirmDialog(
      icon: Icons.check_circle_outline_rounded,
      iconColor: const Color(0xFF43A047),
      title: label,
      message: 'Подтвердить $number?',
      confirmLabel: label,
      confirmColor: const Color(0xFF43A047),
    );
    if (!ok) return;
    await _doSign('approve');
  }

  Future<void> _onReject() async {
    final number = _pass!['number']?.toString() ?? '';
    final comment = await showDialog<String>(
      context: context,
      builder: (_) => _RejectDialog(number: number),
    );
    if (comment == null) return;
    await _doSign('reject', comment: comment);
  }

  Future<void> _onCancel() async {
    final number = _pass!['number']?.toString() ?? '';
    final ok = await _confirmDialog(
      icon: Icons.cancel_outlined,
      iconColor: Colors.grey.shade600,
      title: 'Отменить пропуск',
      message: '$number будет отменён.',
      confirmLabel: 'Отменить',
      confirmColor: Colors.grey.shade600,
    );
    if (!ok) return;
    await _doSign('cancel');
  }

  Future<void> _doSign(String action, {String? comment}) async {
    final id = _pass!['id'];
    final status = _pass!['status'] as int? ?? -1;
    final role = action == 'cancel' ? 'cancel' : _roleFor(status);
    if (role == null) return;
    setState(() => _busy = true);
    try {
      final body = action == 'cancel'
          ? <String, dynamic>{}
          : action == 'reject'
              ? {'action': 'reject', 'comment': comment ?? ''}
              : {'action': 'approve'};
      final resp = await http
          .post(Uri.parse('$API/$_kDP/$id/sign/$role/'), headers: _headers, body: json.encode(body))
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        widget.onActionDone();
        if (mounted) Navigator.of(context).pop();
      } else {
        String msg = 'Ошибка (${resp.statusCode})';
        try {
          final err = json.decode(utf8.decode(resp.bodyBytes));
          msg = err['error'] ?? err['detail'] ?? msg;
        } catch (_) {}
        _snack(msg, false);
        setState(() => _busy = false);
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Ошибка: $e', false);
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
    final surface   = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: onSurface)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: onSurface.withOpacity(0.6))),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: onSurface.withOpacity(0.2)),
                  ),
                  child: Text(S.of(context).cancel,
                      style: TextStyle(color: onSurface.withOpacity(0.7), fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmColor, foregroundColor: Colors.white,
                    elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(confirmLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
    return result ?? false;
  }

  void _snack(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(ok ? Icons.check_circle : Icons.error, color: Colors.white, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
      ]),
      backgroundColor: ok ? const Color(0xFF43A047) : const Color(0xFFD32F2F),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradColors = isDark
        ? [const Color(0xFF3D1800), const Color(0xFF1F0000)]
        : [_g1, _g2];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: Text(
            _pass?['number']?.toString() ?? 'Пропуск',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
              onPressed: _isLoading ? null : _load,
              tooltip: 'Обновить',
            ),
          ],
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradColors,
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
        ),
        bottomNavigationBar: (!_isLoading && _error == null && (_canSignNow || _canCancelNow))
            ? _buildBottomBar(isDark)
            : null,
        body: _isLoading
            ? _buildShimmer(isDark, gradColors)
            : _error != null
                ? _buildError(isDark)
                : _buildContent(isDark, gradColors),
      ),
    );
  }

  Widget _buildShimmer(bool isDark, List<Color> gradColors) {
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final hi   = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    return Column(children: [
      Container(
        height: 170,
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradColors,
                begin: Alignment.topLeft, end: Alignment.bottomRight)),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: 4,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Shimmer.fromColors(
              baseColor: base, highlightColor: hi,
              child: Container(
                height: i == 0 ? 100 : 140,
                decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.red.shade50, shape: BoxShape.circle),
            child: Icon(Icons.wifi_off_rounded, size: 36,
                color: isDark ? Colors.white38 : Colors.red.shade300),
          ),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600,
                  fontSize: 13, height: 1.5)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Повторить'),
            style: FilledButton.styleFrom(
              backgroundColor: _g1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildContent(bool isDark, List<Color> gradColors) {
    final pass      = _pass!;
    final status    = pass['status'] as int? ?? 0;
    final cfg       = passStatusConfig(status);
    final label     = pass['status_display']?.toString() ?? cfg.label;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SingleChildScrollView(
      child: Column(children: [
        // ── Gradient header ──────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradColors,
                  begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              child: Column(children: [
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(cfg.icon, size: 15, color: Colors.white),
                    const SizedBox(width: 7),
                    Flexible(child: Text(label,
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 13))),
                  ]),
                ),
                const SizedBox(height: 16),
                _DetailProgress(status: status),
              ]),
            ),
          ),
        ),

        // ── Cards area ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          child: Column(children: [
            _InfoCard(pass: pass, isDark: isDark, onSurface: onSurface),
            const SizedBox(height: 10),
            _ItemsCard(
                items: (pass['items'] as List?) ?? [],
                isDark: isDark,
                onSurface: onSurface),
            const SizedBox(height: 10),
            _SignaturesCard(pass: pass, isDark: isDark, onSurface: onSurface),
            if (_hasComments(pass)) ...[
              const SizedBox(height: 10),
              _CommentsCard(pass: pass, isDark: isDark, onSurface: onSurface),
            ],
          ]),
        ),
      ]),
    );
  }

  bool _hasComments(Map<String, dynamic> p) =>
      (p['comment']?.toString() ?? '').isNotEmpty ||
      (p['rejection_comment']?.toString() ?? '').isNotEmpty;

  Widget _buildBottomBar(bool isDark) {
    final status = _pass!['status'] as int? ?? 0;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.09),
                blurRadius: 16, offset: const Offset(0, -4)),
          ],
        ),
        child: _busy
            ? const Center(child: SizedBox(width: 28, height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Color(0xFFFF8C00)))))
            : _canSignNow
                ? Row(children: [
                    Expanded(child: _ActionButton(
                      label: _approveLabel(status),
                      icon: Icons.check_rounded,
                      color: const Color(0xFF2E7D32),
                      bgColor: const Color(0xFFE8F5E9),
                      isDark: isDark,
                      onTap: _onApprove,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _ActionButton(
                      label: 'Отклонить',
                      icon: Icons.close_rounded,
                      color: const Color(0xFFD32F2F),
                      bgColor: const Color(0xFFFFEBEE),
                      isDark: isDark,
                      onTap: _onReject,
                    )),
                  ])
                : _ActionButton(
                    label: 'Отменить пропуск',
                    icon: Icons.cancel_outlined,
                    color: Colors.grey.shade600,
                    bgColor: Colors.grey.shade100,
                    isDark: isDark,
                    onTap: _onCancel,
                  ),
      ),
    );
  }
}

// ─── Progress stepper ─────────────────────────────────────────────────────────

class _DetailProgress extends StatelessWidget {
  final int status;
  const _DetailProgress({required this.status});

  static const _steps = [
    (0, 'Новый',     Color(0xFF1E88E5)),
    (1, 'Выдан',     Color(0xFFFF8C00)),
    (2, 'Бухгалтер', Color(0xFFF57C00)),
    (3, 'Рук-ль',    Color(0xFF43A047)),
    (4, 'Завершён',  Color(0xFF2E7D32)),
  ];

  @override
  Widget build(BuildContext context) {
    if (status == -1) {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cancel_outlined, size: 14, color: Colors.white54),
        const SizedBox(width: 6),
        Text('Пропуск отменён',
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6),
                fontStyle: FontStyle.italic)),
      ]);
    }
    return Column(children: [
      Row(children: [
        for (int i = 0; i < _steps.length; i++) ...[
          _StepDot(done: status > _steps[i].$1,
              current: status == _steps[i].$1, color: _steps[i].$3),
          if (i < _steps.length - 1)
            Expanded(child: Container(
              height: 2, margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: status > _steps[i].$1
                    ? _steps[i].$3
                    : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(1),
              ),
            )),
        ],
      ]),
      const SizedBox(height: 5),
      Row(children: [
        for (int i = 0; i < _steps.length; i++) ...[
          Text(_steps[i].$2, style: TextStyle(
            fontSize: 9,
            fontWeight: status == _steps[i].$1 ? FontWeight.w700 : FontWeight.w400,
            color: status >= _steps[i].$1
                ? Colors.white
                : Colors.white.withOpacity(0.3),
          )),
          if (i < _steps.length - 1) const Spacer(),
        ],
      ]),
    ]);
  }
}

class _StepDot extends StatelessWidget {
  final bool done;
  final bool current;
  final Color color;
  const _StepDot({required this.done, required this.current, required this.color});

  @override
  Widget build(BuildContext context) {
    final size   = current ? 20.0 : 15.0;
    final active = done || current;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : Colors.white.withOpacity(0.15),
        border: Border.all(
            color: active ? color : Colors.white.withOpacity(0.3),
            width: current ? 2.5 : 1.5),
        boxShadow: current
            ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 7, spreadRadius: 1)]
            : null,
      ),
      child: active
          ? Icon(Icons.check_rounded, size: size * 0.58, color: Colors.white)
          : null,
    );
  }
}

// ─── Info card ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Map<String, dynamic> pass;
  final bool isDark;
  final Color onSurface;
  const _InfoCard({required this.pass, required this.isDark, required this.onSurface});

  static String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try { return DateFormat('dd.MM.yyyy').format(DateTime.parse(raw)); }
    catch (_) { return raw; }
  }

  static String _fmtDT(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try { return DateFormat('dd.MM.yyyy  HH:mm').format(DateTime.parse(raw)); }
    catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    final warehouse = (pass['intermediate_warehouse_name'] ?? pass['warehouse_name'])?.toString() ?? '';
    final kppTime   = pass['kpp_time']?.toString() ?? '';
    final autoIn    = pass['auto_incoming'];
    final autoOut   = pass['auto_outgoing'];
    final typeName  = pass['pass_type_name']?.toString() ?? '';

    return _SectionCard(
      title: 'Информация',
      icon: Icons.info_outline_rounded,
      isDark: isDark,
      child: Column(children: [
        _Row2(icon: Icons.tag_rounded,           label: 'Номер',
            value: pass['number']?.toString() ?? '—', os: onSurface),
        _Row2(icon: Icons.calendar_today_rounded, label: 'Дата',
            value: _fmtDate(pass['date']?.toString()), os: onSurface),
        _Row2(icon: Icons.business_outlined,     label: 'Клиент',
            value: pass['client']?.toString() ?? '—', os: onSurface),
        _Row2(icon: Icons.factory_outlined,      label: 'Фабрика',
            value: pass['factory_name']?.toString() ?? '—', os: onSurface),
        if (typeName.isNotEmpty)
          _Row2(icon: Icons.category_outlined,   label: 'Тип', value: typeName, os: onSurface),
        if (warehouse.isNotEmpty)
          _Row2(icon: Icons.warehouse_outlined,  label: 'Склад', value: warehouse, os: onSurface),
        _Row2(icon: Icons.person_outline_rounded, label: 'Создал',
            value: pass['create_by_name']?.toString() ?? '—', os: onSurface),
        _Row2(icon: Icons.access_time_rounded,   label: 'Создан',
            value: _fmtDT(pass['create_at']?.toString()), os: onSurface),
        if (kppTime.isNotEmpty)
          _Row2(icon: Icons.directions_car_outlined, label: 'КПП',
              value: _fmtDT(kppTime), os: onSurface),
        if (autoIn != null)
          _Row2(icon: Icons.input_rounded, label: 'Авто-приход',
              value: '#$autoIn', os: onSurface),
        if (autoOut != null)
          _Row2(icon: Icons.output_rounded, label: 'Авто-расход',
              value: '#$autoOut', os: onSurface),
      ]),
    );
  }
}

// ─── Items card ───────────────────────────────────────────────────────────────

class _ItemsCard extends StatelessWidget {
  final List items;
  final bool isDark;
  final Color onSurface;
  const _ItemsCard({required this.items, required this.isDark, required this.onSurface});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Позиции (${items.length})',
      icon: Icons.layers_outlined,
      isDark: isDark,
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Center(child: Text('Нет позиций',
                  style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.4),
                      fontStyle: FontStyle.italic))),
            )
          : Column(children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Divider(height: 10, thickness: 0.5,
                      color: isDark ? Colors.white10 : Colors.grey.shade100),
                _ItemRow(
                    item: items[i] as Map<String, dynamic>,
                    index: i + 1,
                    isDark: isDark,
                    onSurface: onSurface),
              ],
            ]),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;
  final bool isDark;
  final Color onSurface;
  const _ItemRow({required this.item, required this.index,
      required this.isDark, required this.onSurface});

  static String _fmt(dynamic raw) {
    if (raw == null) return '—';
    final n = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    if (n == null) return raw.toString();
    if (n == n.truncateToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final name     = item['material_title']?.toString()
        ?? item['material_name']?.toString() ?? '—';
    final typeName = item['pass_type_name']?.toString() ?? '';
    final amount   = _fmt(item['amount']);
    final unit     = item['m_unit_name']?.toString() ?? item['unit_name']?.toString() ?? '';
    final barcode  = item['comment']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Index badge
        Container(
          width: 26, height: 26, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFF8C00).withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text('$index', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold,
              color: isDark ? Colors.orange.shade300 : const Color(0xFFFF8C00))),
        ),
        const SizedBox(width: 10),
        // Content
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: onSurface),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          if (typeName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(typeName, style: TextStyle(
                fontSize: 10, color: onSurface.withOpacity(0.45)),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 6),
          // Amount + barcode as Wrap to avoid overflow
          Wrap(spacing: 6, runSpacing: 4, children: [
            _Pill(
              text: unit.isNotEmpty ? '$amount $unit' : amount,
              color: isDark ? Colors.blue.shade200 : Colors.blue.shade700,
              bgColor: isDark ? Colors.blue.withOpacity(0.18) : Colors.blue.shade50,
              borderColor: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.shade200,
              icon: Icons.scale_outlined,
            ),
            if (barcode.isNotEmpty)
              _Pill(
                text: barcode,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
                bgColor: isDark ? Colors.white.withOpacity(0.07) : Colors.grey.shade100,
                borderColor: isDark ? Colors.white12 : Colors.grey.shade300,
                icon: Icons.qr_code_rounded,
              ),
          ]),
        ])),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final IconData icon;
  const _Pill({required this.text, required this.color, required this.bgColor,
      required this.borderColor, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

// ─── Signatures card ──────────────────────────────────────────────────────────

class _SignaturesCard extends StatelessWidget {
  final Map<String, dynamic> pass;
  final bool isDark;
  final Color onSurface;
  const _SignaturesCard({required this.pass, required this.isDark, required this.onSurface});

  static String _fmt(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return raw.length <= 10
          ? DateFormat('dd.MM.yyyy').format(dt)
          : DateFormat('dd.MM.yyyy  HH:mm').format(dt);
    } catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      (Icons.person_add_outlined,       'Создал',         pass['create_by_name'],         _fmt(pass['date']?.toString()),              const Color(0xFF1E88E5)),
      (Icons.how_to_reg_rounded,        'Отпустил',       pass['released_by_name'],       _fmt(pass['released_at']?.toString()),       const Color(0xFFFF8C00)),
      (Icons.account_balance_outlined,  'Гл. бухгалтер',  pass['signed_accountant_name'], _fmt(pass['signed_accountant_at']?.toString()), const Color(0xFFF57C00)),
      (Icons.verified_outlined,         'Руководитель',   pass['signed_director_name'],   _fmt(pass['signed_director_at']?.toString()), const Color(0xFF43A047)),
      (Icons.security_rounded,          'Охрана',         pass['security_signed_by_name'],_fmt(pass['security_signed_at']?.toString()), const Color(0xFF2E7D32)),
    ];

    return _SectionCard(
      title: 'История подписей',
      icon: Icons.draw_rounded,
      isDark: isDark,
      child: Column(children: [
        for (int i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Container(
                  width: 1.5, height: 8,
                  color: isDark ? Colors.white12 : Colors.grey.shade200),
            ),
          _SignStep(
            icon: steps[i].$1,
            label: steps[i].$2,
            name: steps[i].$3?.toString(),
            dateStr: steps[i].$4,
            color: steps[i].$5,
            isDark: isDark,
            onSurface: onSurface,
          ),
        ],
      ]),
    );
  }
}

class _SignStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? name;
  final String dateStr;
  final Color color;
  final bool isDark;
  final Color onSurface;
  const _SignStep({required this.icon, required this.label, required this.name,
      required this.dateStr, required this.color, required this.isDark,
      required this.onSurface});

  @override
  Widget build(BuildContext context) {
    final signed = name != null && name!.isNotEmpty;
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      // Icon circle
      Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: signed
              ? color.withOpacity(isDark ? 0.22 : 0.1)
              : (isDark ? Colors.white10 : Colors.grey.shade100),
          border: Border.all(
              color: signed
                  ? color.withOpacity(0.45)
                  : (isDark ? Colors.white12 : Colors.grey.shade300),
              width: 1.5),
        ),
        child: Icon(icon, size: 13,
            color: signed ? color : onSurface.withOpacity(0.28)),
      ),
      const SizedBox(width: 10),
      // Text block — no trailing widget so no overflow
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
            fontSize: 10, color: onSurface.withOpacity(0.45),
            fontWeight: FontWeight.w500)),
        const SizedBox(height: 1),
        Text(signed ? name! : '—',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: signed ? onSurface : onSurface.withOpacity(0.3))),
        if (signed && dateStr.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(dateStr, style: TextStyle(
              fontSize: 10, color: onSurface.withOpacity(0.4))),
        ],
      ])),
      // Signed checkmark
      if (signed)
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(isDark ? 0.2 : 0.08)),
          child: Icon(Icons.check_rounded, size: 12, color: color),
        ),
    ]);
  }
}

// ─── Comments card ────────────────────────────────────────────────────────────

class _CommentsCard extends StatelessWidget {
  final Map<String, dynamic> pass;
  final bool isDark;
  final Color onSurface;
  const _CommentsCard({required this.pass, required this.isDark, required this.onSurface});

  @override
  Widget build(BuildContext context) {
    final comment    = pass['comment']?.toString() ?? '';
    final rejComment = pass['rejection_comment']?.toString() ?? '';

    return _SectionCard(
      title: 'Примечания',
      icon: Icons.notes_rounded,
      isDark: isDark,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (comment.isNotEmpty) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.notes_rounded, size: 13, color: Colors.amber.shade600),
            const SizedBox(width: 8),
            Expanded(child: Text(comment,
                style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.8)))),
          ]),
          if (rejComment.isNotEmpty) const SizedBox(height: 8),
        ],
        if (rejComment.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(isDark ? 0.12 : 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red.shade400),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Причина отклонения',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: Colors.red.shade400)),
                const SizedBox(height: 3),
                Text(rejComment, style: TextStyle(fontSize: 12,
                    color: isDark ? Colors.red.shade200 : Colors.red.shade700)),
              ])),
            ]),
          ),
      ]),
    );
  }
}

// ─── Section card shell ───────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;
  final Widget child;
  const _SectionCard({required this.title, required this.icon,
      required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final bg = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 14, color: const Color(0xFFFF8C00)),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold,
                color: onSurface.withOpacity(0.65))),
          ]),
          Divider(height: 14, thickness: 0.5,
              color: isDark ? Colors.white12 : Colors.grey.shade100),
          child,
        ]),
      ),
    );
  }
}

// ─── Info row (label + value) ─────────────────────────────────────────────────

class _Row2 extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color os;
  const _Row2({required this.icon, required this.label,
      required this.value, required this.os});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 13, color: os.withOpacity(0.32)),
        const SizedBox(width: 7),
        SizedBox(
          width: 88,
          child: Text(label,
              style: TextStyle(fontSize: 11, color: os.withOpacity(0.48)),
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(child: Text(value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: os.withOpacity(0.82)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

// ─── Action button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool isDark;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.icon, required this.color,
      required this.bgColor, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: isDark ? color.withOpacity(0.15) : bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(isDark ? 0.35 : 0.3)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 7),
            Flexible(child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 13,
                    fontWeight: FontWeight.bold))),
          ]),
        ),
      ),
    );
  }
}

// ─── Reject dialog ────────────────────────────────────────────────────────────

class _RejectDialog extends StatefulWidget {
  final String number;
  const _RejectDialog({required this.number});

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final surface   = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.cancel_outlined, color: Colors.red, size: 26),
          ),
          const SizedBox(height: 12),
          Text('Отклонить пропуск',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: onSurface)),
          const SizedBox(height: 3),
          Text(widget.number,
              style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.5))),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl, maxLines: 3, autofocus: true,
            style: TextStyle(fontSize: 13, color: onSurface),
            decoration: InputDecoration(
              hintText: 'Причина отклонения...',
              hintStyle: TextStyle(color: onSurface.withOpacity(0.38), fontSize: 12),
              filled: true,
              fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: onSurface.withOpacity(0.15))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: onSurface.withOpacity(0.15))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.red, width: 1.5)),
              contentPadding: const EdgeInsets.all(11),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(null),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: onSurface.withOpacity(0.2)),
                ),
                child: Text(S.of(context).cancel,
                    style: TextStyle(color: onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white,
                  elevation: 0, padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Отклонить',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
