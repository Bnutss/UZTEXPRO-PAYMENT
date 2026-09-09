import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/adaptive_back_button.dart';
import 'shop_api.dart';

enum _RangePreset { all, today, week, month, custom }

class _ShopStockColors {
  static const Color g1 = AppColors.brandOrange;
  static const Color g2 = AppColors.brandRed;
}

// Дни считаются от confirmed_at — момента, когда бухгалтерия подтвердила
// заказ и товар реально стал доступен для выдачи на ПВЗ, а не от даты
// оформления заказа.
int? _daysSince(DateTime? date) {
  if (date == null) return null;
  return DateTime.now().difference(date).inDays;
}

class _WaitStatus {
  const _WaitStatus(this.bg, this.fg, this.border, this.label);

  final Color bg;
  final Color fg;
  final Color border;
  final String label;
}

const int _overdueDaysThreshold = 3;

_WaitStatus _waitStatus(S s, int? days) {
  if (days == null) return _WaitStatus(Colors.grey.shade100, Colors.grey.shade600, Colors.grey.shade300, '—');
  if (days <= 2) {
    return _WaitStatus(const Color(0xFFF0FDF4), const Color(0xFF166534), const Color(0xFF86EFAC), s.shopStockStatusWaiting);
  }
  if (days == _overdueDaysThreshold) {
    return _WaitStatus(const Color(0xFFFEFCE8), const Color(0xFF854D0E), const Color(0xFFFDE68A), s.shopStockStatusSoon);
  }
  return _WaitStatus(const Color(0xFFFEF2F2), const Color(0xFF991B1B), const Color(0xFFFECACA), s.shopStockStatusOverdue);
}

class _BuyerGroup {
  _BuyerGroup({required this.buyerId, required this.buyerName, required this.orders, required this.maxDays});

  final int? buyerId;
  final String buyerName;
  final List<PvzOrder> orders;
  final int maxDays;
}

List<_BuyerGroup> _groupByBuyer(List<PvzOrder> orders) {
  final Map<int, List<PvzOrder>> byBuyer = {};
  for (final order in orders) {
    final key = order.buyerId ?? -1;
    byBuyer.putIfAbsent(key, () => []).add(order);
  }
  final groups = byBuyer.entries.map((entry) {
    final maxDays = entry.value.fold<int>(0, (max, o) {
      final d = _daysSince(o.confirmedAt) ?? 0;
      return d > max ? d : max;
    });
    return _BuyerGroup(
      buyerId: entry.key == -1 ? null : entry.key,
      buyerName: entry.value.first.buyerName,
      orders: entry.value,
      maxDays: maxDays,
    );
  }).toList();
  groups.sort((a, b) {
    final byDays = b.maxDays.compareTo(a.maxDays);
    if (byDays != 0) return byDays;
    return b.orders.length.compareTo(a.orders.length);
  });
  return groups;
}

/// "Остатки товаров ПВЗ" — orders confirmed by accounting but still sitting
/// unclaimed at a pickup point, broken down by client, flagged red once
/// they've waited more than [_overdueDaysThreshold] days since confirmation.
/// Reuses the same `/shop/sale-pending/` endpoint as [ShopPickupPage]
/// (its data is already scoped to the logged-in employee's own shop by the
/// backend); the shop filter chip row only becomes relevant for accounts
/// that can see more than one shop, mirroring [ShopIssuedReportPage].
class ShopPvzStockPage extends StatefulWidget {
  final String jwtToken;

  const ShopPvzStockPage({super.key, required this.jwtToken});

  @override
  State<ShopPvzStockPage> createState() => _ShopPvzStockPageState();
}

class _ShopPvzStockPageState extends State<ShopPvzStockPage> with SingleTickerProviderStateMixin {
  static const Color _g1 = AppColors.brandOrange;

  final NumberFormat _numberFormat = NumberFormat('#,##0', 'ru');
  final _searchController = TextEditingController();
  Timer? _debounce;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  _RangePreset _preset = _RangePreset.all;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  List<PvzShop> _shops = [];
  int? _shopId;

  bool _overdueOnly = false;

