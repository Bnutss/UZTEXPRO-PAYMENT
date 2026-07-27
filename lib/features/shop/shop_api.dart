import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:uztexpro_payment/main.dart';

class PvzOrderItem {
  PvzOrderItem({
    required this.article,
    required this.productName,
    required this.color,
    required this.sizeName,
    required this.amount,
    required this.price,
  });

  final String article;
  final String productName;
  final String color;
  final String sizeName;
  final double amount;
  final double price;

  double get subtotal => amount * price;

  factory PvzOrderItem.fromJson(Map<String, dynamic> json) => PvzOrderItem(
        article: json['article'] as String? ?? '',
        productName: json['product_name'] as String? ?? '',
        color: json['color'] as String? ?? '',
        sizeName: json['size_name'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        price: (json['price'] as num?)?.toDouble() ?? 0,
      );
}

class PvzOrder {
  PvzOrder({
    required this.id,
    required this.buyerName,
    required this.sellerName,
    required this.items,
    required this.totalAmount,
    required this.totalValue,
    required this.createAt,
    required this.isIssued,
  });

  final int id;
  final String buyerName;
  final String sellerName;
  final List<PvzOrderItem> items;
  final double totalAmount;
  final double totalValue;
  final DateTime createAt;
  final bool isIssued;

  factory PvzOrder.fromJson(Map<String, dynamic> json) => PvzOrder(
        id: json['id'] as int,
        buyerName: json['buyer_name'] as String? ?? '',
        sellerName: json['seller_name'] as String? ?? '',
        items: (json['items'] as List? ?? [])
            .map((e) => PvzOrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
        totalValue: (json['total_value'] as num?)?.toDouble() ?? 0,
        createAt: DateTime.parse(json['create_at'] as String),
        isIssued: json['is_issued'] as bool? ?? false,
      );
}

class PvzApiException implements Exception {
  PvzApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Talks to the same shop backend as uztexpro_store, but from the PVZ
/// (pickup-point) side: lists orders placed by a seller that are still
/// waiting to be handed over, and confirms the handover with a photo.
class PvzApi {
  PvzApi._();

  static String _token(String jwtToken) {
    try {
      return jsonDecode(jwtToken)['token'] as String;
    } catch (_) {
      return jwtToken;
    }
  }

  static Map<String, String> _headers(String jwtToken) => {
        'Authorization': 'Bearer ${_token(jwtToken)}',
        'Content-Type': 'application/json',
      };

  static Future<List<PvzOrder>> fetchPending(String jwtToken, {String query = ''}) async {
    try {
      final uri = Uri.parse('$API/shop/sale-pending/').replace(
        queryParameters: query.isNotEmpty ? {'q': query} : null,
      );
      final res = await http.get(uri, headers: _headers(jwtToken)).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw PvzApiException(_extractError(res.body, fallback: 'Не удалось загрузить заказы'));
      }
      final decoded = json.decode(utf8.decode(res.bodyBytes)) as List;
      return decoded.map((e) => PvzOrder.fromJson(e as Map<String, dynamic>)).toList();
    } on PvzApiException {
      rethrow;
    } catch (_) {
      throw PvzApiException('Не удалось подключиться к серверу');
    }
  }

  static Future<void> issueOrder(String jwtToken, int orderId, String photoBase64) async {
    try {
      final res = await http
          .post(
            Uri.parse('$API/shop/sale/$orderId/issue/'),
            headers: _headers(jwtToken),
            body: jsonEncode({'photo': photoBase64}),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200 && res.statusCode != 201) {
        throw PvzApiException(_extractError(res.body, fallback: 'Не удалось выдать заказ'));
      }
    } on PvzApiException {
      rethrow;
    } catch (_) {
      throw PvzApiException('Не удалось подключиться к серверу');
    }
  }

  static String _extractError(String body, {required String fallback}) {
    try {
      final data = json.decode(body);
      if (data is Map) {
        for (final value in data.values) {
          if (value is String) return value;
          if (value is List && value.isNotEmpty) return value.first.toString();
        }
        if (data['message'] is String) return data['message'] as String;
      }
    } catch (_) {}
    return fallback;
  }
}
