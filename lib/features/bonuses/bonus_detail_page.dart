import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uztexpro_payment/main.dart';
import 'bonuses_page.dart' show bonusStatusConfig;
import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';

const _kDPBonus = 'edo/bonus-employee';

// ─────────────────────────────────────────────────────────────────────────────

class BonusDetailPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final String jwtToken;
  final bool canSign;
  final bool canDelete;
  final VoidCallback onActionDone;

  const BonusDetailPage({
    Key? key,
    required this.item,
    required this.jwtToken,
    required this.canSign,
    required this.canDelete,
    required this.onActionDone,
  }) : super(key: key);

  @override
  State<BonusDetailPage> createState() => _BonusDetailPageState();
}

class _BonusDetailPageState extends State<BonusDetailPage> {
  static const _g1 = Color(0xFFFF8C00);
  static const _g2 = Color(0xFFCC1500);

  late Map<String, dynamic> _item;
  bool _busy = false;

  String get _token {
    try { return jsonDecode(widget.jwtToken)['token'] as String; }
    catch (_) { return widget.jwtToken; }
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_token',
    'Content-Type': 'application/json',
  };

  bool get _canSignNow   => widget.canSign   && (_item['status'] as int? ?? 0) != 4;
  bool get _canDeleteNow => widget.canDelete;

  @override
  void initState() {
    super.initState();
    _item = Map.from(widget.item);
    localeNotifier.addListener(_onLocale);
  }

  void _onLocale() => setState(() {});

  @override
  void dispose() {
    localeNotifier.removeListener(_onLocale);
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _onApprove() async {
    final ok = await _confirmDialog(
      icon: Icons.check_circle_outline_rounded,
      iconColor: const Color(0xFF43A047),
      title: S.of(context).bonusApproveTitle,
      message: S.of(context).bonusApproveDesc,
      confirmLabel: S.of(context).bonusApproveBtn,
      confirmColor: const Color(0xFF43A047),
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final id   = _item['id'];
      final resp = await http
          .patch(Uri.parse('$API/$_kDPBonus/$id/'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        widget.onActionDone();
        if (mounted) Navigator.of(context).pop();
      } else {
        String msg = '${S.of(context).signError} (${resp.statusCode})';
        try {
          final err = json.decode(utf8.decode(resp.bodyBytes));
          msg = err['error'] ?? err['detail'] ?? msg;
        } catch (_) {}
        _snack(msg, false);
        setState(() => _busy = false);
      }
    } catch (e) {
      if (!mounted) return;
      _snack(S.of(context).connectionError, false);
      setState(() => _busy = false);
    }
  }

  Future<void> _onDelete() async {
    final ok = await _confirmDialog(
      icon: Icons.delete_outline_rounded,
      iconColor: Colors.red.shade600,
      title: S.of(context).bonusDeleteTitle,
      message: S.of(context).bonusDeleteDesc,
      confirmLabel: S.of(context).deleteBtn,
      confirmColor: Colors.red.shade600,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final id   = _item['id'];
      final resp = await http
          .delete(Uri.parse('$API/$_kDPBonus/$id/'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (resp.statusCode == 200 || resp.statusCode == 204) {
        widget.onActionDone();
        if (mounted) Navigator.of(context).pop();
      } else {
        _snack('${S.of(context).updateError} (${resp.statusCode})', false);
        setState(() => _busy = false);
      }
    } catch (e) {
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
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: onSurface)),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: onSurface.withOpacity(0.2)),
                  ),
                  child: Text(S.of(context).cancel,
                      style: TextStyle(
                          color: onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.w600, fontSize: 13)),
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
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(confirmLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
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
        Expanded(child: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
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
    final id = _item['id']?.toString() ?? '—';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor:
            isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: Text(
            '${S.of(context).bonusNumber}$id',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: gradColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
            ),
          ),
        ),
        bottomNavigationBar:
            (_canSignNow || _canDeleteNow) ? _buildBottomBar(isDark) : null,
        body: _buildContent(isDark, gradColors),
      ),
    );
  }

  Widget _buildContent(bool isDark, List<Color> gradColors) {
    final status      = _item['status'] as int? ?? 0;
    final cfg         = bonusStatusConfig(status);
    final statusLabel = _item['status_text']?.toString() ?? cfg.label;
    final onSurface   = Theme.of(context).colorScheme.onSurface;
    final notes       = _item['notes']?.toString() ?? '';

    return SingleChildScrollView(
      child: Column(children: [
        // ── Gradient header ──────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: gradColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              child: Column(children: [
                // Status pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.35), width: 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(cfg.icon, size: 15, color: Colors.white),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(statusLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
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
            _InfoCard(item: _item, isDark: isDark, onSurface: onSurface),
            const SizedBox(height: 10),
            _EmployeesCard(
              details: (_item['detail_bonus_work_employee'] as List?) ?? [],
              isDark: isDark,
              onSurface: onSurface,
            ),
            const SizedBox(height: 10),
            _ApprovalsCard(item: _item, isDark: isDark, onSurface: onSurface),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              _NotesCard(notes: notes, isDark: isDark, onSurface: onSurface),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.09),
                blurRadius: 16, offset: const Offset(0, -4)),
          ],
        ),
        child: _busy
            ? const Center(
                child: SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation(Color(0xFFFF8C00))),
                ),
              )
            : Row(children: [
                if (_canDeleteNow) ...[
                  Expanded(child: _ActionButton(
                    label: S.of(context).deleteBtn,
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFD32F2F),
                    bgColor: const Color(0xFFFFEBEE),
                    isDark: isDark,
                    onTap: _onDelete,
                  )),
                  if (_canSignNow) const SizedBox(width: 10),
                ],
                if (_canSignNow)
                  Expanded(child: _ActionButton(
                    label: S.of(context).bonusApproveBtn,
                    icon: Icons.check_rounded,
                    color: const Color(0xFF2E7D32),
                    bgColor: const Color(0xFFE8F5E9),
                    isDark: isDark,
                    onTap: _onApprove,
                  )),
              ]),
      ),
    );
  }
}

