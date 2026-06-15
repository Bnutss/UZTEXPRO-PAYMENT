import 'package:flutter/material.dart';
import 'package:uztexpro_payment/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';

// ─── Status config ────────────────────────────────────────────────────────────

class PayStatusCfg {
  final Color color;
  final IconData icon;

  const PayStatusCfg(this.color, this.icon);
}

PayStatusCfg payStatusConfig(int code) {
  switch (code) {
    case 1:
      return const PayStatusCfg(Color(0xFF1976D2), Icons.fiber_new_rounded);
    case 2:
      return const PayStatusCfg(Color(0xFF43A047), Icons.verified_outlined);
    case 4:
      return const PayStatusCfg(Color(0xFF2E7D32), Icons.paid_outlined);
    case 5:
      return const PayStatusCfg(
        Color(0xFFEF6C00),
        Icons.account_balance_wallet_outlined,
      );
    case 6:
      return const PayStatusCfg(Color(0xFFD32F2F), Icons.cancel_outlined);
    case 9:
      return const PayStatusCfg(Color(0xFF0288D1), Icons.how_to_reg_outlined);
    case 10:
      return const PayStatusCfg(
        Color(0xFF1B5E20),
        Icons.workspace_premium_outlined,
      );
    default:
      return const PayStatusCfg(Color(0xFF1976D2), Icons.pending_outlined);
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class MainPageScreen extends StatefulWidget {
  final String jwtToken;

  const MainPageScreen({Key? key, required this.jwtToken}) : super(key: key);

  @override
  _MainPageScreenState createState() => _MainPageScreenState();
}

class _MainPageScreenState extends State<MainPageScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> paymentReports = [];
  List<dynamic> statuses = [];
  Map<String, dynamic>? selectedStatus;
  bool isLoading = true;
  TextEditingController notesController = TextEditingController();
  TextEditingController amountController = TextEditingController();
  final NumberFormat currencyFormatter = NumberFormat('#,###', 'ru');
  late AnimationController _animationController;
  late Animation<double> _animation;

  final _scrollController = ScrollController();
  bool _showBackToTopButton = false;

  final TextEditingController _searchController = TextEditingController();
  int? _selectedStatusFilterId;

  static const Color _gradientStart = Color(0xFFFF8C00);
  static const Color _gradientEnd = Color(0xFFCC1500);

  static List<dynamic>? _memStatuses;
  static List<dynamic>? _memReports;
  static DateTime? _memStatusesTime;
  static DateTime? _memReportsTime;
  static const _kMemTTL = Duration(minutes: 5);

  // ── Filtered list ────────────────────────────────────────────────────────────

  List<dynamic> get _filteredReports {
    final q = _searchController.text.toLowerCase().trim();
    return paymentReports.where((r) {
      if (_selectedStatusFilterId != null &&
          r['status'] != _selectedStatusFilterId)
        return false;
      if (q.isEmpty) return true;
      return r['id'].toString().contains(q) ||
          (r['bussines_name'] ?? '').toString().toLowerCase().contains(q) ||
          (r['contract'] ?? '').toString().toLowerCase().contains(q) ||
          (r['applicant_name'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _scrollController.addListener(() {
      setState(() => _showBackToTopButton = _scrollController.offset >= 200);
    });
    _searchController.addListener(() => setState(() {}));
    _initializeData();
    localeNotifier.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() => setState(() {});

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    notesController.dispose();
    amountController.dispose();
    _searchController.dispose();
    localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────────────────────

  Future<void> _initializeData() async {
    await Future.wait([fetchPaymentStatuses(), fetchPaymentReports()]);
  }

  String formatCurrency(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '0';
    final clean = value.toString().replaceAll(' ', '').replaceAll(',', '.');
    final n = double.tryParse(clean);
    if (n == null) return value.toString();
    return currencyFormatter.format(n);
  }

  void showNotification(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess
            ? const Color(0xFF43A047)
            : const Color(0xFFD32F2F),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        elevation: 6,
      ),
    );
  }

  Future<void> fetchPaymentStatuses() async {
    const String storageKey = 'payment_statuses';
    final s = S.of(context);
    final now = DateTime.now();
    if (_memStatuses != null &&
        _memStatusesTime != null &&
        now.difference(_memStatusesTime!) < _kMemTTL) {
      if (mounted) setState(() => statuses = _memStatuses!);
      return;
    }
    try {
      String? storedData = await storage.read(key: storageKey);
      if (storedData != null) {
        final decoded = jsonDecode(storedData) as List;
        _memStatuses = decoded;
        _memStatusesTime = now;
        if (mounted) setState(() => statuses = decoded);
      } else {
        final response = await http
            .get(
              Uri.parse('$API/edo/payment-raport-status/'),
              headers: {
                'Authorization':
                    'Bearer ${jsonDecode(widget.jwtToken)["token"]}',
              },
            )
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw Exception('Timeout'),
            );
        if (response.statusCode == 200) {
          final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
          _memStatuses = jsonResponse as List;
          _memStatusesTime = DateTime.now();
          storage.write(key: storageKey, value: jsonEncode(jsonResponse));
          if (mounted) setState(() => statuses = jsonResponse);
        } else {
          throw Exception('Failed');
        }
      }
    } catch (e) {
      if (mounted) showNotification(s.loadStatusError, false);
    }
  }

  Future<void> fetchPaymentReports() async {
    const String cacheKey = 'payment_reports_v2';
    final s = S.of(context);
    final now = DateTime.now();

    if (_memReports != null) {
      if (mounted) {
        setState(() {
          paymentReports = _memReports!;
          isLoading = false;
        });
        _animationController.forward();
      }
      if (_memReportsTime != null &&
          now.difference(_memReportsTime!) < _kMemTTL)
        return;
    } else {
      try {
        final cached = await storage.read(key: cacheKey);
        if (cached != null && mounted) {
          final data = json.decode(cached);
          final List results = data is List ? data : (data['results'] ?? []);
          _memReports = results;
          setState(() {
            paymentReports = results;
            isLoading = false;
          });
          _animationController.forward();
        }
      } catch (_) {}
    }

    try {
      final response = await http
          .get(
            Uri.parse('$API/edo/payment-raport/?for_mobile=1'),
            headers: {
              'Authorization': 'Bearer ${jsonDecode(widget.jwtToken)["token"]}',
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Timeout'),
          );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final List fresh = jsonResponse['results'] ?? [];
        _memReports = fresh;
        _memReportsTime = DateTime.now();
        storage.write(key: cacheKey, value: utf8.decode(response.bodyBytes));
        setState(() {
          paymentReports = fresh;
          isLoading = false;
        });
        _animationController.forward();
      } else {
        throw Exception('Failed');
      }
    } catch (e) {
      if (!mounted) return;
      if (paymentReports.isEmpty) {
        setState(() => isLoading = false);
        showNotification(s.loadDataError, false);
      }
    }
  }

  Future<void> _refreshData() async {
    _animationController.reset();
    await fetchPaymentReports();
    return Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _launchURL(String url) async {
    final s = S.of(context);
    final fullUrl = 'https://uztex.pro$url';
    try {
      final Uri uri = Uri.parse(fullUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        showNotification(s.fileOpenError, false);
        await Clipboard.setData(ClipboardData(text: fullUrl));
        showNotification(s.urlCopied, true);
      }
    } catch (e) {
      showNotification(s.fileError, false);
      await Clipboard.setData(ClipboardData(text: fullUrl));
      showNotification(s.urlCopied, true);
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────────

  void _showSuccessAnimation() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation1, animation2) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          Navigator.of(context).pop();
        });
        return Center(
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            builder: (context, double value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green.shade600,
                      size: 50,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> updateReportStatus(
    Map<String, dynamic> report,
    Map<String, dynamic> selectedStatus,
    String notes,
    String? partialPrice,
  ) async {
    final s = S.of(context);
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;
    final cfg = payStatusConfig(selectedStatus['id'] as int);

    bool confirmed =
        await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_gradientStart, _gradientEnd],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.sync,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.confirmAction,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: onSurface.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.changePaymentStatusTo,
                          style: TextStyle(
                            fontSize: 14,
                            color: onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: cfg.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: cfg.color.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(cfg.icon, color: cfg.color, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                selectedStatus['name'],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: cfg.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            s.noteColon,
                            style: TextStyle(
                              fontSize: 14,
                              color: onSurface.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Text(
                              notes,
                              style: TextStyle(
                                fontSize: 13,
                                color: onSurface.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ],
                        if (partialPrice != null &&
                            partialPrice.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            s.partialAmountColon,
                            style: TextStyle(
                              fontSize: 14,
                              color: onSurface.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              '$partialPrice ${report['currency_name'] ?? ''}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: outline),
                          ),
                          child: Text(
                            s.cancel,
                            style: TextStyle(
                              color: onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: _gradientStart,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            s.confirm,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    final loadingEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: Container(
            width: 180,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.orange.shade700,
                    ),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  s.updating,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(loadingEntry);

    final requestData = <String, dynamic>{
      'status': selectedStatus['id'],
      'notes': notes,
    };
    if (partialPrice != null && partialPrice.isNotEmpty) {
      requestData['partial_price'] = partialPrice;
    }

    try {
      final response = await http
          .patch(
            Uri.parse('$API/edo/payment-raport/${report['id']}/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${jsonDecode(widget.jwtToken)["token"]}',
            },
            body: jsonEncode(requestData),
          )
          .timeout(const Duration(seconds: 20));

      loadingEntry.remove();

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessAnimation();
        showNotification(s.statusUpdated, true);
        await fetchPaymentReports();
      } else {
        throw Exception('Error: ${response.statusCode}');
      }
    } catch (e) {
      loadingEntry.remove();
      showNotification('${s.updateError}: $e', false);
    }
  }

  Widget _buildCompactInfoRow(IconData icon, String label, String value) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.orange.shade700),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: onSurface,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  void showUpdateStatusDialog(
    BuildContext context,
    Map<String, dynamic> report,
  ) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    selectedStatus = statuses.firstWhere(
      (status) => status['id'] == report['status'],
      orElse: () => null,
    );

    notesController.text = report['notes'] ?? '';
    amountController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool showAmountField = selectedStatus?['id'] == 5;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: outline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_gradientStart, _gradientEnd],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.edit_note,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.changeStatus,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  report['bussines_name'] ?? s.unnamed,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: onSurface.withOpacity(0.6),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: Icon(
                              Icons.close,
                              size: 20,
                              color: onSurface.withOpacity(0.7),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: onSurface.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: outline),
                      ),
                      child: Column(
                        children: [
                          _buildCompactInfoRow(
                            Icons.description_outlined,
                            s.contractColon,
                            report['contract'] ?? s.noData,
                          ),
                          const SizedBox(height: 8),
                          _buildCompactInfoRow(
                            Icons.subject_outlined,
                            s.subjectColon,
                            report['sub_contract'] ?? s.noData,
                          ),
                          const SizedBox(height: 8),
                          _buildCompactInfoRow(
                            Icons.monetization_on_outlined,
                            s.amountColon,
                            '${formatCurrency(report['contract_price'])} ${report['currency_name'] ?? ''}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.paymentStatus,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: outline),
                              color: onSurface.withOpacity(0.03),
                            ),
                            child:
                                DropdownButtonFormField<Map<String, dynamic>>(
                                  value: selectedStatus,
                                  isExpanded: true,
                                  dropdownColor: surface,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    border: InputBorder.none,
                                    prefixIcon: Icon(
                                      Icons.playlist_add_check,
                                      color: Colors.orange.shade700,
                                    ),
                                    fillColor: Colors.transparent,
                                  ),
                                  hint: Text(
                                    s.selectPaymentStatus,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.orange.shade700,
                                  ),
                                  items: statuses
                                      .map<
                                        DropdownMenuItem<Map<String, dynamic>>
                                      >((status) {
                                        final sc = payStatusConfig(
                                          status['id'] as int,
                                        );
                                        return DropdownMenuItem<
                                          Map<String, dynamic>
                                        >(
                                          value: status,
                                          child: Row(
                                            children: [
                                              Icon(
                                                sc.icon,
                                                size: 18,
                                                color: sc.color,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                status['name'],
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      })
                                      .toList(),
                                  onChanged: (value) {
                                    setModalState(() {
                                      selectedStatus = value;
                                      showAmountField =
                                          selectedStatus?['id'] == 5;
                                    });
                                  },
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (showAmountField)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.partialAmountLabel,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: amountController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(fontSize: 14, color: onSurface),
                              decoration: InputDecoration(
                                hintText: s.enterAmount,
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: onSurface.withOpacity(0.4),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: outline),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.orange.shade700,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Icon(
                                  Icons.monetization_on,
                                  size: 20,
                                  color: Colors.orange.shade700,
                                ),
                                suffixText: report['currency_name'] ?? '',
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.noteLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: notesController,
                            maxLines: 2,
                            style: TextStyle(fontSize: 14, color: onSurface),
                            decoration: InputDecoration(
                              hintText: s.addComment,
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: onSurface.withOpacity(0.4),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: outline),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.orange.shade700,
                                  width: 2,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.comment,
                                size: 20,
                                color: Colors.orange.shade700,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: outline),
                              ),
                              child: Text(
                                s.cancel,
                                style: TextStyle(
                                  color: onSurface.withOpacity(0.7),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (selectedStatus == null) {
                                  showNotification(s.selectStatusFirst, false);
                                  return;
                                }
                                Navigator.of(dialogContext).pop();
                                final statusToUpdate =
                                    Map<String, dynamic>.from(selectedStatus!);
                                final notesText = notesController.text;
                                final partialPrice = showAmountField
                                    ? amountController.text
                                    : null;
                                updateReportStatus(
                                  report,
                                  statusToUpdate,
                                  notesText,
                                  partialPrice,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                backgroundColor: _gradientStart,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                s.save,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
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
          },
        );
      },
    );
  }

  // ── Shimmer ───────────────────────────────────────────────────────────────────

  Widget _shimmer(bool isDark) {
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final hi = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Shimmer.fromColors(
          baseColor: base,
          highlightColor: hi,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  // ── Empty states ──────────────────────────────────────────────────────────────

  Widget _emptyState(S s, bool isDark) {
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
              Icons.business_center_outlined,
              size: 38,
              color: isDark ? Colors.white38 : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.noContracts,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(s.refresh),
            style: FilledButton.styleFrom(
              backgroundColor: _gradientStart,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noResultsState(S s, bool isDark) {
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
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 38,
              color: isDark ? Colors.white38 : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.paymentNoResults,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              _searchController.clear();
              setState(() => _selectedStatusFilterId = null);
            },
            icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
            label: Text(s.paymentResetFilters),
            style: OutlinedButton.styleFrom(
              foregroundColor: _gradientStart,
              side: const BorderSide(color: _gradientStart),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradColors = isDark
        ? [const Color(0xFF3D1800), const Color(0xFF1F0000)]
        : [_gradientStart, _gradientEnd];
    final surface = Theme.of(context).colorScheme.surface;
    final listBg = isDark ? surface : const Color(0xFFF4F4F4);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            s.paymentAgreements,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
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
        body: Column(
          children: [
            // ── Gradient bar + count badge ──────────────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  const Spacer(),
                  if (!isLoading)
                    _PayCountBadge(
                      shown: _filteredReports.length,
                      total: paymentReports.length,
                    ),
                ],
              ),
            ),
            // ── Search bar ──────────────────────────────────────────────────
            Container(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: _PaySearchBar(
                controller: _searchController,
                hint: s.paymentSearchHint,
                isDark: isDark,
              ),
            ),
            // ── Status filter ───────────────────────────────────────────────
            Container(
              color: listBg,
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: _PayFilterRow(
                statuses: statuses,
                usedIds: paymentReports
                    .map<int>((r) => r['status'] as int)
                    .toSet(),
                selected: _selectedStatusFilterId,
                isDark: isDark,
                allLabel: s.filterAll,
                onSelect: (id) => setState(
                  () => _selectedStatusFilterId = _selectedStatusFilterId == id
                      ? null
                      : id,
                ),
              ),
            ),
            // ── List ────────────────────────────────────────────────────────
            Expanded(
              child: Container(color: listBg, child: _buildBody(isDark, s)),
            ),
          ],
        ),
        floatingActionButton: _showBackToTopButton
            ? FloatingActionButton(
                onPressed: () => _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                ),
                backgroundColor: Colors.white,
                foregroundColor: _gradientStart,
                mini: true,
                elevation: 6,
                child: const Icon(Icons.arrow_upward),
              )
            : null,
      ),
    );
  }

  Widget _buildBody(bool isDark, S s) {
    if (isLoading) return _shimmer(isDark);
    if (paymentReports.isEmpty) return _emptyState(s, isDark);
    if (_filteredReports.isEmpty) return _noResultsState(s, isDark);

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: _gradientStart,
      child: FadeTransition(
        opacity: _animation,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 32),
          itemCount: _filteredReports.length,
          itemBuilder: (_, i) {
            final report = _filteredReports[i];
            return _PayCard(
              report: report,
              isDark: isDark,
              currencyFormatter: currencyFormatter,
              onTap: () {
                if (report['has_change'] == true) {
                  showUpdateStatusDialog(context, report);
                } else {
                  showNotification(s.noPermission, false);
                }
              },
              onOpenFile: report['contract_document_url'] != null
                  ? () => _launchURL(report['contract_document_url'])
                  : null,
              onCopyUrl: report['contract_document_url'] != null
                  ? () async {
                      final url =
                          'https://uztex.pro${report['contract_document_url']}';
                      await Clipboard.setData(ClipboardData(text: url));
                      showNotification(s.urlCopiedShort, true);
                    }
                  : null,
            );
          },
        ),
      ),
    );
  }
}

// ─── Pay Card ─────────────────────────────────────────────────────────────────

class _PayCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final bool isDark;
  final NumberFormat currencyFormatter;
  final VoidCallback onTap;
  final VoidCallback? onOpenFile;
  final VoidCallback? onCopyUrl;

  const _PayCard({
    required this.report,
    required this.isDark,
    required this.currencyFormatter,
    required this.onTap,
    this.onOpenFile,
    this.onCopyUrl,
  });

  String _fmt(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '0';
    final clean = value.toString().replaceAll(' ', '').replaceAll(',', '.');
    final n = double.tryParse(clean);
    if (n == null) return value.toString();
    return currencyFormatter.format(n);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final cardBg = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : Colors.white;
    final s = S.of(context);

    final id = report['id'] as int? ?? 0;
    final statusId = report['status'] as int? ?? 0;
    final cfg = payStatusConfig(statusId);
    final statusName = report['status_name']?.toString() ?? '-';
    final bizName = report['bussines_name']?.toString() ?? s.unnamed;
    final contract = report['contract']?.toString() ?? s.noData;
    final subContract = report['sub_contract']?.toString() ?? s.noData;
    final applicant = report['applicant_name']?.toString() ?? s.notSpecified;
    final payType = report['raport_paying_type_name']?.toString() ?? '';
    final contractAmt = _fmt(report['contract_price']);
    final paid = _fmt(report['paid']);
    final currency = report['currency_name']?.toString() ?? '';
    final notes = report['notes']?.toString() ?? '';
    final hasChange = report['has_change'] == true;

    final payTypeColor = payType.toLowerCase().contains('пост')
        ? const Color(0xFF43A047)
        : const Color(0xFFD32F2F);

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
            border: Border(left: BorderSide(color: cfg.color, width: 4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header: ID + company + status badge ────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // ID badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: cfg.color.withOpacity(
                                    isDark ? 0.2 : 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: cfg.color.withOpacity(0.35),
                                  ),
                                ),
                                child: Text(
                                  '#$id',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: cfg.color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  bizName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: onSurf,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (hasChange)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_rounded,
                                    size: 11,
                                    color: cfg.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    s.available,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cfg.color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status badge
                    _PayStatusBadge(cfg: cfg, label: statusName),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                ),
                const SizedBox(height: 8),
                // ── Info rows ──────────────────────────────────────────────
                _PayInfoLine(
                  icon: Icons.description_outlined,
                  label: s.contract,
                  text: contract,
                  onSurface: onSurf,
                ),
                const SizedBox(height: 5),
                _PayInfoLine(
                  icon: Icons.subject_outlined,
                  label: s.subject,
                  text: subContract,
                  onSurface: onSurf,
                ),
                const SizedBox(height: 5),
                _PayInfoLine(
                  icon: Icons.person_outline_rounded,
                  label: s.applicant,
                  text: applicant,
                  onSurface: onSurf,
                ),
                if (payType.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _PayInfoLine(
                    icon: Icons.credit_card_outlined,
                    label: s.paymentType,
                    text: payType,
                    onSurface: onSurf,
                    valueColor: payTypeColor,
                  ),
                ],
                const SizedBox(height: 8),
                // ── Amount row ─────────────────────────────────────────────
                _PayAmountRow(
                  contractAmt: contractAmt,
                  paid: paid,
                  currency: currency,
                  isDark: isDark,
                  onSurface: onSurf,
                  s: s,
                ),
                // ── Notes ──────────────────────────────────────────────────
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _PayNoteRow(text: notes, isDark: isDark),
                ],
                // ── Bottom bar: hint left, icon buttons right ──────────────
                if (onOpenFile != null || onCopyUrl != null || hasChange) ...[
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (hasChange) ...[
                        Icon(
                          Icons.touch_app_rounded,
                          size: 13,
                          color: cfg.color,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            s.tapToChangeStatus,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cfg.color,
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if (onOpenFile != null)
                        _PayIconBtn(
                          icon: Icons.open_in_new_rounded,
                          tooltip: 'Открыть',
                          onTap: onOpenFile!,
                        ),
                      if (onCopyUrl != null) ...[
                        const SizedBox(width: 6),
                        _PayIconBtn(
                          icon: Icons.copy_rounded,
                          tooltip: 'Копировать',
                          onTap: onCopyUrl!,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────

class _PaySearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isDark;

  const _PaySearchBar({
    required this.controller,
    required this.hint,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.07) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: onSurface, fontSize: 14),
        decoration: InputDecoration(
          hintText: '$hint...',
          hintStyle: TextStyle(
            color: onSurface.withOpacity(0.38),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: onSurface.withOpacity(0.38),
            size: 20,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, __) => v.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      size: 18,
                      color: onSurface.withOpacity(0.4),
                    ),
                    onPressed: controller.clear,
                  ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// ─── Status filter chips ──────────────────────────────────────────────────────

class _PayFilterRow extends StatelessWidget {
  final List<dynamic> statuses;
  final Set<int> usedIds;
  final int? selected;
  final bool isDark;
  final String allLabel;
  final ValueChanged<int?> onSelect;

  const _PayFilterRow({
    required this.statuses,
    required this.usedIds,
    required this.selected,
    required this.isDark,
    required this.allLabel,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (statuses.isEmpty) return const SizedBox.shrink();
    final active = statuses
        .where((st) => usedIds.contains(st['id'] as int))
        .toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _PaySChip(
            label: allLabel,
            selected: selected == null,
            color: isDark ? Colors.white70 : Colors.grey.shade600,
            isDark: isDark,
            onTap: () => onSelect(null),
          ),
          for (final st in active) ...[
            const SizedBox(width: 6),
            _PaySChip(
              label: st['name'] as String,
              selected: selected == st['id'],
              color: payStatusConfig(st['id'] as int).color,
              isDark: isDark,
              onTap: () => onSelect(st['id'] as int),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaySChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _PaySChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? color
              : (isDark ? Colors.white.withOpacity(0.07) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? color
                : (isDark ? Colors.white12 : Colors.grey.shade200),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!selected)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Count badge ──────────────────────────────────────────────────────────────

class _PayCountBadge extends StatelessWidget {
  final int shown;
  final int total;

  const _PayCountBadge({required this.shown, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
      ),
      child: Text(
        shown == total ? '$total' : '$shown / $total',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class _PayStatusBadge extends StatelessWidget {
  final PayStatusCfg cfg;
  final String label;

  const _PayStatusBadge({required this.cfg, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: cfg.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cfg.color.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cfg.icon, size: 12, color: cfg.color),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cfg.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info line ────────────────────────────────────────────────────────────────

class _PayInfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final Color onSurface;
  final Color? valueColor;

  const _PayInfoLine({
    required this.icon,
    required this.label,
    required this.text,
    required this.onSurface,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: onSurface.withOpacity(0.35)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.45)),
        ),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor ?? onSurface.withOpacity(0.85),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Amount row ───────────────────────────────────────────────────────────────

class _PayAmountRow extends StatelessWidget {
  final String contractAmt;
  final String paid;
  final String currency;
  final bool isDark;
  final Color onSurface;
  final S s;

  const _PayAmountRow({
    required this.contractAmt,
    required this.paid,
    required this.currency,
    required this.isDark,
    required this.onSurface,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AmtCell(
              icon: Icons.account_balance_outlined,
              label: s.contractAmount,
              value: contractAmt,
              color: Colors.orange.shade700,
              onSurface: onSurface,
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
          Expanded(
            child: _AmtCell(
              icon: Icons.payment_outlined,
              label: s.toPay,
              value: paid,
              color: Colors.green.shade700,
              onSurface: onSurface,
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
          Expanded(
            child: _AmtCell(
              icon: Icons.currency_exchange_outlined,
              label: s.currency,
              value: currency.isEmpty ? '-' : currency,
              color: Colors.indigo.shade700,
              onSurface: onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmtCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color onSurface;

  const _AmtCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: onSurface.withOpacity(0.5)),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}

// ─── File button ──────────────────────────────────────────────────────────────

class _PayIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _PayIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.blue.shade300 : Colors.blue.shade600;
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.blue.withValues(alpha: 0.1)
                : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? Colors.blue.withValues(alpha: 0.25)
                  : Colors.blue.shade100,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                tooltip,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Note row ─────────────────────────────────────────────────────────────────

class _PayNoteRow extends StatelessWidget {
  final String text;
  final bool isDark;

  const _PayNoteRow({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.notes_rounded,
          size: 13,
          color: isDark ? Colors.amber.shade300 : Colors.amber.shade700,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
            ),
          ),
        ),
      ],
    );
  }
}
