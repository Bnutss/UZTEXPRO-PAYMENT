import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/widgets/stagger_in.dart';
import 'shop_api.dart';

enum _RangePreset { today, week, month, custom }

class _ShopPickupColors {
  static const Color g1 = Color(0xFFFF8C00);
  static const Color g2 = Color(0xFFCC1500);
}

/// PVZ (pickup-point) order view: lists orders placed via uztexpro_store
/// that are still waiting to be handed over at this employee's own shop.
/// Handover itself now happens on the dedicated ПВЗ web terminal
/// (face-recognition driven) — this screen is read-only.
class ShopPickupPage extends StatefulWidget {
  final String jwtToken;

  const ShopPickupPage({super.key, required this.jwtToken});

  @override
  State<ShopPickupPage> createState() => _ShopPickupPageState();
}

class _ShopPickupPageState extends State<ShopPickupPage> with SingleTickerProviderStateMixin {
  static const Color _g1 = Color(0xFFFF8C00);
  static const Color _g2 = Color(0xFFCC1500);

  final NumberFormat _numberFormat = NumberFormat('#,##0', 'ru');
  final _searchController = TextEditingController();
  Timer? _debounce;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  List<PvzOrder> _orders = [];
  bool _loading = true;
  String? _error;

  _RangePreset _preset = _RangePreset.today;
  late DateTime _dateFrom;
  late DateTime _dateTo;

  double get _totalSum => _orders.fold<double>(0, (sum, o) => sum + o.totalValue);