// ─── Progress stepper ─────────────────────────────────────────────────────────

class _DetailProgress extends StatelessWidget {
  final int status;
  const _DetailProgress({required this.status});

  // Ordered workflow: 1 → 5 → 2 → 3 → 4
  static const _steps = [
    (1, 'Новый',     Color(0xFF1E88E5)),
    (5, 'Проверка',  Color(0xFF00ACC1)),
    (2, 'Одобрен',   Color(0xFFFF8C00)),
    (3, 'Утверждён', Color(0xFF43A047)),
    (4, 'Оплачен',   Color(0xFF7B1FA2)),
  ];

  int get _idx {
    for (int i = 0; i < _steps.length; i++) {
      if (_steps[i].$1 == status) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _idx;
    return Column(children: [
      Row(children: [
        for (int i = 0; i < _steps.length; i++) ...[
          _StepDot(done: idx >= 0 && i < idx, current: i == idx,
              color: _steps[i].$3),
          if (i < _steps.length - 1)
            Expanded(child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: (idx >= 0 && i < idx)
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
            fontWeight: i == idx ? FontWeight.w700 : FontWeight.w400,
            color: (idx >= 0 && i <= idx)
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
            ? [BoxShadow(
                color: color.withOpacity(0.5), blurRadius: 7, spreadRadius: 1)]
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
  final Map<String, dynamic> item;
  final bool isDark;
  final Color onSurface;
  const _InfoCard({required this.item, required this.isDark, required this.onSurface});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return _SectionCard(
      title: 'Информация',
      icon: Icons.info_outline_rounded,
      isDark: isDark,
      child: Column(children: [
        _Row2(icon: Icons.tag_rounded,
            label: s.bonusNumber,
            value: item['id']?.toString() ?? '—', os: onSurface),
        _Row2(icon: Icons.factory_outlined,
            label: s.factoryLabel,
            value: item['factory_name']?.toString() ?? '—', os: onSurface),
        _Row2(icon: Icons.calendar_month_rounded,
            label: s.monthLabel,
            value: item['month_text']?.toString() ?? '—', os: onSurface),
        _Row2(icon: Icons.person_outline_rounded,
            label: s.createdByLabel,
            value: item['create_by_name']?.toString() ?? '—', os: onSurface),
        _Row2(icon: Icons.access_time_rounded,
            label: s.dateLabel,
            value: item['created_at']?.toString() ?? '—', os: onSurface),
        _Row2(icon: Icons.payments_outlined,
            label: s.totalLabel,
            value: '${item['total_bonus']?.toString() ?? '—'} UZS',
            os: onSurface, highlight: true),
      ]),
    );
  }
}

// ─── Employees card ───────────────────────────────────────────────────────────

class _EmployeesCard extends StatelessWidget {
  final List details;
  final bool isDark;
  final Color onSurface;
  const _EmployeesCard({
    required this.details, required this.isDark, required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Сотрудники (${details.length})',
      icon: Icons.people_outlined,
      isDark: isDark,
      child: details.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Center(child: Text('Нет сотрудников',
                  style: TextStyle(fontSize: 12,
                      color: onSurface.withOpacity(0.4),
                      fontStyle: FontStyle.italic))),
            )
          : Column(children: [
              for (int i = 0; i < details.length; i++) ...[
                if (i > 0)
                  Divider(height: 10, thickness: 0.5,
                      color: isDark ? Colors.white10 : Colors.grey.shade100),
                _EmployeeRow(
                  detail: details[i] as Map<String, dynamic>,
                  index: i + 1,
                  isDark: isDark,
                  onSurface: onSurface,
                ),
              ],
            ]),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  final Map<String, dynamic> detail;
  final int index;
  final bool isDark;
  final Color onSurface;
  const _EmployeeRow({
    required this.detail, required this.index,
    required this.isDark, required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    final name       = detail['employee_name']?.toString() ?? '—';
    final reportCard = detail['report_card']?.toString() ?? '';
    final department = detail['department_name']?.toString() ?? '';
    final position   = detail['position_name']?.toString() ?? '';
    final bonusText  = detail['bonus_text']?.toString() ?? '—';
    final bonusFee   = detail['bonus_fee_text']?.toString() ?? '';
    final notes      = detail['notes']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Index badge
        Container(
          width: 26, height: 26, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFF8C00)
                .withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text('$index', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold,
              color: isDark
                  ? Colors.orange.shade300
                  : const Color(0xFFFF8C00))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + bonus
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(name, style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: onSurface),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$bonusText UZS', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold,
                      color: isDark
                          ? Colors.orange.shade300
                          : const Color(0xFFFF8C00))),
                  if (bonusFee.isNotEmpty)
                    Text('С нал.: $bonusFee', style: TextStyle(
                        fontSize: 10, color: onSurface.withOpacity(0.45))),
                ]),
              ],
            ),
            if (reportCard.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Таб: $reportCard', style: TextStyle(
                  fontSize: 10, color: onSurface.withOpacity(0.45))),
            ],
            // Dept + position
            if (department.isNotEmpty || position.isNotEmpty) ...[
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (department.isNotEmpty)
                      Row(children: [
                        Icon(Icons.domain_rounded, size: 11,
                            color: onSurface.withOpacity(0.35)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(department,
                            style: TextStyle(fontSize: 11,
                                color: onSurface.withOpacity(0.65)),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                    if (position.isNotEmpty) ...[
                      if (department.isNotEmpty) const SizedBox(height: 3),
                      Row(children: [
                        Icon(Icons.work_outline_rounded, size: 11,
                            color: onSurface.withOpacity(0.35)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(position,
                            style: TextStyle(fontSize: 11,
                                color: onSurface.withOpacity(0.65)),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.notes_rounded, size: 11,
                    color: Colors.amber.shade600),
                const SizedBox(width: 4),
                Expanded(child: Text(notes, style: TextStyle(
                    fontSize: 11, fontStyle: FontStyle.italic,
                    color: isDark
                        ? Colors.amber.shade300
                        : Colors.amber.shade800),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
            ],
          ],
        )),
      ]),
    );
  }
}

// ─── Approvals card ───────────────────────────────────────────────────────────

class _ApprovalsCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDark;
  final Color onSurface;
  const _ApprovalsCard({
    required this.item, required this.isDark, required this.onSurface,
  });

  // Extract name and date from approvals list by sequential index
  static String? _nameAt(List approvals, int index) {
    if (index >= approvals.length) return null;
    final a = approvals[index];
    if (a is! Map) return null;
    final name = a['approver_name']?.toString();
    if (name != null && name.isNotEmpty) return name;
    // Try nested approver object
    final approver = a['approver'];
    if (approver is Map) {
      final n = approver['full_name']?.toString()
          ?? approver['username']?.toString();
      if (n != null && n.isNotEmpty) return n;
    }
    return null;
  }

  static String? _dateAt(List approvals, int index) {
    if (index >= approvals.length) return null;
    final a = approvals[index];
    if (a is! Map) return null;
    return a['signed_at']?.toString();
  }

  @override
  Widget build(BuildContext context) {
    final approvals = (item['approvals_bonus'] as List?) ?? [];
    // Fallback flat fields from serializer
    final approveBy = item['approve_by']?.toString() ?? '';
    final confirmBy = item['confirm_by']?.toString() ?? '';

    // Workflow order: 1→5→2→3→4
    // approvals[0]: proverka_premiya   (1→5)
    // approvals[1]: zam_direktor       (5→2) / approve_by
    // approvals[2]: gen_direktor       (2→3) / confirm_by
    // approvals[3]: oplata             (3→4)
    final steps = [
      (
        Icons.person_add_outlined,
        'Создал',
        item['create_by_name']?.toString(),
        item['created_at']?.toString(),
        const Color(0xFF1E88E5),
      ),
      (
        Icons.rate_review_outlined,
        'Проверил',
        _nameAt(approvals, 0),
        _dateAt(approvals, 0),
        const Color(0xFF00ACC1),
      ),
      (
        Icons.thumb_up_outlined,
        'Одобрил (зам.)',
        _nameAt(approvals, 1) ?? (approveBy.isNotEmpty ? approveBy : null),
        _dateAt(approvals, 1),
        const Color(0xFFFF8C00),
      ),
      (
        Icons.verified_outlined,
        'Утвердил (ген.)',
        _nameAt(approvals, 2) ?? (confirmBy.isNotEmpty ? confirmBy : null),
        _dateAt(approvals, 2),
        const Color(0xFF43A047),
      ),
      (
        Icons.paid_outlined,
        'Оплатил',
        _nameAt(approvals, 3),
        _dateAt(approvals, 3),
        const Color(0xFF7B1FA2),
      ),
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
              child: Container(width: 1.5, height: 8,
                  color: isDark ? Colors.white12 : Colors.grey.shade200),
            ),
          _ApprovalStep(
            icon: steps[i].$1,
            label: steps[i].$2,
            name: steps[i].$3,
            dateStr: steps[i].$4 ?? '',
            color: steps[i].$5,
            isDark: isDark,
            onSurface: onSurface,
          ),
        ],
      ]),
    );
  }
}