  List<PvzOrder> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadShops();
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

  Future<void> _loadShops() async {
    try {
      final shops = await PvzApi.fetchShops(widget.jwtToken);
      if (!mounted) return;
      setState(() => _shops = shops);
    } on PvzApiException {
      // Shop filter is a convenience — silently skip if it fails, the
      // list itself still loads (auto-scoped to the employee's own shop).
    }
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
        shopId: _shopId,
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
    DateTime? from;
    DateTime? to;
    switch (preset) {
      case _RangePreset.all:
        from = null;
        to = null;
        break;
      case _RangePreset.today:
        from = DateTime(now.year, now.month, now.day);
        to = now;
        break;
      case _RangePreset.week:
        from = now.subtract(const Duration(days: 6));
        to = now;
        break;
      case _RangePreset.month:
        from = DateTime(now.year, now.month, 1);
        to = now;
        break;
      case _RangePreset.custom:
        return;
    }
    setState(() {
      _preset = preset;
      _dateFrom = from;
      _dateTo = to;
    });
    _load();
  }

  Future<void> _pickCustomRange() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final range = await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StockCustomRangeSheet(initialRange: DateTimeRange(start: _dateFrom ?? now, end: _dateTo ?? now)),
    );
    if (range == null) return;
    setState(() {
      _preset = _RangePreset.custom;
      _dateFrom = range.start;
      _dateTo = range.end;
    });
    _load();
  }

  void _selectShop(int? shopId) {
    if (_shopId == shopId) return;
    HapticFeedback.selectionClick();
    setState(() => _shopId = shopId);
    _load();
  }

  void _toggleOverdueOnly() {
    HapticFeedback.selectionClick();
    setState(() => _overdueOnly = !_overdueOnly);
  }

  void _openDetail(PvzOrder order) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StockOrderDetailSheet(order: order, numberFormat: _numberFormat),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listBg = isDark ? Theme.of(context).colorScheme.surface : AppColors.groupedBackground;

    final visibleOrders = _overdueOnly
        ? _orders.where((o) => (_daysSince(o.confirmedAt) ?? 0) > _overdueDaysThreshold).toList()
        : _orders;
    final groups = _groupByBuyer(visibleOrders);
    final overdueCount = _orders.where((o) => (_daysSince(o.confirmedAt) ?? 0) > _overdueDaysThreshold).length;
    final totalQty = _orders.fold<double>(0, (sum, o) => sum + o.totalAmount);
    final buyersCount = _orders.map((o) => o.buyerId ?? o.buyerName).toSet().length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: const Center(child: AdaptiveBackButton()),
          title: Text(s.shopStockTitle, style: const TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1C1C1E),
          elevation: 0.5,
          shadowColor: Colors.black12,
        ),
        body: RefreshIndicator(
          color: _g1,
          onRefresh: _load,
          child: Container(
            color: listBg,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildDateFilterRow(s),
                if (_preset != _RangePreset.all) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '${_stockFormatDate(_dateFrom!)} — ${_stockFormatDate(_dateTo!)}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _SearchBar(controller: _searchController, isDark: isDark, hintText: s.shopPickupSearchHint),
                if (_shops.length > 1) ...[
                  const SizedBox(height: 14),
                  _buildShopFilterRow(s, isDark),
                ],
                const SizedBox(height: 10),
                _ToggleChip(label: s.shopStockOverdueOnly, selected: _overdueOnly, isDark: isDark, onTap: _toggleOverdueOnly),
                const SizedBox(height: 18),
                if (_loading)
                  _skeleton(isDark)
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFD32F2F)))),
                  )
                else ...[
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: _buildSummary(s, count: _orders.length, qty: totalQty, overdue: overdueCount, buyers: buyersCount),
                  ),
                  const SizedBox(height: 20),
                  if (groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
                              ),
                              child: Icon(Icons.inventory_2_outlined, size: 34, color: isDark ? Colors.white38 : Colors.grey.shade400),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              s.shopStockEmpty,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          for (final group in groups) ...[
                            _BuyerGroupHeader(group: group, s: s, isDark: isDark),
                            const SizedBox(height: 8),
                            for (final order in group.orders)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _StockOrderTile(
                                  order: order,
                                  isDark: isDark,
                                  numberFormat: _numberFormat,
                                  s: s,
                                  showShop: _shopId == null && _shops.length > 1,
                                  onTap: () => _openDetail(order),
                                ),
                              ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterRow(S s) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _RangeChip(label: s.shopStockAllPeriod, selected: _preset == _RangePreset.all, onTap: () => _applyPreset(_RangePreset.all)),
          const SizedBox(width: 8),
          _RangeChip(label: s.shopIssuedToday, selected: _preset == _RangePreset.today, onTap: () => _applyPreset(_RangePreset.today)),
          const SizedBox(width: 8),
          _RangeChip(label: s.shopIssuedWeek, selected: _preset == _RangePreset.week, onTap: () => _applyPreset(_RangePreset.week)),
          const SizedBox(width: 8),
          _RangeChip(label: s.shopIssuedMonth, selected: _preset == _RangePreset.month, onTap: () => _applyPreset(_RangePreset.month)),
          const SizedBox(width: 8),
          _RangeChip(
            label: s.shopIssuedCustomPeriod,
            icon: Icons.date_range_rounded,
            selected: _preset == _RangePreset.custom,
            onTap: _pickCustomRange,
          ),
        ],
      ),
    );
  }

  Widget _buildShopFilterRow(S s, bool isDark) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _ShopChip(label: s.shopIssuedAllShops, selected: _shopId == null, isDark: isDark, onTap: () => _selectShop(null)),
          for (final shop in _shops) ...[
            const SizedBox(width: 8),
            _ShopChip(label: shop.name, selected: _shopId == shop.id, isDark: isDark, onTap: () => _selectShop(shop.id)),
          ],
        ],
      ),
    );
  }

  Widget _buildSummary(S s, {required int count, required double qty, required int overdue, required int buyers}) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _SummaryCard(label: s.shopStockOrdersLabel, value: '$count', icon: Icons.receipt_long_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _SummaryCard(label: s.shopStockQtyLabel, value: _numberFormat.format(qty), icon: Icons.inventory_2_rounded)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: s.shopStockOverdueLabel,
                value: '$overdue',
                icon: Icons.warning_amber_rounded,
                highlight: overdue > 0,
                highlightColor: const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _SummaryCard(label: s.shopStockBuyersLabel, value: '$buyers', icon: Icons.people_alt_rounded)),
          ],
        ),
      ],
    );
  }

  Widget _skeleton(bool isDark) {
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final hi = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    Widget block({double height = 88, double? width}) => Container(
      height: height,
      width: width,
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(16)),
    );
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: block(height: 72)),
              const SizedBox(width: 10),
              Expanded(child: block(height: 72)),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < 4; i++) Padding(padding: const EdgeInsets.only(bottom: 8), child: block()),
        ],
      ),
    );
  }
}

