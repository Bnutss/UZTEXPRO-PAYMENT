import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
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

class _ShopIssuedReportPageState extends State<ShopIssuedReportPage> {
  static const Color _g1 = Color(0xFFFF8C00);
  static const Color _g2 = Color(0xFFCC1500);

  final NumberFormat _numberFormat = NumberFormat('#,##0', 'ru');

  _RangePreset _preset = _RangePreset.month;
  late DateTime _dateFrom;
  late DateTime _dateTo;

  List<PvzShop> _shops = [];
  int? _shopId;

  PvzIssuedReport? _report;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, 1);
    _dateTo = now;
    _loadShops();
    _load();
    localeNotifier.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() => setState(() {});

  @override
  void dispose() {
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
    } on PvzApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyPreset(_RangePreset preset) {
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
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _dateFrom, end: _dateTo),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: _g2)),
        child: child!,
      ),
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
    setState(() => _shopId = shopId);
    _load();
  }

  void _openDetail(PvzOrder order) {
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
    final gradColors = isDark ? [const Color(0xFF3D1800), const Color(0xFF1F0000)] : [_g1, _g2];
    final listBg = isDark ? Theme.of(context).colorScheme.surface : const Color(0xFFF4F4F4);
    final report = _report;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.shopIssuedTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: BoxDecoration(gradient: LinearGradient(colors: gradColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
          ),
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
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '${_formatDate(_dateFrom)} — ${_formatDate(_dateTo)}',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  ),
                ),
                if (_shops.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildShopFilterRow(s, isDark),
                ],
                const SizedBox(height: 18),
                if (_loading)
                  const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator(color: _g1)))
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFD32F2F)))),
                  )
                else if (report != null) ...[
                  _buildSummary(s, report),
                  const SizedBox(height: 20),
                  if (report.sales.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(s.shopIssuedEmpty, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                      ),
                    )
                  else
                    ...report.sales.map(
                      (order) => _IssuedOrderTile(
                        order: order,
                        isDark: isDark,
                        numberFormat: _numberFormat,
                        s: s,
                        showShop: _shopId == null,
                        onTap: () => _openDetail(order),
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
          _FilterChip(label: s.shopIssuedToday, selected: _preset == _RangePreset.today, onTap: () => _applyPreset(_RangePreset.today)),
          const SizedBox(width: 8),
          _FilterChip(label: s.shopIssuedWeek, selected: _preset == _RangePreset.week, onTap: () => _applyPreset(_RangePreset.week)),
          const SizedBox(width: 8),
          _FilterChip(label: s.shopIssuedMonth, selected: _preset == _RangePreset.month, onTap: () => _applyPreset(_RangePreset.month)),
          const SizedBox(width: 8),
          _FilterChip(
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

  Widget _buildSummary(S s, PvzIssuedReport report) {
    return Row(
      children: [
        Expanded(child: _SummaryCard(label: s.shopIssuedCountLabel, value: '${report.salesCount}', icon: Icons.receipt_long_rounded)),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: s.shopIssuedAmountLabel,
            value: _numberFormat.format(report.totalAmount),
            icon: Icons.inventory_2_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _SummaryCard(
            label: s.shopIssuedValueLabel,
            value: _numberFormat.format(report.totalValue),
            icon: Icons.payments_rounded,
            highlight: true,
          ),
        ),
      ],
    );
  }
}

// ─── Filter chips ──────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.icon});

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
            gradient: selected
                ? const LinearGradient(colors: [_ShopIssuedReportPageColors.g1, _ShopIssuedReportPageColors.g2])
                : null,
            color: selected ? null : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? Colors.transparent : onSurface.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: selected ? Colors.white : onSurface.withOpacity(0.6)),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : onSurface),
              ),
            ],
          ),
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
          color: selected ? _ShopIssuedReportPageColors.g2 : (isDark ? Colors.white.withOpacity(0.07) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _ShopIssuedReportPageColors.g2 : (isDark ? Colors.white12 : Colors.grey.shade200)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }
}

class _ShopIssuedReportPageColors {
  static const Color g1 = Color(0xFFFF8C00);
  static const Color g2 = Color(0xFFCC1500);
}

// ─── Summary card ────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.icon, this.highlight = false});

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: highlight ? const LinearGradient(colors: [_ShopIssuedReportPageColors.g1, _ShopIssuedReportPageColors.g2]) : null,
        color: highlight ? null : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlight ? Colors.transparent : onSurface.withOpacity(0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: highlight ? Colors.white : _ShopIssuedReportPageColors.g2),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: highlight ? Colors.white : onSurface),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: highlight ? Colors.white.withOpacity(0.85) : onSurface.withOpacity(0.55))),
        ],
      ),
    );
  }
}

// ─── Order tile ──────────────────────────────────────────────────────────

class _IssuedOrderTile extends StatelessWidget {
  const _IssuedOrderTile({
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
    const accent = Color(0xFF2E7D32);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: onSurface.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: order.buyerPhotoUrl != null
                      ? Image.network(order.buyerPhotoUrl!, width: 44, height: 44, fit: BoxFit.cover)
                      : Container(width: 44, height: 44, color: onSurface.withOpacity(0.06), child: Icon(Icons.person_rounded, color: onSurface.withOpacity(0.35))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('№${order.id}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: accent)),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              order.buyerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: onSurface),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        showShop
                            ? '${order.shopName} · ${order.issuedAt != null ? _formatDateTime(order.issuedAt!) : ''}'
                            : (order.issuedAt != null ? _formatDateTime(order.issuedAt!) : ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${numberFormat.format(order.totalValue)} сум',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
              if (order.buyerPhotoUrl != null) _PhotoPreview(photoUrl: order.buyerPhotoUrl!),
              const SizedBox(height: 16),
              Text(s.shopPickupOrderTitle(order.id), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: onSurface)),
              const SizedBox(height: 4),
              Text('${s.shopPickupBuyer}: ${order.buyerName}', style: TextStyle(fontSize: 13, color: onSurface.withOpacity(0.6))),
              Text('${s.shopPickupSeller}: ${order.sellerName}', style: TextStyle(fontSize: 13, color: onSurface.withOpacity(0.6))),
              Text('${s.shopIssuedShopFilterTitle}: ${order.shopName}', style: TextStyle(fontSize: 13, color: onSurface.withOpacity(0.6))),
              if (order.issuedByName != null)
                Text('${s.shopIssuedIssuedBy}: ${order.issuedByName}', style: TextStyle(fontSize: 13, color: onSurface.withOpacity(0.6))),
              if (order.issuedAt != null)
                Text('${s.shopIssuedIssuedAt}: ${_formatDateTime(order.issuedAt!)}', style: TextStyle(fontSize: 13, color: onSurface.withOpacity(0.6))),
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

// ─── Photo preview (tap to zoom) ───────────────────────────────────────

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _FullScreenPhotoView(photoUrl: photoUrl), fullscreenDialog: true),
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
              ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.network(photoUrl, fit: BoxFit.cover)),
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
  const _FullScreenPhotoView({required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
      body: Center(child: InteractiveViewer(minScale: 0.8, maxScale: 4, child: Image.network(photoUrl))),
    );
  }
}