  int get _salary {
    if (_totalSum <= 0) return 0;
    final raw = _totalSum * 0.05;
    return (raw / 100).round() * 100;
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, now.day);
    _dateTo = now;
    _load();
    _searchController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), _load);
    });
    localeNotifier.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() => setState(() {});

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await PvzApi.fetchPending(
        widget.jwtToken,
        query: _searchController.text.trim(),
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
      _animCtrl.forward(from: 0);
    } on PvzApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _applyPreset(_RangePreset preset) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    DateTime from;
    switch (preset) {
      case _RangePreset.today:
        from = DateTime(now.year, now.month, now.day);
        break;
      case _RangePreset.week:
        from = now.subtract(const Duration(days: 6));
        break;
      case _RangePreset.month:
        from = DateTime(now.year, now.month, 1);
        break;
      case _RangePreset.custom:
        return;
    }
    setState(() {
      _preset = preset;
      _dateFrom = from;
      _dateTo = now;
    });
    _load();
  }

  Future<void> _pickCustomRange() async {
    HapticFeedback.selectionClick();
    final range = await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickupCustomRangeSheet(initialRange: DateTimeRange(start: _dateFrom, end: _dateTo)),
    );
    if (range == null) return;
    setState(() {
      _preset = _RangePreset.custom;
      _dateFrom = range.start;
      _dateTo = range.end;
    });
    _load();
  }

  void _openDetail(PvzOrder order) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(
        order: order,
        numberFormat: _numberFormat,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradColors = isDark ? [const Color(0xFF3D1800), const Color(0xFF1F0000)] : [_g1, _g2];
    final listBg = isDark ? Theme.of(context).colorScheme.surface : const Color(0xFFF4F4F4);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.shopPickupTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: BoxDecoration(gradient: LinearGradient(colors: gradColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
          ),
        ),
        body: Column(
          children: [
            Container(
              decoration: BoxDecoration(gradient: LinearGradient(colors: gradColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildDateFilterRow(s)),
                      const SizedBox(width: 8),
                      if (!_loading && _error == null) _CountBadge(count: _orders.length),
                    ],
                  ),
                  if (!_loading && _error == null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _HeaderStatTile(
                            icon: Icons.payments_rounded,
                            label: s.shopPickupTotalLabel,
                            value: '${_numberFormat.format(_totalSum)} сум',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _HeaderStatTile(
                            icon: Icons.account_balance_wallet_rounded,
                            label: s.shopPickupSalaryLabel,
                            value: '${_numberFormat.format(_salary)} сум',
                            highlight: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Container(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: _SearchBar(controller: _searchController, isDark: isDark, hintText: s.shopPickupSearchHint),
            ),
            Expanded(child: Container(color: listBg, child: _buildBody(isDark, s))),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterRow(S s) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _DateChip(label: s.shopIssuedToday, selected: _preset == _RangePreset.today, onTap: () => _applyPreset(_RangePreset.today)),
          const SizedBox(width: 8),
          _DateChip(label: s.shopIssuedWeek, selected: _preset == _RangePreset.week, onTap: () => _applyPreset(_RangePreset.week)),
          const SizedBox(width: 8),
          _DateChip(label: s.shopIssuedMonth, selected: _preset == _RangePreset.month, onTap: () => _applyPreset(_RangePreset.month)),
          const SizedBox(width: 8),
          _DateChip(
            label: s.shopIssuedCustomPeriod,
            icon: Icons.date_range_rounded,
            selected: _preset == _RangePreset.custom,
            onTap: _pickCustomRange,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark, S s) {
    if (_loading) return _skeleton(isDark);

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
                decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.red.shade50, shape: BoxShape.circle),
                child: Icon(Icons.wifi_off_rounded, size: 36, color: isDark ? Colors.white38 : Colors.red.shade300),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(s.refresh),
                style: FilledButton.styleFrom(backgroundColor: _g1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
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
                boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
              ),
              child: Icon(Icons.inventory_2_outlined, size: 38, color: isDark ? Colors.white38 : Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              s.shopPickupEmpty,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.grey.shade700),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _g1,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 32),
          itemCount: _orders.length,
          itemBuilder: (_, i) => StaggerIn(
            delay: Duration(milliseconds: 40 * i.clamp(0, 8)),
            child: _OrderCard(
              order: _orders[i],
              isDark: isDark,
              numberFormat: _numberFormat,
              s: s,
              onTap: () => _openDetail(_orders[i]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _skeleton(bool isDark) {
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final hi = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 32),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Shimmer.fromColors(
          baseColor: base,
          highlightColor: hi,
          child: Container(height: 108, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(14))),
        ),
      ),
    );
  }
}

// ─── Order card ───────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final PvzOrder order;
  final bool isDark;
  final NumberFormat numberFormat;
  final S s;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.isDark, required this.numberFormat, required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final cardBg = isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white;
    const accent = Color(0xFFEF6C00);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.18 : 0.05), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          // A single-side Border can't be rounded together with the
          // container's borderRadius — Flutter falls back to a sharp
          // rectangular stroke, so the accent bar pokes past the rounded
          // corners. Clipping a real colored strip keeps it flush instead.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: accent.withOpacity(0.35)),
                                ),
                                child: Text('№${order.id}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accent)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order.buyerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: onSurface),
                                ),
                              ),
                              Text(
                                '${numberFormat.format(order.totalValue)} сум',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _InfoLine(
                            icon: Icons.inventory_2_outlined,
                            text: '${order.items.length} ${s.shopPickupPositions} · ${s.shopPickupSeller}: ${order.sellerName}',
                            onSurface: onSurface,
                          ),
                          const SizedBox(height: 4),
                          _InfoLine(icon: Icons.event_rounded, text: _formatDateTime(order.createAt), onSurface: onSurface),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Center(child: Icon(Icons.chevron_right_rounded, color: onSurface.withOpacity(0.3))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color onSurface;

  const _InfoLine({required this.icon, required this.text, required this.onSurface});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: onSurface.withOpacity(0.4)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.55)),
          ),
        ),
      ],
    );
  }
}

// ─── Order detail sheet ──────────────────────────────────────────────────

class _OrderDetailSheet extends StatelessWidget {
  final PvzOrder order;
  final NumberFormat numberFormat;

  const _OrderDetailSheet({required this.order, required this.numberFormat});