String _stockFormatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}

String _stockFormatDateTime(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
}

// ─── Buyer group header ─────────────────────────────────────────────────

class _BuyerGroupHeader extends StatelessWidget {
  const _BuyerGroupHeader({required this.group, required this.s, required this.isDark});

  final _BuyerGroup group;
  final S s;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final hasOverdue = group.maxDays > _overdueDaysThreshold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: onSurface.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _ShopStockColors.g2.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.person_rounded, size: 15, color: _ShopStockColors.g2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              group.buyerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: onSurface),
            ),
          ),
          const SizedBox(width: 8),
          Text(s.shopStockOrdersCount(group.orders.length), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: onSurface.withOpacity(0.5))),
          if (hasOverdue) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFECACA))),
              child: Text(s.shopStockGroupBadge, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF991B1B))),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Order tile ──────────────────────────────────────────────────────────

class _StockOrderTile extends StatelessWidget {
  const _StockOrderTile({
    required this.order,
    required this.isDark,
    required this.numberFormat,
    required this.s,
    required this.showShop,
    required this.onTap,
  });

  final PvzOrder order;
  final bool isDark;
  final NumberFormat numberFormat;
  final S s;
  final bool showShop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final cardBg = isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white;
    final days = _daysSince(order.confirmedAt);
    final status = _waitStatus(s, days);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.18 : 0.05), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: status.border),
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
                                  color: status.bg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: status.border),
                                ),
                                child: Text('№${order.id}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: status.fg)),
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: status.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: status.border)),
                                child: Text(
                                  days == null ? '—' : '$days ${s.shopStockDaysLabel}',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: status.fg),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _StockInfoLine(
                            icon: Icons.inventory_2_outlined,
                            text: '${order.items.length} ${s.shopPickupPositions} · ${numberFormat.format(order.totalValue)} сум',
                            onSurface: onSurface,
                          ),
                          const SizedBox(height: 4),
                          if (showShop) ...[
                            _StockInfoLine(icon: Icons.storefront_rounded, text: order.shopName, onSurface: onSurface),
                            const SizedBox(height: 4),
                          ],
                          _StockInfoLine(
                            icon: Icons.event_available_rounded,
                            text: order.confirmedAt != null ? _stockFormatDateTime(order.confirmedAt!) : '—',
                            onSurface: onSurface,
                          ),
                        ],
                      ),
                    ),
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

