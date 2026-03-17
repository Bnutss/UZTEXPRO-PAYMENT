import 'package:flutter/material.dart';
import 'package:uztexpro_payment/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'settings_screen.dart';
import 'login_page.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'app_strings.dart';
import 'locale_notifier.dart';

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
  bool isUpdatingStatus = false;
  TextEditingController notesController = TextEditingController();
  TextEditingController amountController = TextEditingController();
  final NumberFormat currencyFormatter = NumberFormat('#,###', 'ru');
  late AnimationController _animationController;
  late Animation<double> _animation;

  final _scrollController = ScrollController();
  bool _showBackToTopButton = false;

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
      setState(() {
        _showBackToTopButton = _scrollController.offset >= 200;
      });
    });

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
    localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  Future<void> _initializeData() async {
    await fetchPaymentStatuses();
    await fetchPaymentReports();
  }

  String formatCurrency(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return "0";
    String cleanValue =
        value.toString().replaceAll(" ", "").replaceAll(",", ".");
    double? numValue = double.tryParse(cleanValue);
    if (numValue == null) return value.toString();
    return currencyFormatter.format(numValue);
  }

  void showNotification(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle : Icons.error,
                color: Colors.white, size: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        backgroundColor:
            isSuccess ? const Color(0xFF43A047) : const Color(0xFFD32F2F),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        elevation: 6,
      ),
    );
  }

  Future<void> fetchPaymentStatuses() async {
    const String storageKey = "payment_statuses";
    final s = S.of(context);
    try {
      String? storedData = await storage.read(key: storageKey);
      if (storedData != null) {
        setState(() {
          statuses = jsonDecode(storedData);
        });
      } else {
        final response = await http.get(
          Uri.parse("$API/edo/payment-raport-status/"),
          headers: {
            "Authorization": "Bearer ${jsonDecode(widget.jwtToken)["token"]}"
          },
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Timeout'),
        );

        if (response.statusCode == 200) {
          final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
          await storage.write(key: storageKey, value: jsonEncode(jsonResponse));
          setState(() {
            statuses = jsonResponse;
          });
        } else {
          throw Exception('Failed');
        }
      }
    } catch (e) {
      showNotification(s.loadStatusError, false);
    }
  }

  Future<void> fetchPaymentReports() async {
    setState(() => isLoading = true);
    final s = S.of(context);
    try {
      final response = await http.get(
        Uri.parse("$API/edo/payment-raport/?for_mobile=1"),
        headers: {
          "Authorization": "Bearer ${jsonDecode(widget.jwtToken)["token"]}"
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Timeout'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          paymentReports = jsonResponse['results'];
          isLoading = false;
        });
        _animationController.forward();
      } else {
        throw Exception('Failed');
      }
    } catch (e) {
      setState(() => isLoading = false);
      showNotification(s.loadDataError, false);
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

  Color _getStatusColor(int statusId) {
    switch (statusId) {
      case 2:
        return const Color(0xFF43A047);
      case 3:
        return const Color(0xFFD32F2F);
      case 5:
        return const Color(0xFFEF6C00);
      default:
        return const Color(0xFF1976D2);
    }
  }

  IconData _getStatusIcon(int statusId) {
    switch (statusId) {
      case 2:
        return Icons.check_circle;
      case 3:
        return Icons.cancel;
      case 5:
        return Icons.account_balance_wallet;
      default:
        return Icons.pending;
    }
  }

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
      String? partialPrice) async {
    final s = S.of(context);
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    bool confirmed = await showModalBottomSheet<bool>(
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
                            colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.sync, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.confirmAction,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: onSurface),
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
                          style: TextStyle(fontSize: 14, color: onSurface.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _getStatusColor(selectedStatus["id"]).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getStatusColor(selectedStatus["id"]).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(selectedStatus["id"]),
                                color: _getStatusColor(selectedStatus["id"]),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                selectedStatus["name"],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(selectedStatus["id"]),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            s.noteColon,
                            style: TextStyle(fontSize: 14, color: onSurface.withOpacity(0.7)),
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
                              style: TextStyle(fontSize: 13, color: onSurface.withOpacity(0.8)),
                            ),
                          ),
                        ],
                        if (partialPrice != null && partialPrice.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            s.partialAmountColon,
                            style: TextStyle(fontSize: 14, color: onSurface.withOpacity(0.7)),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            backgroundColor: const Color(0xFFFF9800),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            s.confirm,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

    final loadingOverlayEntry = OverlayEntry(
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
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

    Overlay.of(context).insert(loadingOverlayEntry);

    var requestData = {
      'status': selectedStatus["id"],
      'notes': notes,
    };
    if (partialPrice != null && partialPrice.isNotEmpty) {
      requestData['partial_price'] = partialPrice;
    }

    try {
      var response = await http
          .patch(
            Uri.parse("$API/edo/payment-raport/${report['id']}/"),
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer ${jsonDecode(widget.jwtToken)["token"]}",
            },
            body: jsonEncode(requestData),
          )
          .timeout(const Duration(seconds: 20));

      loadingOverlayEntry.remove();

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessAnimation();
        showNotification(s.statusUpdated, true);
        await fetchPaymentReports();
      } else {
        throw Exception('Error: ${response.statusCode}');
      }
    } catch (e) {
      loadingOverlayEntry.remove();
      showNotification('${s.updateError}: ${e.toString()}', false);
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
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: onSurface),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  void showUpdateStatusDialog(BuildContext context, Map<String, dynamic> report) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    selectedStatus = statuses.firstWhere(
      (status) => status["id"] == report['status'],
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
            bool showAmountField = selectedStatus?["id"] == 5;

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
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2)),
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
                                colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.edit_note, color: Colors.white, size: 24),
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
                                  style: TextStyle(fontSize: 13, color: onSurface.withOpacity(0.6)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: Icon(Icons.close, size: 20, color: onSurface.withOpacity(0.7)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                            child: DropdownButtonFormField<Map<String, dynamic>>(
                              value: selectedStatus,
                              isExpanded: true,
                              dropdownColor: surface,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: InputBorder.none,
                                prefixIcon: Icon(Icons.playlist_add_check, color: Colors.orange.shade700),
                                fillColor: Colors.transparent,
                              ),
                              hint: Text(s.selectPaymentStatus, style: const TextStyle(fontSize: 14)),
                              icon: Icon(Icons.arrow_drop_down, color: Colors.orange.shade700),
                              items: statuses.map<DropdownMenuItem<Map<String, dynamic>>>((status) {
                                Color statusColor = _getStatusColor(status["id"]);
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: status,
                                  child: Row(
                                    children: [
                                      Icon(_getStatusIcon(status["id"]), size: 18, color: statusColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        status["name"],
                                        style: TextStyle(fontSize: 14, color: onSurface),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setModalState(() {
                                  selectedStatus = value;
                                  showAmountField = selectedStatus?["id"] == 5;
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
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: onSurface),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: amountController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(fontSize: 14, color: onSurface),
                              decoration: InputDecoration(
                                hintText: s.enterAmount,
                                hintStyle: TextStyle(fontSize: 14, color: onSurface.withOpacity(0.4)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: outline),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
                                ),
                                prefixIcon: Icon(Icons.monetization_on, size: 20, color: Colors.orange.shade700),
                                suffixText: report['currency_name'] ?? '',
                                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: onSurface),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: notesController,
                            maxLines: 2,
                            style: TextStyle(fontSize: 14, color: onSurface),
                            decoration: InputDecoration(
                              hintText: s.addComment,
                              hintStyle: TextStyle(fontSize: 14, color: onSurface.withOpacity(0.4)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: outline),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
                              ),
                              prefixIcon: Icon(Icons.comment, size: 20, color: Colors.orange.shade700),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                final Map<String, dynamic> statusToUpdate =
                                    Map<String, dynamic>.from(selectedStatus!);
                                final String notesText = notesController.text;
                                final String? partialPrice =
                                    showAmountField ? amountController.text : null;
                                updateReportStatus(report, statusToUpdate, notesText, partialPrice);
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: const Color(0xFFFF9800),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                s.save,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

  void _logout() {
    final s = S.of(context);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 10,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.logout, color: Colors.red.shade700, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  s.logOut,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: onSurface),
                ),
                const SizedBox(height: 12),
                Text(
                  s.logOutConfirm,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: onSurface.withOpacity(0.7)),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          s.cancel,
                          style: TextStyle(
                            fontSize: 14,
                            color: onSurface.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await storage.delete(key: "jwt");
                          } catch (_) {}
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => LoginPage()),
                            (Route<dynamic> route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          s.logOutBtn,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerCard() {
    final theme = Theme.of(context);
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.outline,
      highlightColor: theme.colorScheme.surface,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              width: double.infinity,
              height: 40,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(width: 14, height: 14, color: theme.cardColor),
                    const SizedBox(width: 8),
                    Container(width: 120, height: 12, color: theme.cardColor),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Container(width: 14, height: 14, color: theme.cardColor),
                    const SizedBox(width: 8),
                    Container(width: 160, height: 12, color: theme.cardColor),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Container(width: 14, height: 14, color: theme.cardColor),
                    const SizedBox(width: 8),
                    Container(width: 140, height: 12, color: theme.cardColor),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: Container(height: 12, color: theme.cardColor)),
                    const SizedBox(width: 20),
                    Expanded(child: Container(height: 12, color: theme.cardColor)),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    width: 80,
                    height: 20,
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(10),
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

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final surface = theme.colorScheme.surface;
    final outline = theme.colorScheme.outline;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          s.paymentAgreements,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white, size: 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
            tooltip: s.settingsTooltip,
            splashRadius: 24,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white, size: 24),
            onPressed: _logout,
            tooltip: s.exitTooltip,
            splashRadius: 24,
          ),
        ],
      ),
      body: isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: 5,
              itemBuilder: (context, index) => _buildShimmerCard(),
            )
          : paymentReports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.business_center, size: 70, color: Colors.orange.shade300),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        s.noContracts,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: onSurface.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _refreshData,
                        icon: const Icon(Icons.refresh, size: 20),
                        label: Text(s.refresh, style: const TextStyle(fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9800),
                          foregroundColor: Colors.white,
                          elevation: 3,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  color: const Color(0xFFFF9800),
                  child: FadeTransition(
                    opacity: _animation,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: paymentReports.length,
                      itemBuilder: (context, index) {
                        final report = paymentReports[index];
                        Color statusColor;
                        IconData statusIcon;

                        switch (report['status']) {
                          case 2:
                            statusColor = const Color(0xFF43A047);
                            statusIcon = Icons.check_circle;
                            break;
                          case 3:
                            statusColor = const Color(0xFFD32F2F);
                            statusIcon = Icons.cancel;
                            break;
                          case 5:
                            statusColor = const Color(0xFFEF6C00);
                            statusIcon = Icons.account_balance_wallet;
                            break;
                          default:
                            statusColor = const Color(0xFF1976D2);
                            statusIcon = Icons.pending;
                        }

                        Color payingTypeColor = const Color(0xFFD32F2F);
                        if (report['raport_paying_type_name'] != null) {
                          if (report['raport_paying_type_name']
                              .toString()
                              .toLowerCase()
                              .contains('пост')) {
                            payingTypeColor = const Color(0xFF43A047);
                          }
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              if (report['has_change']) {
                                showUpdateStatusDialog(context, report);
                              } else {
                                showNotification(s.noPermission, false);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        onSurface.withOpacity(0.04),
                                        onSurface.withOpacity(0.08),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      topRight: Radius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFF9800), Color(0xFFFF7043)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.orange.withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.business, color: Colors.white, size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          report['bussines_name'] ?? s.unnamed,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: onSurface,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (report['has_change'])
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.blue.shade100, width: 1),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.edit, size: 12, color: Colors.blue.shade700),
                                              const SizedBox(width: 4),
                                              Text(
                                                s.available,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.blue.shade700,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildInfoCard(
                                              Icons.description,
                                              s.contract,
                                              report['contract'] ?? s.noData,
                                              Colors.blue.shade50,
                                              Colors.blue.shade700,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _buildInfoCard(
                                              Icons.subject,
                                              s.subject,
                                              report['sub_contract'] ?? s.noData,
                                              Colors.purple.shade50,
                                              Colors.purple.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _buildInfoRow(
                                        s.applicant,
                                        report['applicant_name'] ?? s.notSpecified,
                                        Icons.person,
                                        Colors.blueGrey.shade600,
                                        onSurface: onSurface,
                                        outline: outline,
                                        surface: surface,
                                      ),
                                      const SizedBox(height: 6),
                                      if (report['raport_paying_type_name'] != null)
                                        _buildInfoRow(
                                          s.paymentType,
                                          report['raport_paying_type_name'],
                                          Icons.credit_card,
                                          payingTypeColor,
                                          isBold: true,
                                          onSurface: onSurface,
                                          outline: outline,
                                          surface: surface,
                                        ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: onSurface.withOpacity(0.04),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: outline, width: 1),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.account_balance, size: 12, color: Colors.orange.shade700),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        s.contractAmount,
                                                        style: TextStyle(fontSize: 9, color: onSurface.withOpacity(0.5)),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    formatCurrency(report['contract_price']),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: onSurface,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(width: 1, height: 40, color: outline),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.payment, size: 12, color: Colors.green.shade700),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        s.toPay,
                                                        style: TextStyle(fontSize: 9, color: onSurface.withOpacity(0.5)),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    formatCurrency(report['paid']),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: onSurface,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(width: 1, height: 40, color: outline),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.currency_exchange, size: 12, color: Colors.indigo.shade700),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        s.currency,
                                                        style: TextStyle(fontSize: 9, color: onSurface.withOpacity(0.5)),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    report['currency_name'] ?? '-',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: onSurface,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(statusIcon, color: statusColor, size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${s.statusLabel}: ${report['status_name'] ?? '-'}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ),
                                            if (report['contract_document_url'] != null)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(Icons.file_present, color: Colors.blue.shade700, size: 18),
                                                    onPressed: () => _launchURL(report['contract_document_url']),
                                                    tooltip: 'Просмотр файла',
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                                  ),
                                                  IconButton(
                                                    icon: Icon(Icons.copy, color: Colors.blue.shade700, size: 18),
                                                    onPressed: () async {
                                                      final fullUrl = 'https://uztex.pro${report['contract_document_url']}';
                                                      Clipboard.setData(ClipboardData(text: fullUrl));
                                                      showNotification(s.urlCopiedShort, true);
                                                    },
                                                    tooltip: 'Копировать ссылку',
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (report['notes'] != null && report['notes'].toString().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 12),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade50,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.amber.shade200, width: 1),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Icon(Icons.note, color: Colors.amber.shade800, size: 16),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    report['notes'],
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: onSurface.withOpacity(0.7),
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (report['has_change'])
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFFFF9800), Color(0xFFFF7043)],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.touch_app, color: Colors.white, size: 14),
                                          const SizedBox(width: 6),
                                          Text(
                                            s.tapToChangeStatus,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
      floatingActionButton: _showBackToTopButton
          ? FloatingActionButton(
              onPressed: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              },
              backgroundColor: const Color(0xFFFF9800),
              child: const Icon(Icons.arrow_upward, color: Colors.white),
              mini: true,
            )
          : null,
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String label,
    String value,
    Color backgroundColor,
    Color iconColor,
  ) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: iconColor, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: onSurface),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon,
    Color valueColor, {
    bool isBold = false,
    required Color onSurface,
    required Color outline,
    required Color surface,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: onSurface.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: onSurface.withOpacity(0.5)),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 11,
              color: onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: valueColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
