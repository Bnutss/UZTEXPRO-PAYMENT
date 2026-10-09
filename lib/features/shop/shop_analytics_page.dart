import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/adaptive_back_button.dart';
import '../../core/widgets/app_refresh.dart';
import '../../core/widgets/app_segmented_control.dart';
import '../../core/widgets/choice_field.dart';
import '../../core/widgets/search_toggle.dart';
import '../../core/widgets/ui_blocks.dart';
import 'shop_api.dart';

enum _RangePreset { all, today, week, month, custom }

enum _Tab { products, shops, buyers, stock }

String _pad2(int v) => v.toString().padLeft(2, '0');
String _formatDate(DateTime d) => '${_pad2(d.day)}.${_pad2(d.month)}.${d.year}';

/// Product analytics for the shop: current stock plus best-selling
/// products, best-performing shops and top buyers over a chosen period —
/// the mobile counterpart of the web "Аналитика товаров" page.
class ShopAnalyticsPage extends StatefulWidget {
  final String jwtToken;

  const ShopAnalyticsPage({super.key, required this.jwtToken});

  @override
  State<ShopAnalyticsPage> createState() => _ShopAnalyticsPageState();
}

class _ShopAnalyticsPageState extends State<ShopAnalyticsPage> {
  final NumberFormat _fmt = NumberFormat('#,##0', 'ru');
  final TextEditingController _searchCtrl = TextEditingController();

  _RangePreset _preset = _RangePreset.month;
  // Bumped when a custom range is cancelled so the segmented control snaps
  // back to the real preset instead of staying on "custom".
  int _segmentsEpoch = 0;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  List<PvzShop> _shops = [];
  int? _shopId;

  _Tab _tab = _Tab.products;
  bool _searching = false;