class _ApprovalStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? name;
  final String dateStr;
  final Color color;
  final bool isDark;
  final Color onSurface;
  const _ApprovalStep({
    required this.icon, required this.label, required this.name,
    required this.dateStr, required this.color,
    required this.isDark, required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    final signed = name != null && name!.isNotEmpty;
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
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
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(
              fontSize: 10, color: onSurface.withOpacity(0.45),
              fontWeight: FontWeight.w500)),
          const SizedBox(height: 1),
          Text(signed ? name! : '—',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: signed ? onSurface : onSurface.withOpacity(0.3))),
          if (signed && dateStr.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(dateStr, style: TextStyle(
                fontSize: 10, color: onSurface.withOpacity(0.4))),
          ],
        ],
      )),
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

// ─── Notes card ───────────────────────────────────────────────────────────────

class _NotesCard extends StatelessWidget {
  final String notes;
  final bool isDark;
  final Color onSurface;
  const _NotesCard({required this.notes, required this.isDark, required this.onSurface});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Примечание',
      icon: Icons.notes_rounded,
      isDark: isDark,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.notes_rounded, size: 13, color: Colors.amber.shade600),
        const SizedBox(width: 8),
        Expanded(child: Text(notes, style: TextStyle(
            fontSize: 12, color: onSurface.withOpacity(0.8)))),
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
  const _SectionCard({
    required this.title, required this.icon,
    required this.isDark, required this.child,
  });

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

// ─── Info row ─────────────────────────────────────────────────────────────────

class _Row2 extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color os;
  final bool highlight;
  const _Row2({
    required this.icon, required this.label,
    required this.value, required this.os,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 13,
            color: highlight
                ? const Color(0xFFFF8C00)
                : os.withOpacity(0.32)),
        const SizedBox(width: 7),
        SizedBox(
          width: 90,
          child: Text(label,
              style: TextStyle(fontSize: 11, color: os.withOpacity(0.48)),
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(child: Text(value, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: highlight
                ? const Color(0xFFFF8C00)
                : os.withOpacity(0.82)),
            maxLines: 2, overflow: TextOverflow.ellipsis)),
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
  const _ActionButton({
    required this.label, required this.icon, required this.color,
    required this.bgColor, required this.isDark, required this.onTap,
  });

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
            border: Border.all(
                color: color.withOpacity(isDark ? 0.35 : 0.3)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 7),
            Flexible(child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color, fontSize: 13,
                    fontWeight: FontWeight.bold))),
          ]),
        ),
      ),
    );
  }
}
