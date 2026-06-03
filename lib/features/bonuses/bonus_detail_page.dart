import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BonusDetailPage extends StatelessWidget {
  final Map<String, dynamic> item;

  const BonusDetailPage({Key? key, required this.item}) : super(key: key);

  static const Color _g1 = Color(0xFFFF8C00);
  static const Color _g2 = Color(0xFFCC1500);

  Color _statusColor(int status) {
    switch (status) {
      case 1: return Colors.blue;
      case 2: return Colors.orange;
      case 3: return Colors.green;
      case 4: return Colors.purple;
      case 5: return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? [const Color(0xFF3D1800), const Color(0xFF1F0000)]
        : [_g1, _g2];

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
    final details =
        (item['detail_bonus_work_employee'] as List<dynamic>?) ?? [];
    final statusColor = _statusColor(status);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            'Премия №$id',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
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
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _InfoCard(
                        isDark: isDark,
                        gradientColors: gradientColors,
                        factory: factory,
                        month: month,
                        status: status,
                        statusText: statusText,
                        statusColor: statusColor,
                        creator: creator,
                        createdAt: createdAt,
                        totalBonus: totalBonus,
                        approveBy: approveBy,
                        confirmBy: confirmBy,
                        notes: notes,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
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
                            child: Row(
                              children: [
                                Icon(Icons.people_rounded,
                                    size: 14,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.orange.shade800),
                                const SizedBox(width: 6),
                                Text(
                                  'Сотрудников: ${details.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (details.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'Нет данных о сотрудниках',
                            style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey.shade500),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _EmployeeCard(
                            detail: details[i] as Map<String, dynamic>,
                            index: i + 1,
                            isDark: isDark,
                          ),
                          childCount: details.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final bool isDark;
  final List<Color> gradientColors;
  final String factory;
  final String month;
  final int status;
  final String statusText;
  final Color statusColor;
  final String creator;
  final String createdAt;
  final String totalBonus;
  final String approveBy;
  final String confirmBy;
  final String notes;

  const _InfoCard({
    required this.isDark,
    required this.gradientColors,
    required this.factory,
    required this.month,
    required this.status,
    required this.statusText,
    required this.statusColor,
    required this.creator,
    required this.createdAt,
    required this.totalBonus,
    required this.approveBy,
    required this.confirmBy,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final cardBg = isDark ? theme.colorScheme.surface : Colors.white;

    return Container(
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.card_giftcard_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$factory — $month',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        createdAt,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.4)),
                  ),
                  child: Text(statusText,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Создал',
                  value: creator,
                  isDark: isDark,
                  onSurface: onSurface,
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  icon: Icons.payments_outlined,
                  label: 'Итого (без налога)',
                  value: '$totalBonus UZS',
                  isDark: isDark,
                  onSurface: onSurface,
                  highlight: true,
                ),
                if (approveBy.isNotEmpty && approveBy.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _DetailRow(
                    icon: Icons.approval_rounded,
                    label: 'Согласовал',
                    value: approveBy,
                    isDark: isDark,
                    onSurface: onSurface,
                  ),
                ],
                if (confirmBy.isNotEmpty && confirmBy.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _DetailRow(
                    icon: Icons.verified_rounded,
                    label: 'Утвердил',
                    value: confirmBy,
                    isDark: isDark,
                    onSurface: onSurface,
                    accent: Colors.green,
                  ),
                ],
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.amber.withOpacity(0.1)
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isDark
                              ? Colors.amber.withOpacity(0.25)
                              : Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes_rounded,
                            size: 15, color: Colors.amber.shade700),
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
}

class _EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> detail;
  final int index;
  final bool isDark;

  const _EmployeeCard({
    required this.detail,
    required this.index,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final cardBg = isDark ? theme.colorScheme.surface : Colors.white;

    final name = detail['employee_name'] ?? '—';
    final reportCard = detail['report_card']?.toString() ?? '—';
    final department = detail['department_name'] ?? '—';
    final position = detail['position_name'] ?? '—';
    final bonusText = detail['bonus_text']?.toString() ?? '—';
    final bonusFeeText = detail['bonus_fee_text']?.toString() ?? '—';
    final notes = detail['notes']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8C00).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: const TextStyle(
                          color: Color(0xFFFF8C00),
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: onSurface),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Таб: $reportCard',
                        style: TextStyle(
                            fontSize: 11,
                            color: onSurface.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$bonusText UZS',
                      style: const TextStyle(
                          color: Color(0xFFFF8C00),
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'С нал.: $bonusFeeText',
                      style: TextStyle(
                          fontSize: 11,
                          color: onSurface.withOpacity(0.5)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.domain_rounded,
                          size: 13,
                          color: onSurface.withOpacity(0.4)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          department,
                          style: TextStyle(
                              fontSize: 12,
                              color: onSurface.withOpacity(0.7)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (position.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.work_outline_rounded,
                            size: 13,
                            color: onSurface.withOpacity(0.4)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            position,
                            style: TextStyle(
                                fontSize: 12,
                                color: onSurface.withOpacity(0.7)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded,
                      size: 13,
                      color: Colors.amber.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      notes,
                      style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: isDark
                              ? Colors.amber.shade200
                              : Colors.amber.shade800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color onSurface;
  final bool highlight;
  final Color? accent;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    required this.onSurface,
    this.highlight = false,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor =
        accent ?? (highlight ? const Color(0xFFFF8C00) : onSurface);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 15,
            color: accent ??
                (highlight
                    ? const Color(0xFFFF8C00)
                    : onSurface.withOpacity(0.45))),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                      fontSize: 13,
                      color: onSurface.withOpacity(0.55)),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: highlight || accent != null
                        ? FontWeight.bold
                        : FontWeight.w600,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
