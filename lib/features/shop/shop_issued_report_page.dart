import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/adaptive_back_button.dart';
import '../../core/widgets/app_refresh.dart';
import '../../core/widgets/block_search_field.dart';
import '../../core/widgets/search_toggle.dart';
import '../../core/widgets/app_segmented_control.dart';
import '../../core/widgets/choice_field.dart';
import '../../core/widgets/ui_blocks.dart';
import '../auth/widgets/logo_stroke_loader.dart';
import 'shop_api.dart';

enum _RangePreset { today, week, month, custom }

String _pad2(int v) => v.toString().padLeft(2, '0');
String _formatDate(DateTime d) => '${_pad2(d.day)}.${_pad2(d.month)}.${d.year}';
String _formatDateTime(DateTime d) => '${_formatDate(d)}, ${_pad2(d.hour)}:${_pad2(d.minute)}';

/// Management overview of orders handed over across all shops, with a
/// date-range and per-shop filter and a running total.
class ShopIssuedReportPage extends StatefulWidget {
  final String jwtToken;

  const ShopIssuedReportPage({super.key, required this.jwtToken});

  @override
  State<ShopIssuedReportPage> createState() => _ShopIssuedReportPageState();
}

class _ShopIssuedReportPageState extends State<ShopIssuedReportPage> with SingleTickerProviderStateMixin {

  final NumberFormat _numberFormat = NumberFormat('#,##0', 'ru');

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  _RangePreset _preset = _RangePreset.month;
  // Bumped when the custom-range sheet is dismissed so the segmented control
  // snaps back to the real preset instead of staying on "custom".
  int _segmentsEpoch = 0;

  // 'all' | 'issued' | 'pending' — only narrows the list and the totals
  // computed from it; the server always returns every confirmed order.
  String _statusFilter = 'all';

  // Buyer groups start collapsed; keyed by buyerId (-1 = unknown buyer).
  final Set<int> _expandedBuyers = {};

  late final Map<String, String> _imgHeaders = PvzApi.imageHeaders(widget.jwtToken);
  late DateTime _dateFrom;
  late DateTime _dateTo;