  static const Color _g1 = Color(0xFFFF8C00);
  static const Color _g2 = Color(0xFFCC1500);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline = Theme.of(context).colorScheme.outline;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(color: surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: onSurface.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_g1, _g2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(s.shopPickupOrderTitle(order.id), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: onSurface)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: onSurface.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: outline.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    _DetailRow(icon: Icons.person_outline_rounded, label: s.shopPickupBuyer, value: order.buyerName, onSurface: onSurface),
                    const SizedBox(height: 8),
                    _DetailRow(icon: Icons.badge_outlined, label: s.shopPickupSeller, value: order.sellerName, onSurface: onSurface),
                    const SizedBox(height: 8),
                    _DetailRow(icon: Icons.event_rounded, label: '', value: _formatDateTime(order.createAt), onSurface: onSurface),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(s.shopPickupItemsHeader, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: onSurface)),
              const SizedBox(height: 10),
              ...order.items.map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: onSurface.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item.article} — ${item.productName}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onSurface)),
                            const SizedBox(height: 2),
                            Text(
                              '${item.color} · Размер ${item.sizeName} · ${numberFormat.format(item.amount)} шт',
                              style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.55)),
                            ),
                          ],
                        ),
                      ),
                      Text('${numberFormat.format(item.subtotal)} сум', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _g2)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_g1, _g2]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: _g2.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(s.totalLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    Text('${numberFormat.format(order.totalValue)} сум', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color onSurface;

  const _DetailRow({required this.icon, required this.label, required this.value, required this.onSurface});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: onSurface.withOpacity(0.4)),
        const SizedBox(width: 8),
        if (label.isNotEmpty) ...[
          Text(label, style: TextStyle(fontSize: 13, color: onSurface.withOpacity(0.55))),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onSurface),
          ),
        ),
      ],
    );
  }
}

// ─── Small shared widgets ─────────────────────────────────────────────────

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
      child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _DateChip({required this.label, this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(selected ? 0 : 0.32)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: selected ? _ShopPickupColors.g2 : Colors.white),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? _ShopPickupColors.g2 : Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _HeaderStatTile({required this.icon, required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? Colors.white : Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(highlight ? 0 : 0.28)),
        boxShadow: highlight ? [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 4))] : null,
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: highlight ? _ShopPickupColors.g2.withOpacity(0.12) : Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: highlight ? _ShopPickupColors.g2 : Colors.white),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: highlight ? _ShopPickupColors.g2.withOpacity(0.75) : Colors.white.withOpacity(0.85)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: highlight ? _ShopPickupColors.g2 : Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom range sheet ─────────────────────────────────────────────────

class _PickupCustomRangeSheet extends StatefulWidget {
  final DateTimeRange initialRange;

  const _PickupCustomRangeSheet({required this.initialRange});

  @override
  State<_PickupCustomRangeSheet> createState() => _PickupCustomRangeSheetState();
}

class _PickupCustomRangeSheetState extends State<_PickupCustomRangeSheet> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _from = widget.initialRange.start;
    _to = widget.initialRange.end;
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: _to,
      initialDate: _from,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: _ShopPickupColors.g2)),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: _from,
      lastDate: DateTime.now(),
      initialDate: _to,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: _ShopPickupColors.g2)),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(color: onSurface.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_ShopPickupColors.g1, _ShopPickupColors.g2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.date_range_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(s.shopIssuedCustomPeriod, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: onSurface)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _PickupDatePickerField(label: s.shopIssuedDateFrom, date: _from, onTap: _pickFrom)),
                const SizedBox(width: 12),
                Expanded(child: _PickupDatePickerField(label: s.shopIssuedDateTo, date: _to, onTap: _pickTo)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop(DateTimeRange(start: _from, end: _to));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _ShopPickupColors.g2,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(s.shopIssuedApply, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickupDatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _PickupDatePickerField({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline = Theme.of(context).colorScheme.outline;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: outline.withOpacity(0.5)),
            color: onSurface.withOpacity(0.03),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 13, color: onSurface.withOpacity(0.4)),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.55))),
                ],
              ),
              const SizedBox(height: 6),
              Text(_pickupFormatDate(date), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

String _pickupFormatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final String hintText;

  const _SearchBar({required this.controller, required this.isDark, required this.hintText});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.07) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: onSurface, fontSize: 14),
        decoration: InputDecoration(
          hintText: '$hintText...',
          hintStyle: TextStyle(color: onSurface.withOpacity(0.38), fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: onSurface.withOpacity(0.38), size: 20),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, __) => v.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: Icon(Icons.clear_rounded, size: 18, color: onSurface.withOpacity(0.4)),
                    onPressed: controller.clear,
                  ),
          ),
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
}