class _StockInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color onSurface;

  const _StockInfoLine({required this.icon, required this.text, required this.onSurface});

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

// ─── Order detail sheet ────────────────────────────────────────────────

class _StockOrderDetailSheet extends StatelessWidget {
  const _StockOrderDetailSheet({required this.order, required this.numberFormat});

  final PvzOrder order;
  final NumberFormat numberFormat;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline = Theme.of(context).colorScheme.outline;
    final days = _daysSince(order.confirmedAt);
    final status = _waitStatus(s, days);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
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
              if (order.buyerPhotoUrl != null) _StockPhotoPreview(photoUrl: order.buyerPhotoUrl!, heroTag: 'stock_order_photo_${order.id}'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: status.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: status.border)),
                    child: Icon(Icons.local_shipping_rounded, color: status.fg, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(s.shopPickupOrderTitle(order.id), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: onSurface)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: status.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: status.border)),
                    child: Text(status.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: status.fg)),
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
                    _StockDetailRow(icon: Icons.person_outline_rounded, label: s.shopPickupBuyer, value: order.buyerName, onSurface: onSurface),
                    const SizedBox(height: 8),
                    _StockDetailRow(icon: Icons.badge_outlined, label: s.shopPickupSeller, value: order.sellerName, onSurface: onSurface),
                    const SizedBox(height: 8),
                    _StockDetailRow(icon: Icons.storefront_outlined, label: s.shopIssuedShopFilterTitle, value: order.shopName, onSurface: onSurface),
                    const SizedBox(height: 8),
                    _StockDetailRow(
                      icon: Icons.event_available_rounded,
                      label: s.shopStockWaitingSince,
                      value: order.confirmedAt != null ? _stockFormatDateTime(order.confirmedAt!) : '—',
                      onSurface: onSurface,
                    ),
                    const SizedBox(height: 8),
                    _StockDetailRow(
                      icon: Icons.hourglass_bottom_rounded,
                      label: s.shopStockDaysLabel,
                      value: days == null ? '—' : '$days',
                      onSurface: onSurface,
                    ),
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
                      Text(
                        '${numberFormat.format(item.subtotal)} сум',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ShopStockColors.g2),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_ShopStockColors.g1, _ShopStockColors.g2]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: _ShopStockColors.g2.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(s.totalLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    Text(
                      '${numberFormat.format(order.totalValue)} сум',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
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

class _StockDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color onSurface;

  const _StockDetailRow({required this.icon, required this.label, required this.value, required this.onSurface});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: onSurface.withOpacity(0.4)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, color: onSurface.withOpacity(0.55))),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onSurface),
          ),
        ),
      ],
    );
  }
}

class _StockPhotoPreview extends StatelessWidget {
  const _StockPhotoPreview({required this.photoUrl, required this.heroTag});

