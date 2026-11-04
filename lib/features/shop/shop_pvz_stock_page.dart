import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_refresh.dart';
import '../../core/widgets/app_segmented_control.dart';
import '../../core/widgets/native_segments.dart';
import '../../core/widgets/fading_header_scaffold.dart';
import '../../core/widgets/ui_blocks.dart';
import '../auth/widgets/logo_stroke_loader.dart';
import 'shop_api.dart';

enum _RangePreset { all, today, week, month, custom }

class _ShopStockColors {
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
  if (days == null)
    return _WaitStatus(
      Colors.grey.shade100,
      Colors.grey.shade600,
      Colors.grey.shade300,
      '—',
    );
  if (days <= 2) {
    return _WaitStatus(
      const Color(0xFFF0FDF4),
      const Color(0xFF166534),
      const Color(0xFF86EFAC),
      s.shopStockStatusWaiting,
    );
  }
  if (days == _overdueDaysThreshold) {
    return _WaitStatus(
      const Color(0xFFFEFCE8),
      const Color(0xFF854D0E),
      const Color(0xFFFDE68A),
      s.shopStockStatusSoon,
    );
  }
  return _WaitStatus(
    const Color(0xFFFEF2F2),
    const Color(0xFF991B1B),
    const Color(0xFFFECACA),
    s.shopStockStatusOverdue,
  );
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

class _ShopPvzStockPageState extends State<ShopPvzStockPage>
    with SingleTickerProviderStateMixin {
  final NumberFormat _numberFormat = NumberFormat('#,##0', 'ru');
  final _searchController = TextEditingController();
  bool _searching = false;

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _searchController.clear();
    });
  }

  Timer? _debounce;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  _RangePreset _preset = _RangePreset.all;
  // Bumped when the custom-range sheet is dismissed so the segmented control
  // snaps back to the real preset instead of staying on "custom".
  int _segmentsEpoch = 0;
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
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _startAfterTransition();
    _searchController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), _load);
    });
    localeNotifier.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() => setState(() {});

  // Network data landing in the middle of the route fade swaps the whole body
  // (loader -> list) and makes the app bar flicker on the first open. Wait
  // for the transition to finish first.
  void _startAfterTransition() {
    void start() {
      if (!mounted) return;
      _loadShops();
      _load();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anim = ModalRoute.of(context)?.animation;
      if (anim == null || anim.isCompleted) {
        start();
        return;
      }
      void listener(AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          anim.removeStatusListener(listener);
          start();
        }
      }

      anim.addStatusListener(listener);
    });
  }

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
    final from = await AdaptiveDatePicker.show(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: now,
      initialDate: _dateFrom ?? now,
    );
    if (from == null || !mounted) {
      setState(() => _segmentsEpoch++);
      return;
    }
    final to = await AdaptiveDatePicker.show(
      context: context,
      firstDate: from,
      lastDate: now,
      initialDate: (_dateTo != null && !_dateTo!.isBefore(from))
          ? _dateTo!
          : from,
    );
    if (to == null || !mounted) {
      setState(() => _segmentsEpoch++);
      return;
    }
    setState(() {
      _preset = _RangePreset.custom;
      _dateFrom = from;
      _dateTo = to;
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

  /// Orders open in place, several at once.
  final Set<int> _expandedOrders = {};

  void _toggleOrder(int id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_expandedOrders.remove(id)) _expandedOrders.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listBg = isDark
        ? Theme.of(context).colorScheme.surface
        : AppColors.groupedBackground;

    final visibleOrders = _overdueOnly
        ? _orders
              .where(
                (o) => (_daysSince(o.confirmedAt) ?? 0) > _overdueDaysThreshold,
              )
              .toList()
        : _orders;
    // One flat list, the longest waiting first.
    final sortedOrders = [...visibleOrders]
      ..sort(
        (a, b) => (_daysSince(b.confirmedAt) ?? -1).compareTo(
          _daysSince(a.confirmedAt) ?? -1,
        ),
      );
    final overdueCount = _orders
        .where((o) => (_daysSince(o.confirmedAt) ?? 0) > _overdueDaysThreshold)
        .length;
    final totalQty = _orders.fold<double>(0, (sum, o) => sum + o.totalAmount);
    final buyersCount = _orders
        .map((o) => o.buyerId ?? o.buyerName)
        .toSet()
        .length;

    return FadingHeaderScaffold(
      title: s.shopStockTitle,
      background: listBg,
      searching: _searching,
      onToggleSearch: _toggleSearch,
      searchController: _searchController,
      searchHint: s.shopPickupSearchHint,
      // Shop filter: a native menu next to search (check on the selected one).
      filterLabels: _shops.isNotEmpty
          ? [s.shopIssuedAllShops, for (final shop in _shops) shop.name]
          : null,
      filterSelected: _shopId == null
          ? 0
          : (_shops.indexWhere((shop) => shop.id == _shopId) + 1),
      filterActive: _shopId != null,
      onFilterSelected: (i) => _selectShop(i == 0 ? null : _shops[i - 1].id),
      // Two native segmented controls (period, all / overdue), pinned under
      // the title row.
      bottomHeight: 92,
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDateFilterRow(s),
            const SizedBox(height: 10),
            AppSegmentedControl(
              labels: [s.filterAll, s.shopStockOverdueOnly],
              selectedIndex: _overdueOnly ? 1 : 0,
              onChanged: (i) {
                if ((i == 1) != _overdueOnly) _toggleOverdueOnly();
              },
              minSegmentWidth: 0,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      body: (context, topInset) => AppRefresh(
        topOffset: topInset,
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 16),
          children: [
            if (_preset != _RangePreset.all &&
                _dateFrom != null &&
                _dateTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Center(
                  child: Text(
                    '${_stockFormatDate(_dateFrom!)} — ${_stockFormatDate(_dateTo!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            if (_loading)
              _skeleton(isDark)
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFD32F2F)),
                  ),
                ),
              )
            else ...[
              FadeTransition(
                opacity: _fadeAnim,
                child: _buildSummary(
                  s,
                  count: _orders.length,
                  qty: totalQty,
                  overdue: overdueCount,
                  buyers: buyersCount,
                ),
              ),
              const SizedBox(height: 20),
              if (sortedOrders.isEmpty)
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
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 12,
                                    ),
                                  ],
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: 34,
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          s.shopStockEmpty,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.55),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                FadeTransition(
                  opacity: _fadeAnim,
                  // One block with a flat Telegram-style list: a row per order,
                  // hairlines that start at the text.
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Theme.of(context).colorScheme.surfaceContainerHigh
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < sortedOrders.length; i++) ...[
                          if (i > 0) const _ListHairline(indent: _kTextIndent),
                          _StockOrderTile(
                            order: sortedOrders[i],
                            numberFormat: _numberFormat,
                            s: s,
                            showShop: _shopId == null && _shops.length > 1,
                            expanded: _expandedOrders.contains(
                              sortedOrders[i].id,
                            ),
                            onTap: () => _toggleOrder(sortedOrders[i].id),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterRow(S s) {
    const presets = _RangePreset.values;
    return NativeSegments(
      key: ValueKey(_segmentsEpoch),
      labels: [
        s.shopStockAllPeriod,
        s.shopIssuedToday,
        s.shopIssuedWeek,
        s.shopIssuedMonth,
        s.shopIssuedCustomPeriod,
      ],
      selectedIndex: presets.indexOf(_preset),
      onChanged: (i) => presets[i] == _RangePreset.custom
          ? _pickCustomRange()
          : _applyPreset(presets[i]),
    );
  }

  Widget _buildSummary(
    S s, {
    required int count,
    required double qty,
    required int overdue,
    required int buyers,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: s.shopStockOrdersLabel,
                value: '$count',
                icon: Icons.receipt_long_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: s.shopStockQtyLabel,
                value: _numberFormat.format(qty),
                icon: Icons.inventory_2_rounded,
              ),
            ),
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
            Expanded(
              child: _SummaryCard(
                label: s.shopStockBuyersLabel,
                value: '$buyers',
                icon: Icons.people_alt_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _skeleton(bool isDark) {
    return const Padding(
      padding: EdgeInsets.only(top: 56, bottom: 56),
      child: Center(child: LogoStrokeLoader(size: 120)),
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

// ─── Telegram-style list ─────────────────────────────────────────────────

/// Where the text of a row starts (16 padding + 44 avatar + 12 gap).
const double _kTextIndent = 72;

/// A thin line that starts at the text, like in Telegram's lists.
class _ListHairline extends StatelessWidget {
  const _ListHairline({required this.indent});

  final double indent;

  @override
  Widget build(BuildContext context) => Divider(
    height: 0.5,
    thickness: 0.5,
    indent: indent,
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
  );
}

/// One order: the buyer, then its number, positions and sum; on the right how
/// long it has been waiting (red once overdue). Tapping opens the details
/// right under the row.
class _StockOrderTile extends StatelessWidget {
  const _StockOrderTile({
    required this.order,
    required this.numberFormat,
    required this.s,
    required this.showShop,
    required this.expanded,
    required this.onTap,
  });

  final PvzOrder order;
  final NumberFormat numberFormat;
  final S s;
  final bool showShop;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final days = _daysSince(order.confirmedAt);
    final status = _waitStatus(s, days);
    final muted = TextStyle(
      fontSize: 13,
      color: onSurface.withValues(alpha: 0.5),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 9, 10, 9),
              child: Row(
                children: [
                  PersonAvatar(name: order.buyerName, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.buyerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '№${order.id} · ${order.items.length} ${s.shopPickupPositions}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted,
                        ),
                        Text(
                          '${numberFormat.format(order.totalValue)} сум',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted.copyWith(
                            fontWeight: FontWeight.w600,
                            color: onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        if (showShop)
                          Text(
                            order.shopName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: muted,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: status.bg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      days == null ? '—' : '$days ${s.shopStockDaysLabel}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: status.fg,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? _StockOrderDetails(
                  order: order,
                  numberFormat: numberFormat,
                  s: s,
                  days: days,
                  status: status,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// The opened part of an order: who and when, the goods, the total.
class _StockOrderDetails extends StatelessWidget {
  const _StockOrderDetails({
    required this.order,
    required this.numberFormat,
    required this.s,
    required this.days,
    required this.status,
  });

  final PvzOrder order;
  final NumberFormat numberFormat;
  final S s;
  final int? days;
  final _WaitStatus status;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.5);

    Widget facts(String label, String value, {Color? valueColor}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: muted)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? onSurface,
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(_kTextIndent, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          facts(s.shopPickupSeller, order.sellerName),
          facts(s.shopIssuedShopFilterTitle, order.shopName),
          facts(
            s.shopStockWaitingSince,
            order.confirmedAt != null
                ? _stockFormatDateTime(order.confirmedAt!)
                : '—',
          ),
          facts(
            s.shopStockDaysLabel,
            days == null ? '—' : '$days',
            valueColor: status.fg,
          ),
          const SizedBox(height: 6),
          const _ListHairline(indent: 0),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              s.shopPickupItemsHeader.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: muted,
              ),
            ),
          ),
          for (var i = 0; i < order.items.length; i++) ...[
            if (i > 0) const _ListHairline(indent: 0),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${order.items[i].article} — ${order.items[i].productName}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${order.items[i].color} · ${order.items[i].sizeName} · ${numberFormat.format(order.items[i].amount)} шт',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${numberFormat.format(order.items[i].subtotal)} сум',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _ShopStockColors.g2,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const _ListHairline(indent: 0),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  s.totalLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
                Text(
                  '${numberFormat.format(order.totalValue)} сум',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _ShopStockColors.g2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter chips ──────────────────────────────────────────────────────────

// ─── Summary card ────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
    this.highlightColor,
  });

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
        color: highlight
            ? hc.withOpacity(0.1)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? hc.withOpacity(0.35) : onSurface.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hc.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: hc),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: highlight ? hc : onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: onSurface.withOpacity(0.55)),
          ),
        ],
      ),
    );
  }
}

// ─── Search bar ──────────────────────────────────────────────────────────
