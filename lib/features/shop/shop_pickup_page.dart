import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import 'order_photo_capture_page.dart';
import 'shop_api.dart';

/// PVZ (pickup-point) order issuance: lists orders placed via uztexpro_store
/// that are still waiting to be handed over at this employee's own shop,
/// and lets the PVZ staff confirm the handover with a buyer photo.
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

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
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
      final orders = await PvzApi.fetchPending(widget.jwtToken, query: _searchController.text.trim());
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

  void _snack(String message, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(ok ? Icons.check_circle : Icons.error, color: Colors.white, size: 16),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: ok ? const Color(0xFF43A047) : const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Future<void> _openDetail(PvzOrder order) async {
    final issued = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(
        order: order,
        jwtToken: widget.jwtToken,
        numberFormat: _numberFormat,
      ),
    );
    if (issued == true && mounted) {
      _snack(S.of(context).shopPickupIssuedSnack(order.id), true);
      _load();
    }
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  const Spacer(),
                  if (!_loading && _error == null) _CountBadge(count: _orders.length),
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
          itemBuilder: (_, i) => _OrderCard(
            order: _orders[i],
            isDark: isDark,
            numberFormat: _numberFormat,
            s: s,
            onTap: () => _openDetail(_orders[i]),
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

class _OrderDetailSheet extends StatefulWidget {
  final PvzOrder order;
  final String jwtToken;
  final NumberFormat numberFormat;

  const _OrderDetailSheet({required this.order, required this.jwtToken, required this.numberFormat});

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  static const Color _g1 = Color(0xFFFF8C00);
  static const Color _g2 = Color(0xFFCC1500);

  bool _issuing = false;

  Future<void> _issue() async {
    final photoBase64 = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const OrderPhotoCapturePage()),
    );
    if (photoBase64 == null || !mounted) return;

    setState(() => _issuing = true);
    try {
      await PvzApi.issueOrder(widget.jwtToken, widget.order.id, photoBase64);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PvzApiException catch (e) {
      if (!mounted) return;
      setState(() => _issuing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: const Color(0xFFD32F2F)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline = Theme.of(context).colorScheme.outline;
    final order = widget.order;

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
                              '${item.color} · Размер ${item.sizeName} · ${widget.numberFormat.format(item.amount)} шт',
                              style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.55)),
                            ),
                          ],
                        ),
                      ),
                      Text('${widget.numberFormat.format(item.subtotal)} сум', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _g2)),
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
                    Text('${widget.numberFormat.format(order.totalValue)} сум', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _issuing ? null : _issue,
                  icon: _issuing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.camera_alt_rounded, size: 20),
                  label: Text(_issuing ? s.shopPickupIssuing : s.shopPickupIssueButton, style: const TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
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
