import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uztexpro_payment/main.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import 'product_photo.dart';

const _kDetailPath = 'sewing/product-model-list';
const _kConfirmPricePath = 'sewing/product-model';

String _fmtNum(dynamic raw) {
  if (raw == null) return '—';
  final n = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
  if (n == null) return raw.toString();
  if (n == n.truncateToDouble()) return n.toInt().toString();
  return n.toStringAsFixed(2);
}

String _fmtDateTime(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  try {
    return DateFormat('dd.MM.yyyy HH:mm:ss').format(DateTime.parse(raw));
  } catch (_) {
    return raw;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class ProductModelDetailPage extends StatefulWidget {
  final int modelId;
  final String jwtToken;
  final bool canConfirm;
  final VoidCallback onActionDone;

  const ProductModelDetailPage({
    Key? key,
    required this.modelId,
    required this.jwtToken,
    required this.canConfirm,
    required this.onActionDone,
  }) : super(key: key);

  @override
  State<ProductModelDetailPage> createState() => _ProductModelDetailPageState();
}

class _ProductModelDetailPageState extends State<ProductModelDetailPage> {
  static const _g1 = Color(0xFFFF8C00);
  static const _g2 = Color(0xFFCC1500);

  Map<String, dynamic>? _model;
  bool _isLoading = true;
  String? _error;
  bool _busy = false;

  String get _token {
    try {
      return jsonDecode(widget.jwtToken)['token'] as String;
    } catch (_) {
      return widget.jwtToken;
    }
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_token',
    'Content-Type': 'application/json',
  };

  bool get _confirmed => _model?['price_confirmed'] == true;

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
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final resp = await http
          .get(
            Uri.parse('$API/$_kDetailPath/${widget.modelId}/'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final rawBody =
            json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        setState(() {
          _model = (rawBody['data'] as Map<String, dynamic>?) ?? rawBody;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = '${S.of(context).loadDataError} (${resp.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '${S.of(context).connectionError}\n$e';
        _isLoading = false;
      });
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _onToggleConfirm() async {
    final confirmed = _confirmed;
    final ok = await _confirmDialog(
      icon: confirmed
          ? Icons.remove_circle_outline_rounded
          : Icons.check_circle_outline_rounded,
      iconColor: confirmed ? Colors.red.shade600 : const Color(0xFF43A047),
      title: confirmed
          ? S.of(context).unconfirmPriceTitle
          : S.of(context).confirmPriceTitle,
      message: confirmed
          ? S.of(context).unconfirmPriceDesc
          : S.of(context).confirmPriceDesc,
      confirmLabel: confirmed
          ? S.of(context).unconfirmPriceBtn
          : S.of(context).confirmPriceBtn,
      confirmColor: confirmed ? Colors.red.shade600 : const Color(0xFF43A047),
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final uri = Uri.parse(
        '$API/$_kConfirmPricePath/${widget.modelId}/confirm-price/',
      );
      final resp = confirmed
          ? await http
                .delete(uri, headers: _headers)
                .timeout(const Duration(seconds: 15))
          : await http
                .post(uri, headers: _headers)
                .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        setState(() {
          _model!['price_confirmed'] = data['price_confirmed'] ?? !confirmed;
          _model!['price_confirmed_by_name'] = data['price_confirmed_by_name'];
          _model!['price_confirmed_at'] = data['price_confirmed_at'];
          _busy = false;
        });
        widget.onActionDone();
        _snack(
          confirmed
              ? S.of(context).unconfirmPriceSuccess
              : S.of(context).confirmPriceSuccess,
          true,
        );
      } else if (resp.statusCode == 403) {
        _snack(S.of(context).noPricePermission, false);
        setState(() => _busy = false);
      } else {
        _snack(S.of(context).updateError, false);
        setState(() => _busy = false);
      }
    } catch (_) {
      if (!mounted) return;
      _snack(S.of(context).connectionError, false);
      setState(() => _busy = false);
    }
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────────

  Future<bool> _confirmDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: onSurface.withOpacity(0.2)),
                      ),
                      child: Text(
                        S.of(context).cancel,
                        style: TextStyle(
                          color: onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  void _snack(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: ok ? const Color(0xFF43A047) : const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
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
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: Text(
            _model?['vendor_code']?.toString() ??
                S.of(context).productModelDetailTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          centerTitle: true,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 22,
              ),
              onPressed: _isLoading ? null : _load,
              tooltip: S.of(context).refresh,
            ),
          ],
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        bottomNavigationBar:
            (!_isLoading && _error == null && widget.canConfirm)
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
    final hi = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    return Column(
      children: [
        Container(
          height: 150,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: 4,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Shimmer.fromColors(
                baseColor: base,
                highlightColor: hi,
                child: Container(
                  height: i == 0 ? 100 : 140,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 36,
                color: isDark ? Colors.white38 : Colors.red.shade300,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey.shade600,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(S.of(context).retry),
              style: FilledButton.styleFrom(
                backgroundColor: _g1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark, List<Color> gradColors) {
    final s = S.of(context);
    final model = _model!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final confirmed = _confirmed;
    final materials = (model['materials'] as List?) ?? [];
    final accessories = (model['accessories'] as List?) ?? [];

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Gradient header ──────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
                child: Column(
                  children: [
                    ProductPhotoThumbnail(
                      imageUrl: resolveProductImageUrl(model['image_url']),
                      size: 88,
                      heroTag: 'product_photo_${widget.modelId}',
                      isDark: isDark,
                      showRing: true,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      model['vendor_code']?.toString() ?? '—',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      model['name']?.toString() ?? '—',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            confirmed
                                ? Icons.check_circle_rounded
                                : Icons.hourglass_empty_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            confirmed ? s.priceConfirmed : s.priceNotConfirmed,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _HeroPriceRow(model: model),
                  ],
                ),
              ),
            ),
          ),

          // ── Cards area ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
            child: Column(
              children: [
                _InfoCard(model: model, isDark: isDark, onSurface: onSurface),
                const SizedBox(height: 10),
                _PricingCard(
                  model: model,
                  isDark: isDark,
                  onSurface: onSurface,
                ),
                const SizedBox(height: 10),
                _ConfirmationCard(
                  model: model,
                  isDark: isDark,
                  onSurface: onSurface,
                ),
                const SizedBox(height: 10),
                _MaterialsCard(
                  materials: materials,
                  isDark: isDark,
                  onSurface: onSurface,
                ),
                const SizedBox(height: 10),
                _AccessoriesCard(
                  accessories: accessories,
                  isDark: isDark,
                  onSurface: onSurface,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    final s = S.of(context);
    final confirmed = _confirmed;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.09),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: _busy
            ? const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Color(0xFFFF8C00)),
                  ),
                ),
              )
            : _ActionButton(
                label: confirmed ? s.unconfirmPriceBtn : s.confirmPriceBtn,
                icon: confirmed
                    ? Icons.remove_circle_outline_rounded
                    : Icons.check_rounded,
                color: confirmed
                    ? const Color(0xFFD32F2F)
                    : const Color(0xFF2E7D32),
                bgColor: confirmed
                    ? const Color(0xFFFFEBEE)
                    : const Color(0xFFE8F5E9),
                isDark: isDark,
                onTap: _onToggleConfirm,
              ),
      ),
    );
  }
}

// ─── Hero price row ───────────────────────────────────────────────────────────

class _HeroPriceRow extends StatelessWidget {
  final Map<String, dynamic> model;

  const _HeroPriceRow({required this.model});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _HeroStat(
              label: s.priceLabel,
              value: _fmtNum(model['cost']),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 1,
            height: 34,
            color: Colors.white.withOpacity(0.22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _HeroStat(
              label: s.discountCostLabel,
              value: _fmtNum(model['discount_cost']),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

// ─── Info card ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Map<String, dynamic> model;
  final bool isDark;
  final Color onSurface;

  const _InfoCard({
    required this.model,
    required this.isDark,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final category = model['category_name']?.toString() ?? '';
    return _SectionCard(
      title: s.information,
      icon: Icons.info_outline_rounded,
      isDark: isDark,
      child: Column(
        children: [
          _Row2(
            icon: Icons.tag_rounded,
            label: s.vendorCodeLabel,
            value: model['vendor_code']?.toString() ?? '—',
            os: onSurface,
          ),
          _Row2(
            icon: Icons.storefront_outlined,
            label: s.firmLabel,
            value: model['firm_name']?.toString() ?? '—',
            os: onSurface,
          ),
          _Row2(
            icon: Icons.calendar_view_month_rounded,
            label: s.seasonLabel,
            value: model['season']?.toString() ?? '—',
            os: onSurface,
          ),
          if (category.isNotEmpty)
            _Row2(
              icon: Icons.category_outlined,
              label: s.categoryLabel,
              value: category,
              os: onSurface,
            ),
        ],
      ),
    );
  }
}

// ─── Pricing card ─────────────────────────────────────────────────────────────

class _PricingCard extends StatelessWidget {
  final Map<String, dynamic> model;
  final bool isDark;
  final Color onSurface;

  const _PricingCard({
    required this.model,
    required this.isDark,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final allTiles = [
      (
        Icons.content_cut_rounded,
        s.cuttingPriceLabel,
        _fmtNum(model['cutting_price']),
        const Color(0xFF1E88E5),
      ),
      (
        Icons.local_shipping_outlined,
        s.transferPriceLabel,
        _fmtNum(model['transfer_price']),
        const Color(0xFF00ACC1),
      ),
      (
        Icons.print_outlined,
        s.printPriceLabel,
        _fmtNum(model['print_price']),
        const Color(0xFF8E24AA),
      ),
      (
        Icons.brush_outlined,
        s.embroideryPriceLabel,
        _fmtNum(model['embroidery_price']),
        const Color(0xFFD81B60),
      ),
      (
        Icons.checkroom_outlined,
        s.accessoryCostLabel,
        _fmtNum(model['accessory_cost']),
        const Color(0xFF43A047),
      ),
      (
        Icons.percent_rounded,
        s.sewingLossLabel,
        _fmtNum(model['sewing_loss_percent']),
        const Color(0xFFFB8C00),
      ),
      (
        Icons.percent_rounded,
        s.otherExpensesLabel,
        _fmtNum(model['other_expenses_percent']),
        const Color(0xFFFB8C00),
      ),
      (
        Icons.trending_up_rounded,
        s.profitabilityLabel,
        _fmtNum(model['profitability']),
        const Color(0xFF2E7D32),
      ),
      (
        Icons.percent_rounded,
        s.commissionLabel,
        _fmtNum(model['commission']),
        const Color(0xFF6D4C41),
      ),
      (
        Icons.discount_outlined,
        s.discountLabel,
        _fmtNum(model['discount']),
        const Color(0xFFE53935),
      ),
    ];
    final tiles = allTiles.where((t) => t.$3 != '—').toList();

    return _SectionCard(
      title: s.pricingSection,
      icon: Icons.payments_outlined,
      isDark: isDark,
      child: tiles.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: Text(
                  s.noPricingData,
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurface.withOpacity(0.4),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 8.0;
                final tileWidth = (constraints.maxWidth - spacing) / 2;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final t in tiles)
                      SizedBox(
                        width: tileWidth,
                        child: _StatTile(
                          icon: t.$1,
                          label: t.$2,
                          value: t.$3,
                          color: t.$4,
                          isDark: isDark,
                          onSurface: onSurface,
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

// ─── Stat tile ────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final Color onSurface;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(isDark ? 0.22 : 0.14),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
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

// ─── Confirmation card ────────────────────────────────────────────────────────

class _ConfirmationCard extends StatelessWidget {
  final Map<String, dynamic> model;
  final bool isDark;
  final Color onSurface;

  const _ConfirmationCard({
    required this.model,
    required this.isDark,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final confirmed = model['price_confirmed'] == true;
    final byName = model['price_confirmed_by_name']?.toString() ?? '';
    final rawAt = model['price_confirmed_at']?.toString() ?? '';
    final at = _fmtDateTime(rawAt);
    final color = confirmed ? const Color(0xFF43A047) : const Color(0xFFFF8C00);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(isDark ? 0.35 : 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(isDark ? 0.22 : 0.14),
            ),
            child: Icon(
              confirmed
                  ? Icons.check_circle_rounded
                  : Icons.hourglass_empty_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  confirmed ? s.priceConfirmed : s.priceNotConfirmed,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
                if (confirmed && byName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${s.confirmedByLabel}: $byName',
                    style: TextStyle(
                      fontSize: 12,
                      color: onSurface.withOpacity(0.65),
                    ),
                  ),
                ],
                if (confirmed && rawAt.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    at,
                    style: TextStyle(
                      fontSize: 11,
                      color: onSurface.withOpacity(0.45),
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

// ─── Materials card ───────────────────────────────────────────────────────────

class _MaterialsCard extends StatelessWidget {
  final List materials;
  final bool isDark;
  final Color onSurface;

  const _MaterialsCard({
    required this.materials,
    required this.isDark,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return _SectionCard(
      title: s.materialsCountLabel(materials.length),
      icon: Icons.layers_outlined,
      isDark: isDark,
      child: materials.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: Text(
                  s.noMaterials,
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurface.withOpacity(0.4),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          : Column(
              children: [
                for (int i = 0; i < materials.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 10,
                      thickness: 0.5,
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                    ),
                  _MaterialRow(
                    material: materials[i] as Map<String, dynamic>,
                    index: i + 1,
                    isDark: isDark,
                    onSurface: onSurface,
                  ),
                ],
              ],
            ),
    );
  }
}

class _MaterialRow extends StatelessWidget {
  final Map<String, dynamic> material;
  final int index;
  final bool isDark;
  final Color onSurface;

  const _MaterialRow({
    required this.material,
    required this.index,
    required this.isDark,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    final name = material['fabric_name']?.toString() ?? '—';
    final color = material['fabric_color_name']?.toString() ?? '';
    final price = _fmtNum(material['fabric_price']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFF8C00).withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? Colors.orange.shade300
                    : const Color(0xFFFF8C00),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (color.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    color,
                    style: TextStyle(
                      fontSize: 10,
                      color: onSurface.withOpacity(0.45),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                _Pill(
                  text: price,
                  color: isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                  bgColor: isDark
                      ? Colors.blue.withOpacity(0.18)
                      : Colors.blue.shade50,
                  borderColor: isDark
                      ? Colors.blue.withOpacity(0.3)
                      : Colors.blue.shade200,
                  icon: Icons.payments_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Accessories card ─────────────────────────────────────────────────────────

class _AccessoriesCard extends StatelessWidget {
  final List accessories;
  final bool isDark;
  final Color onSurface;

  const _AccessoriesCard({
    required this.accessories,
    required this.isDark,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return _SectionCard(
      title: s.accessoriesCountLabel(accessories.length),
      icon: Icons.category_outlined,
      isDark: isDark,
      child: accessories.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: Text(
                  s.noAccessories,
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurface.withOpacity(0.4),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          : Column(
              children: [
                for (int i = 0; i < accessories.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 10,
                      thickness: 0.5,
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                    ),
                  _AccessoryRow(
                    accessory: accessories[i] as Map<String, dynamic>,
                    isDark: isDark,
                    onSurface: onSurface,
                  ),
                ],
              ],
            ),
    );
  }
}

class _AccessoryRow extends StatelessWidget {
  final Map<String, dynamic> accessory;
  final bool isDark;
  final Color onSurface;

  const _AccessoryRow({
    required this.accessory,
    required this.isDark,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    final title = accessory['accessory_title']?.toString() ?? '—';
    final norm = _fmtNum(accessory['norm']);
    final unit = accessory['m_unit_name']?.toString() ?? '';
    final price = _fmtNum(accessory['price']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.checkroom_outlined,
            size: 14,
            color: onSurface.withOpacity(0.35),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 6,
            children: [
              _Pill(
                text: unit.isNotEmpty ? '$norm $unit' : norm,
                color: isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                bgColor: isDark
                    ? Colors.blue.withOpacity(0.18)
                    : Colors.blue.shade50,
                borderColor: isDark
                    ? Colors.blue.withOpacity(0.3)
                    : Colors.blue.shade200,
                icon: Icons.scale_outlined,
              ),
              _Pill(
                text: price,
                color: isDark
                    ? Colors.orange.shade200
                    : const Color(0xFFFF8C00),
                bgColor: isDark
                    ? Colors.orange.withOpacity(0.18)
                    : Colors.orange.shade50,
                borderColor: isDark
                    ? Colors.orange.withOpacity(0.3)
                    : Colors.orange.shade200,
                icon: Icons.payments_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final IconData icon;

  const _Pill({
    required this.text,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
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
    required this.title,
    required this.icon,
    required this.isDark,
    required this.child,
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
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(
                      0xFFFF8C00,
                    ).withOpacity(isDark ? 0.2 : 0.1),
                  ),
                  child: Icon(icon, size: 13, color: const Color(0xFFFF8C00)),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            ),
            Divider(
              height: 14,
              thickness: 0.5,
              color: isDark ? Colors.white12 : Colors.grey.shade100,
            ),
            child,
          ],
        ),
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
  final bool highlight;

  const _Row2({
    required this.icon,
    required this.label,
    required this.value,
    required this.os,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFFFF8C00);
    final valueColor = highlight ? accent : os.withOpacity(0.85);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (highlight ? accent : os).withOpacity(
                highlight ? 0.14 : 0.06,
              ),
            ),
            child: Icon(
              icon,
              size: 12,
              color: highlight ? accent : os.withOpacity(0.4),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: os.withOpacity(0.48)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
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
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.isDark,
    required this.onTap,
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
            border: Border.all(color: color.withOpacity(isDark ? 0.35 : 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
