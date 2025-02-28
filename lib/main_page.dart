import 'package:flutter/material.dart';
import 'package:uztexpro_payment/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'settings_screen.dart'; // Импортируйте экран настроек

class MainPageScreen extends StatefulWidget {
  final String jwtToken;

  MainPageScreen({required this.jwtToken});

  @override
  _MainPageScreenState createState() => _MainPageScreenState();
}

class _MainPageScreenState extends State<MainPageScreen> {
  List items = [];
  List statuses = [];
  Map<String, dynamic>? selectedStatus;
  bool isLoading = true;
  TextEditingController textController = TextEditingController();
  TextEditingController numberController = TextEditingController();
  bool showNumberField = false;

  @override
  void initState() {
    super.initState();
    fetchPaymentStatuses();
    fetchData();
  }

  String convertFormatNumber(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return "";
    String cleanedString = value.toString().replaceAll(" ", "");
    double? cleanValue = double.tryParse(cleanedString);
    if (cleanValue == null || cleanValue == 0) return value.toString();
    String formattedValue = cleanedString.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match match) => '${match[1]} ');
    return formattedValue;
  }

  void showToast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void showInputDialog(BuildContext context, Map<String, dynamic> item) {
    double deviceWidth = MediaQuery.of(context).size.width;
    if (!isLoading) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          Map<String, dynamic>? localSelectedStatus = selectedStatus;
          bool showNumberField = localSelectedStatus?["id"] == 5;

          TextEditingController localTextController = TextEditingController();
          TextEditingController localNumberController = TextEditingController();

          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(top: 30.0),
                      width: deviceWidth * 0.8,
                      child: TextField(
                        controller: textController,
                        decoration:
                            const InputDecoration(labelText: "Примечание"),
                      ),
                    ),
                    SizedBox(
                      width: deviceWidth * 0.8,
                      child: DropdownButtonFormField<Map<String, dynamic>>(
                        value: selectedStatus,
                        isExpanded: true,
                        hint: const Text("Статус"),
                        items: statuses
                            .map<DropdownMenuItem<Map<String, dynamic>>>(
                                (status) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: status,
                            child: Text(status["name"]),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            localSelectedStatus = value;
                            showNumberField = localSelectedStatus?["id"] == 5;
                          });
                        },
                      ),
                    ),
                    Visibility(
                      visible: showNumberField,
                      child: TextFormField(
                        controller: numberController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Введите сумма",
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text("Отмена"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    setDialogState(() {
                      isLoading = true;
                    });
                    var dataPost = {
                      'notes': textController.text,
                      'status': localSelectedStatus?["id"],
                    };
                    if (numberController.text.length > 0) {
                      dataPost['partial_price'] = numberController.text;
                    }
                    print(dataPost);

                    var res = await http
                        .patch(
                            Uri.parse("$API/edo/payment-raport/${item['id']}/"),
                            headers: {
                              "Content-Type": "application/json",
                              "Authorization": "Bearer " +
                                  jsonDecode(widget.jwtToken)["token"],
                            },
                            body: jsonEncode(dataPost).toString())
                        .timeout(
                      const Duration(seconds: 20),
                      onTimeout: () {
                        return http.Response('Error', 408);
                      },
                    );

                    if (res.statusCode == 201) {
                      showToast("✅ Успешно!", Colors.green);
                      Navigator.of(context).pop();
                      fetchData();
                    } else {
                      setDialogState(() {
                        isLoading = false;
                      });
                      Navigator.of(context).pop();
                      showToast("❌ Ошибка: ${utf8.decode(res.bodyBytes)}",
                          Colors.red);
                    }
                  },
                  child: const Text("Сохранить"),
                ),
              ],
            );
          });
        },
      );
    } else {
      return;
    }
  }

  Future<void> fetchPaymentStatuses() async {
    const String storageKey = "payment_statuses";

    try {
      String? storedData = await storage.read(key: storageKey);

      if (storedData != null) {
        print("Loading from SecureStorage...");
        setState(() {
          statuses = jsonDecode(storedData);
        });
      } else {
        print("Fetching from API...");
        final response = await http.get(
          Uri.parse("$API/edo/payment-raport-status/"),
          headers: {
            "Authorization": "Bearer ${jsonDecode(widget.jwtToken)["token"]}"
          },
        );

        if (response.statusCode == 200) {
          final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
          print("Fetched from API: $jsonResponse");

          await storage.write(key: storageKey, value: jsonEncode(jsonResponse));

          setState(() {
            statuses = jsonResponse;
          });
        } else {
          throw Exception('Failed to load data');
        }
      }
    } catch (e) {
      print("Error fetching payment statuses: $e");
    }
  }

  Future<void> fetchData() async {
    final response = await http
        .get(Uri.parse("$API/edo/payment-raport/?for_mobile=1"), headers: {
      "Authorization": "Bearer " + jsonDecode(widget.jwtToken)["token"]
    });
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      print(jsonResponse['results']);
      setState(() {
        items = jsonResponse['results'];
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      throw Exception('Failed to load data');
    }
  }

  Future<void> _refreshData() async {
    await fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Рапорты", style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange, Colors.red],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      title: Text(item['bussines_name'] ?? "No Name",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("📜 Договор: ${item['contract'] ?? 'N/A'}"),
                          Text(
                              "👤 Заявитель: ${item['applicant_name'] ?? 'Unknown'}"),
                          Text(
                              "💰 Сумма договор: ${convertFormatNumber(item['contract_price']) ?? 'Unknown'}"),
                          Text(
                              "💰 Сумма к оплате: ${convertFormatNumber(item['paid']) ?? 'Unknown'}"),
                          Text("🔹 Status: ${item['status_name'] ?? 'N/A'}"),
                        ],
                      ),
                      leading: const Icon(Icons.business, color: Colors.blue),
                      onTap: () {
                        showInputDialog(context, item);
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
