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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    notesController.dispose();
    amountController.dispose();
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
          onTimeout: () => throw Exception('Превышено время ожидания'),
        );

        if (response.statusCode == 200) {
          final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
          await storage.write(key: storageKey, value: jsonEncode(jsonResponse));
          setState(() {
            statuses = jsonResponse;
          });
        } else {
          throw Exception('Не удалось загрузить статусы');
        }
      }
    } catch (e) {
      showNotification('Ошибка при загрузке статусов', false);
    }
  }

  Future<void> fetchPaymentReports() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse("$API/edo/payment-raport/?for_mobile=1"),
        headers: {
          "Authorization": "Bearer ${jsonDecode(widget.jwtToken)["token"]}"
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Превышено время ожидания'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          paymentReports = jsonResponse['results'];
          isLoading = false;
        });
        _animationController.forward();
      } else {
        throw Exception('Не удалось загрузить платежные рапорты');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      showNotification('Ошибка при загрузке данных', false);
    }
  }

  Future<void> _refreshData() async {
    _animationController.reset();
    await fetchPaymentReports();
    return Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _launchURL(String url) async {
    final fullUrl = 'https://uztex.pro$url';

    try {
      final Uri uri = Uri.parse(fullUrl);
      if (!await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      )) {
        showNotification('Не удалось открыть файл', false);
        await Clipboard.setData(ClipboardData(text: fullUrl));
        showNotification('URL скопирован в буфер обмена', true);
      }
    } catch (e) {
      showNotification('Ошибка при открытии файла', false);
      await Clipboard.setData(ClipboardData(text: fullUrl));
      showNotification('URL скопирован в буфер обмена', true);
    }
  }

  void showUpdateStatusDialog(
      BuildContext context, Map<String, dynamic> report) {
    selectedStatus = statuses.firstWhere(
      (status) => status["id"] == report['status'],
      orElse: () => null,
    );

    notesController.text = report['notes'] ?? '';
    amountController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool showAmountField = selectedStatus?["id"] == 5;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 10,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                          child: const Icon(
                            Icons.update,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Обновление статуса платежа',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          padding: EdgeInsets.zero,
                          splashRadius: 24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.grey.shade100, Colors.grey.shade200],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${report['bussines_name'] ?? "Без названия"}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          _buildDialogInfoRow(Icons.description, 'Договор:',
                              '${report['contract'] ?? 'Нет данных'}'),
                          const SizedBox(height: 6),
                          _buildDialogInfoRow(Icons.subject, 'Предмет:',
                              '${report['sub_contract'] ?? 'Нет данных'}'),
                          const SizedBox(height: 6),
                          _buildDialogInfoRow(Icons.monetization_on, 'Сумма:',
                              '${formatCurrency(report['contract_price'])} ${report['currency_name'] ?? ''}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Выберите статус платежа:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        color: Colors.grey.shade50,
                      ),
                      child: DropdownButtonFormField<Map<String, dynamic>>(
                        value: selectedStatus,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.playlist_add_check,
                              color: Colors.orange.shade700),
                        ),
                        hint: const Text("Выберите статус платежа",
                            style: TextStyle(fontSize: 14)),
                        icon: Icon(Icons.arrow_drop_down,
                            color: Colors.orange.shade700),
                        items: statuses
                            .map<DropdownMenuItem<Map<String, dynamic>>>(
                                (status) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: status,
                            child: Text(status["name"],
                                style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedStatus = value;
                            showAmountField = selectedStatus?["id"] == 5;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (showAmountField)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Сумма частичной оплаты:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Введите сумму',
                              hintStyle: TextStyle(
                                  fontSize: 14, color: Colors.grey.shade500),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.orange.shade700, width: 2),
                              ),
                              prefixIcon: Icon(Icons.monetization_on,
                                  size: 20, color: Colors.orange.shade700),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    Text(
                      'Примечание:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Добавьте комментарий...',
                        hintStyle: TextStyle(
                            fontSize: 14, color: Colors.grey.shade500),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.orange.shade700, width: 2),
                        ),
                        prefixIcon: Icon(Icons.comment,
                            size: 20, color: Colors.orange.shade700),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            "ОТМЕНА",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            if (selectedStatus == null) {
                              showNotification(
                                  'Пожалуйста, выберите статус', false);
                              return;
                            }

                            Navigator.of(context).pop();

                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (BuildContext context) {
                                return Dialog(
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: const Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Color(0xFFFF9800)),
                                            strokeWidth: 3,
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'Обновление статуса...',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );

                            try {
                              var requestData = {
                                'notes': notesController.text,
                                'status': selectedStatus?["id"],
                              };

                              if (amountController.text.isNotEmpty) {
                                requestData['partial_price'] =
                                    amountController.text;
                              }

                              var response = await http
                                  .patch(
                                    Uri.parse(
                                        "$API/edo/payment-raport/${report['id']}/"),
                                    headers: {
                                      "Content-Type": "application/json",
                                      "Authorization":
                                          "Bearer ${jsonDecode(widget.jwtToken)["token"]}",
                                    },
                                    body: jsonEncode(requestData),
                                  )
                                  .timeout(
                                    const Duration(seconds: 20),
                                    onTimeout: () => http.Response(
                                        'Время ожидания истекло', 408),
                                  );
                              Navigator.of(context).pop();

                              if (response.statusCode == 200 ||
                                  response.statusCode == 201) {
                                showNotification(
                                    'Статус платежа успешно обновлен', true);
                                fetchPaymentReports();
                              } else {
                                showNotification(
                                    'Ошибка при обновлении статуса', false);
                              }
                            } catch (e) {
                              Navigator.of(context).pop();
                              showNotification(
                                  'Произошла ошибка при обновлении', false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF9800),
                            foregroundColor: Colors.white,
                            elevation: 3,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "СОХРАНИТЬ",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
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
      },
    );
  }

  Widget _buildDialogInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.orange.shade700,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                  child: Icon(
                    Icons.logout,
                    color: Colors.red.shade700,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Выход из системы",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Вы уверены, что хотите выйти из учетной записи?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "ОТМЕНА",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          storage.delete(key: "jwtToken").then((_) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (context) => LoginPage()),
                              (Route<dynamic> route) => false,
                            );
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "ВЫЙТИ",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
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
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              width: double.infinity,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
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
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 120,
                        height: 12,
                        color: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 160,
                        height: 12,
                        color: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 140,
                        height: 12,
                        color: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 12,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Container(
                          height: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 80,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
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
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "Платежные договоры",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
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
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
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
            tooltip: 'Настройки',
            splashRadius: 24,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white, size: 24),
            onPressed: _logout,
            tooltip: 'Выйти',
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
                        child: Icon(
                          Icons.business_center,
                          size: 70,
                          color: Colors.orange.shade300,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Нет доступных платежных договоров",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _refreshData,
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text("Обновить",
                            style: TextStyle(fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9800),
                          foregroundColor: Colors.white,
                          elevation: 3,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              if (report['has_change']) {
                                showUpdateStatusDialog(context, report);
                              } else {
                                showNotification(
                                    'У вас нет прав на изменение статуса',
                                    false);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.grey.shade50,
                                        Colors.grey.shade100
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
                                            colors: [
                                              Color(0xFFFF9800),
                                              Color(0xFFFF7043)
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.orange
                                                  .withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.business,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          report['bussines_name'] ??
                                              "Без названия",
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF424242),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (report['has_change'])
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors.blue.shade100,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.edit,
                                                size: 12,
                                                color: Colors.blue.shade700,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Доступно',
                                                style: TextStyle(
                                                  fontSize: 12,
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
                                              'Договор',
                                              report['contract'] ??
                                                  'Нет данных',
                                              Colors.blue.shade50,
                                              Colors.blue.shade700,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _buildInfoCard(
                                              Icons.subject,
                                              'Предмет',
                                              report['sub_contract'] ??
                                                  'Нет данных',
                                              Colors.purple.shade50,
                                              Colors.purple.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _buildInfoRow(
                                        'Заявитель',
                                        report['update_by'] ?? 'Не указан',
                                        Icons.person,
                                        Colors.blueGrey.shade600,
                                      ),
                                      const SizedBox(height: 8),
                                      if (report['raport_paying_type_name'] !=
                                          null)
                                        _buildInfoRow(
                                          'Тип оплаты',
                                          report['raport_paying_type_name'],
                                          Icons.credit_card,
                                          payingTypeColor,
                                          isBold: true,
                                        ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.account_balance,
                                                        size: 14,
                                                        color: Colors
                                                            .orange.shade700,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Сумма договора',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Colors
                                                              .grey.shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    formatCurrency(report[
                                                        'contract_price']),
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF424242),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 40,
                                              color: Colors.grey.shade300,
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.payment,
                                                        size: 14,
                                                        color: Colors
                                                            .green.shade700,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'К оплате',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Colors
                                                              .grey.shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    formatCurrency(
                                                        report['paid']),
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF424242),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 40,
                                              color: Colors.grey.shade300,
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.currency_exchange,
                                                        size: 14,
                                                        color: Colors
                                                            .indigo.shade700,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Валюта',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Colors
                                                              .grey.shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    report['currency_name'] ??
                                                        '-',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF424242),
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
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: statusColor.withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              statusIcon,
                                              color: statusColor,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Статус: ${report['status_name'] ?? 'Не определен'}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ),
                                            if (report[
                                                    'contract_document_url'] !=
                                                null)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.file_present,
                                                      color:
                                                          Colors.blue.shade700,
                                                      size: 20,
                                                    ),
                                                    onPressed: () {
                                                      _launchURL(report[
                                                          'contract_document_url']);
                                                    },
                                                    tooltip: 'Просмотр файла',
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 32,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.copy,
                                                      color:
                                                          Colors.blue.shade700,
                                                      size: 20,
                                                    ),
                                                    onPressed: () async {
                                                      final fullUrl =
                                                          'https://uztex.pro${report['contract_document_url']}';
                                                      Clipboard.setData(
                                                          ClipboardData(
                                                              text: fullUrl));
                                                      showNotification(
                                                          'URL скопирован',
                                                          true);
                                                    },
                                                    tooltip:
                                                        'Копировать ссылку',
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 32,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (report['notes'] != null &&
                                          report['notes'].toString().isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 12),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.amber.shade200,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  Icons.note,
                                                  color: Colors.amber.shade800,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    report['notes'],
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color:
                                                          Colors.grey.shade800,
                                                      fontStyle:
                                                          FontStyle.italic,
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
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFFFF9800),
                                          const Color(0xFFFF7043)
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.touch_app,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Нажмите для изменения статуса',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
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
              child: const Icon(
                Icons.arrow_upward,
                color: Colors.white,
              ),
              mini: true,
            )
          : null,
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value,
      Color backgroundColor, Color iconColor) {
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
              Icon(
                icon,
                size: 16,
                color: iconColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: iconColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF424242),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      String label, String value, IconData icon, Color valueColor,
      {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
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