  final TextEditingController _searchCtrl = TextEditingController();
  bool _searching = false;

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _searchCtrl.clear();
    });
  }

  List<PvzShop> _shops = [];
  int? _shopId;

  PvzIssuedReport? _report;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, 1);
    _dateTo = now;
    _searchCtrl.addListener(() => setState(() {}));
    _loadShops();
    _load();
    localeNotifier.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() => setState(() {});

  @override
  void dispose() {
    _animCtrl.dispose();
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
      // Shop filter is a convenience — silently skip if it fails, the
      // report itself still loads without it.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await PvzApi.fetchIssuedReport(
        widget.jwtToken,
        shopId: _shopId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
      if (!mounted) return;
      setState(() => _report = report);
      _animCtrl.forward(from: 0);
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
      builder: (_) => _CustomRangeSheet(initialRange: DateTimeRange(start: _dateFrom, end: _dateTo)),
    );
    if (range == null) {
      setState(() => _segmentsEpoch++);
      return;
    }
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

  void _toggleBuyer(int key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_expandedBuyers.remove(key)) _expandedBuyers.add(key);
    });
  }

  void _openDetail(PvzOrder order) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _IssuedOrderDetailSheet(order: order, numberFormat: _numberFormat),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listBg = isDark ? Theme.of(context).colorScheme.surface : AppColors.groupedBackground;
    final report = _report;
    final visible = (report?.sales ?? const <PvzOrder>[]).where((o) {
      switch (_statusFilter) {
        case 'issued':
          return o.isIssued;
        case 'pending':
          return !o.isIssued;
        default:
          return true;
      }
    }).where((o) {
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      final hay = StringBuffer('${o.buyerName} ${o.id}');
      for (final it in o.items) {
        hay.write(' ${it.article} ${it.productName} ${it.color}');
      }
      return hay.toString().toLowerCase().contains(q);
    }).toList();
    final groups = _groupByBuyer(visible);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: const Center(child: AdaptiveBackButton()),
          title: Text(s.shopIssuedTitle, style: const TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: false,
          backgroundColor: isDark ? Theme.of(context).colorScheme.surface : AppColors.groupedBackground,
          foregroundColor: const Color(0xFF1C1C1E),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          actions: [SearchToggleButton(active: _searching, onPressed: _toggleSearch)],
        ),
        body: AppRefresh(
          onRefresh: _load,
          child: Container(
            color: listBg,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                BlockCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDateFilterRow(s),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          '${_formatDate(_dateFrom)} — ${_formatDate(_dateTo)}',
                          style: const TextStyle(fontSize: 11.5, color: kInkMuted),
                        ),
                      ),
                      if (_shops.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        BlockCaption(s.shopIssuedShopFilterTitle),
                        _buildShopFilterRow(s, isDark),
                      ],
                      const SizedBox(height: 12),
                      AppSegmentedControl(
                        labels: [s.filterAll, s.shopIssuedStatusIssued, s.shopIssuedStatusPending],
                        selectedIndex: const ['all', 'issued', 'pending'].indexOf(_statusFilter),
                        onChanged: (i) => setState(() => _statusFilter = const ['all', 'issued', 'pending'][i]),
                        minSegmentWidth: 0,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                if (_searching) ...[
                  const SizedBox(height: 10),
                  BlockSearchField(controller: _searchCtrl, hint: s.shopIssuedSearchHint),
                ],
                const SizedBox(height: 12),
                if (_loading)
                  _skeleton(isDark)
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFD32F2F)))),
                  )
                else if (report != null) ...[
                  FadeTransition(opacity: _fadeAnim, child: _buildSummary(s, visible)),
                  const SizedBox(height: 18),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 28),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.checklist_rtl_rounded, size: 40, color: kInkMuted.withOpacity(0.6)),
                            const SizedBox(height: 10),
                            Text(s.shopIssuedEmpty, textAlign: TextAlign.center, style: const TextStyle(color: kInkMuted, fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  else
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BlockCaption(
                            s.shopAnalyticsTabBuyers,
                            trailing: Text('${groups.length}', style: const TextStyle(fontSize: 11.5, color: kInkMuted, fontWeight: FontWeight.w600)),
                          ),
                          BlockCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (final (i, group) in groups.indexed) ...[
                                  if (i > 0) const Divider(height: 1, thickness: 0.6, indent: 64),
                                  _IssuedBuyerHeader(
                                    group: group,
                                    imgHeaders: _imgHeaders,
                                    numberFormat: _numberFormat,
                                    s: s,
                                    expanded: _expandedBuyers.contains(group.key),
                                    onTap: () => _toggleBuyer(group.key),
                                  ),
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    alignment: Alignment.topCenter,
                                    child: _expandedBuyers.contains(group.key)
                                        ? Container(
                                            color: kInk.withOpacity(0.025),
                                            child: Column(
                                              children: [
                                                for (final (j, order) in group.orders.indexed) ...[
                                                  if (j > 0) const Divider(height: 1, thickness: 0.6, indent: 64),
                                                  _IssuedOrderRow(
                                                    order: order,
                                                    imgHeaders: _imgHeaders,
                                                                    numberFormat: _numberFormat,
                                                    s: s,
                                                    showShop: _shopId == null && _shops.length > 1,
                                                    onTap: () => _openDetail(order),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          )
                                        : const SizedBox(width: double.infinity),
                                  ),
                                ],
                              ],
                            ),
                          ),
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
    const presets = _RangePreset.values;
    return AppSegmentedControl(
      key: ValueKey(_segmentsEpoch),
      labels: [
        s.shopIssuedToday,
        s.shopIssuedWeek,
        s.shopIssuedMonth,
        s.shopIssuedCustomPeriod,
      ],
      selectedIndex: presets.indexOf(_preset),
      onChanged: (i) => presets[i] == _RangePreset.custom
          ? _pickCustomRange()
          : _applyPreset(presets[i]),
      minSegmentWidth: 80,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildShopFilterRow(S s, bool isDark) {
    return ChoiceField<int?>(
      title: s.shopIssuedShopFilterTitle,
      options: [
        ChoiceOption<int?>(null, s.shopIssuedAllShops),
        for (final shop in _shops) ChoiceOption<int?>(shop.id, shop.name),
      ],
      selected: _shopId,
      onChanged: _selectShop,
    );
  }

  Widget _buildSummary(S s, List<PvzOrder> orders) {
    final totalAmount = orders.fold<double>(0, (sum, o) => sum + o.totalAmount);
    final totalValue = orders.fold<double>(0, (sum, o) => sum + o.totalValue);
    return BlockCard(
      child: Column(
        children: [
          MetricRow(
            flex: const [2, 2, 3],
            metrics: [
              Metric(s.shopIssuedCountLabel, '${orders.length}'),
              Metric(s.shopIssuedAmountLabel, _numberFormat.format(totalAmount)),
              Metric(s.shopIssuedValueLabel, _numberFormat.format(totalValue)),
            ],
          ),
          const BlockDivider(),
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: AppColors.brandRed.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.account_balance_wallet_rounded, size: 15, color: AppColors.brandRed),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(s.shopPickupSalaryLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kInk))),
              Text(
                '${_numberFormat.format(pvzSellerSalary(totalValue))} сум',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.brandRed),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _skeleton(bool isDark) {
    return const Padding(
      padding: EdgeInsets.only(top: 56, bottom: 56),
      child: Center(child: LogoStrokeLoader(size: 120)),
    );
  }
}

// ─── Custom range sheet ─────────────────────────────────────────────────
//
// showDateRangePicker's own calendar dialog is full-screen on phones in
// portrait (Material has no compact variant of it) — a single-date picker
// dialog is compact, so a from/to pair of those inside our own bottom
// sheet gives the same result without taking over the whole screen.

class _CustomRangeSheet extends StatefulWidget {
  final DateTimeRange initialRange;

  const _CustomRangeSheet({required this.initialRange});

  @override
  State<_CustomRangeSheet> createState() => _CustomRangeSheetState();
}

class _CustomRangeSheetState extends State<_CustomRangeSheet> {
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
                    gradient: const LinearGradient(
                      colors: [_ShopIssuedReportPageColors.g1, _ShopIssuedReportPageColors.g2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
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
                Expanded(
                  child: _DatePickerField(label: s.shopIssuedDateFrom, date: _from, onTap: _pickFrom),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePickerField(label: s.shopIssuedDateTo, date: _to, onTap: _pickTo),
                ),
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
                color: _ShopIssuedReportPageColors.g2,
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

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DatePickerField({required this.label, required this.date, required this.onTap});

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
              Text(_formatDate(date), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopIssuedReportPageColors {
  static const Color g1 = AppColors.brandOrange;
  static const Color g2 = AppColors.brandRed;
}

// ─── Buyer groups ────────────────────────────────────────────────────────

class _IssuedBuyerGroup {
  _IssuedBuyerGroup(this.key, this.name) : orders = [];

  final int key;
  final String name;
  final List<PvzOrder> orders;

  double get totalValue => orders.fold(0, (sum, o) => sum + o.totalValue);

  int get pendingCount => orders.where((o) => !o.isIssued).length;

  /// Photo candidates, best first: the buyer's profile photo, the latest
  /// hand-over snapshot (orders arrive newest-first), then their access photo.
  List<PhotoSource> photoSources(Map<String, String> imgHeaders) {
    final sources = <PhotoSource>[];
    for (final o in orders) {
      if (o.buyerAvatarUrl != null) {
        sources.add(PhotoSource(o.buyerAvatarUrl!));
        break;
      }
    }
    for (final o in orders) {
      if (o.isIssued && o.buyerPhotoUrl != null) {
        sources.add(PhotoSource(o.buyerPhotoUrl!));
        break;
      }
    }
    if (key > 0) sources.add(PhotoSource(PvzApi.buyerFaceUrl(key), headers: imgHeaders));
    return sources;
  }
}

/// Groups orders by buyer, keeping the server's newest-first order for both
/// the groups (by their latest order) and the orders inside each one.
List<_IssuedBuyerGroup> _groupByBuyer(List<PvzOrder> orders) {
  final groups = <int, _IssuedBuyerGroup>{};
  for (final order in orders) {
    final key = order.buyerId ?? -1;
    groups.putIfAbsent(key, () => _IssuedBuyerGroup(key, order.buyerName)).orders.add(order);
  }
  return groups.values.toList();
}

class _IssuedBuyerHeader extends StatelessWidget {
  const _IssuedBuyerHeader({
    required this.group,
    required this.imgHeaders,
    required this.numberFormat,
    required this.s,
    required this.expanded,
    required this.onTap,
  });

  final _IssuedBuyerGroup group;
  final Map<String, String> imgHeaders;
  final NumberFormat numberFormat;
  final S s;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              PersonAvatar(
                name: group.name,
                sources: group.photoSources(imgHeaders),
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kInk),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.shopStockOrdersCount(group.orders.length)} · ${numberFormat.format(group.totalValue)} сум',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: kInkMuted),
                    ),
                  ],
                ),
              ),
              if (group.pendingCount > 0) ...[
                StatusTag('${group.pendingCount}', color: const Color(0xFFE08A00)),
                const SizedBox(width: 6),
              ],
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: kInkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Order row ───────────────────────────────────────────────────────────

class _IssuedOrderRow extends StatelessWidget {
  const _IssuedOrderRow({
    required this.order,
    required this.imgHeaders,
    required this.numberFormat,
    required this.s,
    required this.showShop,
    required this.onTap,
  });

  final PvzOrder order;
  final Map<String, String> imgHeaders;
  final NumberFormat numberFormat;
  final S s;
  final bool showShop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const issuedColor = Color(0xFF2E7D32);
    const pendingColor = Color(0xFFE08A00);
    final color = order.isIssued ? issuedColor : pendingColor;
    // The hand-over photo only exists once the order is picked up.
    final when = order.isIssued ? order.issuedAt : order.confirmedAt;

    Widget placeholder() => _thumbPlaceholder(
          order.isIssued ? Icons.person_rounded : Icons.hourglass_top_rounded,
          order.isIssued ? kInkMuted : pendingColor,
          order.isIssued ? kInk.withOpacity(0.06) : pendingColor.withOpacity(0.12),
        );

    // Profile photo, then the hand-over snapshot, then the access photo.
    Widget photo() {
      final sources = <PhotoSource>[
        if (order.buyerAvatarUrl != null) PhotoSource(order.buyerAvatarUrl!),
        if (order.isIssued && order.buyerPhotoUrl != null) PhotoSource(order.buyerPhotoUrl!),
        if (order.buyerId != null) PhotoSource(PvzApi.buyerFaceUrl(order.buyerId!), headers: imgHeaders),
      ];
      if (sources.isEmpty) return placeholder();
      return FallbackNetworkImage(sources: sources, width: 40, height: 40, placeholder: placeholder);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: photo(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '№${order.id}${when != null ? ' · ${_formatDateTime(when)}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kInk),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        StatusTag(order.isIssued ? s.shopIssuedBadgeIssued : s.shopIssuedWaitingBadge, color: color),
                        if (showShop && order.shopName.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              order.shopName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: kInkMuted),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${numberFormat.format(order.totalValue)} сум',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _thumbPlaceholder(IconData icon, Color iconColor, Color bg) => Container(
      color: bg,
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: iconColor),
    );

// ─── Order detail sheet ────────────────────────────────────────────────

class _IssuedOrderDetailSheet extends StatelessWidget {
  const _IssuedOrderDetailSheet({required this.order, required this.numberFormat});

  final PvzOrder order;
  final NumberFormat numberFormat;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline = Theme.of(context).colorScheme.outline;

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
              if (order.isIssued && order.buyerPhotoUrl != null) _PhotoPreview(photoUrl: order.buyerPhotoUrl!, heroTag: 'issued_order_photo_${order.id}'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (order.isIssued ? const Color(0xFF2E7D32) : const Color(0xFFE08A00)).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      order.isIssued ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                      color: order.isIssued ? const Color(0xFF2E7D32) : const Color(0xFFE08A00),
                      size: 20,
                    ),
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
                    _DetailRow(icon: Icons.storefront_outlined, label: s.shopIssuedShopFilterTitle, value: order.shopName, onSurface: onSurface),
                    if (order.issuedByName != null) ...[
                      const SizedBox(height: 8),
                      _DetailRow(icon: Icons.how_to_reg_rounded, label: s.shopIssuedIssuedBy, value: order.issuedByName!, onSurface: onSurface),
                    ],
                    if (order.issuedAt != null) ...[
                      const SizedBox(height: 8),
                      _DetailRow(icon: Icons.event_available_rounded, label: s.shopIssuedIssuedAt, value: _formatDateTime(order.issuedAt!), onSurface: onSurface),
                    ],
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
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ShopIssuedReportPageColors.g2),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_ShopIssuedReportPageColors.g1, _ShopIssuedReportPageColors.g2]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: _ShopIssuedReportPageColors.g2.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6))],
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

// ─── Photo preview (tap to zoom) ───────────────────────────────────────

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.photoUrl, required this.heroTag});

  final String photoUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _FullScreenPhotoView(photoUrl: photoUrl, heroTag: heroTag), fullscreenDialog: true),
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

class _FullScreenPhotoView extends StatelessWidget {
  const _FullScreenPhotoView({required this.photoUrl, required this.heroTag});

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