  ProductAnalytics? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, 1);
    _dateTo = now;
    _searchCtrl.addListener(() => setState(() {}));
    localeNotifier.addListener(_onLocaleChanged);
    _loadShops();
    _load();
  }

  void _onLocaleChanged() => setState(() {});

  @override
  void dispose() {
    _searchCtrl.dispose();
    localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  Future<void> _loadShops() async {
    try {
      final shops = await PvzApi.fetchShops(widget.jwtToken);
      if (!mounted) return;
      setState(() => _shops = shops);
    } on PvzApiException {
      // The shop filter is a convenience — the analytics still load.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final data = await PvzApi.fetchProductAnalytics(
        widget.jwtToken,
        shopId: _shopId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
      if (!mounted) return;
      setState(() => _data = data);
    } on PvzApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyPreset(_RangePreset preset) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    DateTime? from;
    DateTime? to = now;
    switch (preset) {
      case _RangePreset.all:
        to = null;
        break;
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
      initialDate: (_dateTo != null && !_dateTo!.isBefore(from)) ? _dateTo! : from,
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

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _searchCtrl.clear();
    });
  }

  void _selectTab(_Tab tab) {
    setState(() {
      _tab = tab;
      if (tab != _Tab.stock && _searching) {
        _searching = false;
        _searchCtrl.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listBg = isDark ? Theme.of(context).colorScheme.surface : AppColors.groupedBackground;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: const Center(child: AdaptiveBackButton()),
          title: Text(
            s.shopAnalyticsTitle,
            style: const TextStyle(color: kInk, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: kInk,
          elevation: 0.5,
          shadowColor: Colors.black12,
          actions: [
            if (_tab == _Tab.stock) SearchToggleButton(active: _searching, onPressed: _toggleSearch),
          ],
        ),
        body: AppRefresh(
          onRefresh: _load,
          child: Container(
            color: listBg,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  sliver: SliverList(delegate: SliverChildListDelegate(_header(s))),
                ),
                ..._content(s, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _header(S s) {
    const presets = _RangePreset.values;
    final data = _data;
    return [
      BlockCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSegmentedControl(
              key: ValueKey(_segmentsEpoch),
              labels: [
                s.shopStockAllPeriod,
                s.shopIssuedToday,
                s.shopIssuedWeek,
                s.shopIssuedMonth,
                s.shopIssuedCustomPeriod,
              ],
              selectedIndex: presets.indexOf(_preset),
              onChanged: (i) => presets[i] == _RangePreset.custom ? _pickCustomRange() : _applyPreset(presets[i]),
              minSegmentWidth: 84,
              padding: EdgeInsets.zero,
            ),
            if (_dateFrom != null && _dateTo != null) ...[
              const SizedBox(height: 6),
              Center(
                child: Text(
                  '${_formatDate(_dateFrom!)} — ${_formatDate(_dateTo!)}',
                  style: const TextStyle(fontSize: 11.5, color: kInkMuted),
                ),
              ),
            ],
            if (_shops.isNotEmpty) ...[
              const SizedBox(height: 12),
              BlockCaption(s.shopIssuedShopFilterTitle),
              ChoiceField<int?>(
                title: s.shopIssuedShopFilterTitle,
                options: [
                  ChoiceOption<int?>(null, s.shopIssuedAllShops),
                  for (final shop in _shops) ChoiceOption<int?>(shop.id, shop.name),
                ],
                selected: _shopId,
                onChanged: _selectShop,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (data != null) ...[
        BlockCard(
          child: Column(
            children: [
              MetricRow(
                flex: const [2, 3],
                metrics: [
                  Metric(s.shopIssuedAmountLabel, _fmt.format(data.soldAmount), icon: Icons.shopping_bag_outlined),
                  Metric(s.shopAnalyticsSoldSum, '${_fmt.format(data.soldValue)} сум', icon: Icons.payments_outlined, accent: true),
                ],
              ),
              const BlockDivider(),
              MetricRow(
                flex: const [2, 3],
                metrics: [
                  Metric(s.shopAnalyticsStockQty, _fmt.format(data.stockAmount), icon: Icons.inventory_2_outlined),
                  Metric(s.shopAnalyticsStockValue, '${_fmt.format(data.stockValue)} сум', icon: Icons.warehouse_outlined),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      AppSegmentedControl(
        labels: [
          s.shopAnalyticsTabProducts,
          s.shopAnalyticsTabShops,
          s.shopAnalyticsTabBuyers,
          s.shopAnalyticsTabStock,
        ],
        selectedIndex: _tab.index,
        onChanged: (i) => _selectTab(_Tab.values[i]),
        minSegmentWidth: 88,
        padding: EdgeInsets.zero,
      ),
      if (_searching && _tab == _Tab.stock) ...[
        const SizedBox(height: 10),
        _SearchField(controller: _searchCtrl, hint: s.shopAnalyticsSearchHint),
      ],
    ];
  }

  List<Widget> _content(S s, bool isDark) {
    if (_loading) return [SliverToBoxAdapter(child: _skeleton(isDark))];
    if (_error != null && _data == null) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
            child: Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFD32F2F)))),
          ),
        ),
      ];
    }
    final data = _data;
    if (data == null) return const [];

    final int count;
    final Widget Function(int) rowAt;
    switch (_tab) {
      case _Tab.products:
      case _Tab.shops:
      case _Tab.buyers:
        final rows = _tab == _Tab.products
            ? data.topProducts
            : _tab == _Tab.shops
                ? data.topShops
                : data.topBuyers;
        final maxValue = rows.fold<double>(0, (m, r) => r.totalValue > m ? r.totalValue : m);
        count = rows.length;
        rowAt = (i) => _RankRow(
              rank: i + 1,
              row: rows[i],
              kind: _tab,
              fmt: _fmt,
              share: maxValue > 0 ? rows[i].totalValue / maxValue : 0,
              ordersLabel: s.shopStockOrdersCount(rows[i].salesCount),
              pcsLabel: s.shopAnalyticsPcs,
            );
        break;
      case _Tab.stock:
        final q = _searchCtrl.text.trim().toLowerCase();
        final stock = q.isEmpty
            ? data.stock
            : data.stock.where((r) => '${r.article} ${r.name} ${r.color}'.toLowerCase().contains(q)).toList();
        count = stock.length;
        rowAt = (i) => _StockRow(row: stock[i], fmt: _fmt, showShop: _shopId == null && _shops.length > 1, pcsLabel: s.shopAnalyticsPcs);
        break;
    }

    if (count == 0) return [SliverToBoxAdapter(child: _empty(s))];
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        sliver: SliverList.builder(
          itemCount: count,
          itemBuilder: (_, i) => GroupedTile(index: i, count: count, child: rowAt(i)),
        ),
      ),
    ];
  }

  Widget _empty(S s) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.insights_rounded, size: 40, color: kInkMuted.withOpacity(0.6)),
            const SizedBox(height: 10),
            Text(s.shopAnalyticsEmpty, style: const TextStyle(color: kInkMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _skeleton(bool isDark) {
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final hi = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 280,
          decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

// ─── Widgets ───────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kInk.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: kInk, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: kInkMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: kInkMuted),
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.row,
    required this.kind,
    required this.fmt,
    required this.share,
    required this.ordersLabel,
    required this.pcsLabel,
  });

  final int rank;
  final AnalyticsRankRow row;
  final _Tab kind;
  final NumberFormat fmt;
  final double share;
  final String ordersLabel;
  final String pcsLabel;

  static const _medals = [Color(0xFFE0A100), Color(0xFF8E9AAB), Color(0xFFB87333)];

  Widget _leading() {
    switch (kind) {
      case _Tab.buyers:
        return PersonAvatar(name: row.title, size: 38);
      case _Tab.shops:
        return Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppColors.brandOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
          child: const Icon(Icons.storefront_rounded, size: 19, color: AppColors.brandOrange),
        );
      default:
        final medal = rank <= 3 ? _medals[rank - 1] : kInkMuted;
        return Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: medal.withOpacity(0.14), borderRadius: BorderRadius.circular(11)),
          child: Text('$rank', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: medal)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = [if (row.subtitle.isNotEmpty) row.subtitle, ordersLabel].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              _leading(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kInk),
                    ),
                    const SizedBox(height: 2),
                    Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: kInkMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${fmt.format(row.totalValue)} сум', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kInk)),
                  const SizedBox(height: 2),
                  Text('${fmt.format(row.totalAmount)} $pcsLabel', style: const TextStyle(fontSize: 11.5, color: kInkMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: kInk.withOpacity(0.06),
              valueColor: const AlwaysStoppedAnimation(AppColors.brandOrange),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.row, required this.fmt, required this.showShop, required this.pcsLabel});

  final AnalyticsStockRow row;
  final NumberFormat fmt;
  final bool showShop;
  final String pcsLabel;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (row.color.isNotEmpty) row.color,
      if (row.size.isNotEmpty) row.size,
      if (showShop && row.shopName.isNotEmpty) row.shopName,
    ].join(' · ');
    final empty = row.amount <= 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row.article} · ${row.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kInk),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: kInkMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${fmt.format(row.amount)} $pcsLabel',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: empty ? const Color(0xFFD32F2F) : kInk),
              ),
              const SizedBox(height: 2),
              Text('${fmt.format(row.value)} сум', style: const TextStyle(fontSize: 11.5, color: kInkMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