  final String photoUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _StockFullScreenPhotoView(photoUrl: photoUrl, heroTag: heroTag), fullscreenDialog: true),
        ),
        child: Container(
          width: 128,
          height: 168,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Hero(tag: heroTag, child: Image.network(photoUrl, fit: BoxFit.cover)),
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                  child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockFullScreenPhotoView extends StatelessWidget {
  const _StockFullScreenPhotoView({required this.photoUrl, required this.heroTag});

  final String photoUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Hero(tag: heroTag, child: Image.network(photoUrl)),
        ),
      ),
    );
  }
}

// ─── Custom range sheet ─────────────────────────────────────────────────

class _StockCustomRangeSheet extends StatefulWidget {
  final DateTimeRange initialRange;

  const _StockCustomRangeSheet({required this.initialRange});

  @override
  State<_StockCustomRangeSheet> createState() => _StockCustomRangeSheetState();
}

class _StockCustomRangeSheetState extends State<_StockCustomRangeSheet> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _from = widget.initialRange.start;
    _to = widget.initialRange.end;
  }

  Future<void> _pickFrom() async {
    final picked = await AdaptiveDatePicker.show(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: _to,
      initialDate: _from,
    );
    if (picked == null || !mounted) return;
    setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await AdaptiveDatePicker.show(
      context: context,
      firstDate: _from,
      lastDate: DateTime.now(),
      initialDate: _to,
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
                    gradient: const LinearGradient(colors: [_ShopStockColors.g1, _ShopStockColors.g2], begin: Alignment.topLeft, end: Alignment.bottomRight),
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
                Expanded(child: _StockDatePickerField(label: s.shopIssuedDateFrom, date: _from, onTap: _pickFrom)),
                const SizedBox(width: 12),
                Expanded(child: _StockDatePickerField(label: s.shopIssuedDateTo, date: _to, onTap: _pickTo)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: AdaptiveButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop(DateTimeRange(start: _from, end: _to));
                },
                label: s.shopIssuedApply,
                style: AdaptiveButtonStyle.filled,
                color: _ShopStockColors.g2,
                textColor: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockDatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _StockDatePickerField({required this.label, required this.date, required this.onTap});

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
              Text(_stockFormatDate(date), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Filter chips ──────────────────────────────────────────────────────────

class _RangeChip extends StatelessWidget {
  const _RangeChip({required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected ? const LinearGradient(colors: [_ShopStockColors.g1, _ShopStockColors.g2]) : null,
            color: selected ? null : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? Colors.transparent : onSurface.withOpacity(0.15)),
            boxShadow: selected ? [BoxShadow(color: _ShopStockColors.g2.withOpacity(0.28), blurRadius: 8, offset: const Offset(0, 2))] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: selected ? Colors.white : onSurface.withOpacity(0.6)),
                const SizedBox(width: 6),
              ],
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.label, required this.selected, required this.isDark, required this.onTap});

  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDC2626) : (isDark ? Colors.white.withOpacity(0.07) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFFDC2626) : (isDark ? Colors.white12 : Colors.grey.shade200)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              size: 15,
              color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade600),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopChip extends StatelessWidget {
  const _ShopChip({required this.label, required this.selected, required this.isDark, required this.onTap});

  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _ShopStockColors.g2 : (isDark ? Colors.white.withOpacity(0.07) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _ShopStockColors.g2 : (isDark ? Colors.white12 : Colors.grey.shade200)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!selected)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: _ShopStockColors.g1),
              ),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary card ────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.icon, this.highlight = false, this.highlightColor});

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final hc = highlightColor ?? _ShopStockColors.g2;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? hc.withOpacity(0.1) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlight ? hc.withOpacity(0.35) : onSurface.withOpacity(0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: hc.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: hc),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: highlight ? hc : onSurface),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: onSurface.withOpacity(0.55))),
        ],
      ),
    );
  }
}

// ─── Search bar ──────────────────────────────────────────────────────────

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
        color: isDark ? Colors.white.withOpacity(0.07) : Colors.white,
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
                : IconButton(icon: Icon(Icons.clear_rounded, size: 18, color: onSurface.withOpacity(0.4)), onPressed: controller.clear),
          ),
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
