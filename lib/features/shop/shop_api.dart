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
    required this.shopName,
    required this.buyerName,
    required this.sellerName,
    required this.items,
    required this.totalAmount,
    required this.totalValue,
    required this.createAt,
    required this.isIssued,
    required this.issuedAt,
    required this.issuedByName,
    required this.buyerPhotoUrl,
  });

  final int id;
  final String shopName;
  final String buyerName;
  final String sellerName;
  final List<PvzOrderItem> items;
  final double totalAmount;
  final double totalValue;
  final DateTime createAt;
  final bool isIssued;
  final DateTime? issuedAt;
  final String? issuedByName;
  final String? buyerPhotoUrl;

  factory PvzOrder.fromJson(Map<String, dynamic> json) => PvzOrder(
        id: json['id'] as int,
        shopName: json['shop_name'] as String? ?? '',
        buyerName: json['buyer_name'] as String? ?? '',
        sellerName: json['seller_name'] as String? ?? '',
        items: (json['items'] as List? ?? [])
            .map((e) => PvzOrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
        totalValue: (json['total_value'] as num?)?.toDouble() ?? 0,
        createAt: DateTime.parse(json['create_at'] as String),
        isIssued: json['is_issued'] as bool? ?? false,
        issuedAt: json['issued_at'] != null ? DateTime.parse(json['issued_at'] as String) : null,
        issuedByName: json['issued_by_name'] as String?,
        buyerPhotoUrl: json['buyer_photo'] as String?,
      );
}

class PvzShop {
  PvzShop({required this.id, required this.name});

  final int id;
  final String name;

  factory PvzShop.fromJson(Map<String, dynamic> json) => PvzShop(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
      );
}

class PvzIssuedReport {
  PvzIssuedReport({
    required this.salesCount,
    required this.totalAmount,
    required this.totalValue,
    required this.sales,
  });

  final int salesCount;
  final double totalAmount;
  final double totalValue;
  final List<PvzOrder> sales;

  factory PvzIssuedReport.fromJson(Map<String, dynamic> json) => PvzIssuedReport(
        salesCount: json['sales_count'] as int? ?? 0,
        totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
        totalValue: (json['total_value'] as num?)?.toDouble() ?? 0,
        sales: (json['sales'] as List? ?? [])
            .map((e) => PvzOrder.fromJson(e as Map<String, dynamic>))
            .toList(),
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
/// waiting to be handed over. Handover itself happens on the dedicated
/// ПВЗ web terminal, not in this app.
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

  static Future<List<PvzOrder>> fetchPending(
    String jwtToken, {
    String query = '',
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final params = <String, String>{};
      if (query.isNotEmpty) params['q'] = query;
      if (dateFrom != null) params['date_from'] = _dateOnly(dateFrom);
      if (dateTo != null) params['date_to'] = _dateOnly(dateTo);
      final uri = Uri.parse('$API/shop/sale-pending/').replace(
        queryParameters: params.isNotEmpty ? params : null,
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

  static Future<List<PvzShop>> fetchShops(String jwtToken) async {
    try {
      final res = await http
          .get(Uri.parse('$API/shop/shop/'), headers: _headers(jwtToken))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw PvzApiException(_extractError(res.body, fallback: 'Не удалось загрузить магазины'));
      }
      final decoded = json.decode(utf8.decode(res.bodyBytes)) as List;
      return decoded.map((e) => PvzShop.fromJson(e as Map<String, dynamic>)).toList();
    } on PvzApiException {
      rethrow;
    } catch (_) {
      throw PvzApiException('Не удалось подключиться к серверу');
    }
  }

  static Future<PvzIssuedReport> fetchIssuedReport(
    String jwtToken, {
    int? shopId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final params = <String, String>{};
      if (shopId != null) params['shop'] = '$shopId';
      if (dateFrom != null) params['date_from'] = _dateOnly(dateFrom);
      if (dateTo != null) params['date_to'] = _dateOnly(dateTo);
      final uri = Uri.parse('$API/shop/sale-issued-report/').replace(queryParameters: params.isNotEmpty ? params : null);
      final res = await http.get(uri, headers: _headers(jwtToken)).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw PvzApiException(_extractError(res.body, fallback: 'Не удалось загрузить отчёт'));
      }
      return PvzIssuedReport.fromJson(json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
    } on PvzApiException {
      rethrow;
    } catch (_) {
      throw PvzApiException('Не удалось подключиться к серверу');
    }
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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
