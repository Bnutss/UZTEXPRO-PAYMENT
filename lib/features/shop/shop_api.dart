import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:uztexpro_payment/main.dart';

/// Image links may come back relative ("/media/..."), scheme-relative or with
/// a plain-http scheme depending on how the server sees the request; iOS
/// blocks cleartext http, so always resolve against the API's own https host.
String? _imageUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final origin = Uri.parse(API).origin;
  if (url.startsWith('//')) return 'https:$url';
  if (url.startsWith('/')) return '$origin$url';
  if (url.startsWith('http://')) return 'https://${url.substring(7)}';
  return url;
}

/// Seller's pay for a period: 5% of the sales total, rounded to the nearest
/// 100 so'm. Same rule the sales report on the web uses.
int pvzSellerSalary(double totalValue) {
  if (totalValue <= 0) return 0;
  return ((totalValue * 0.05) / 100).round() * 100;
}

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
    required this.buyerId,
    required this.buyerName,
    required this.sellerName,
    required this.items,
    required this.totalAmount,
    required this.totalValue,
    required this.createAt,
    required this.confirmedAt,
    required this.isIssued,
    required this.issuedAt,
    required this.issuedByName,
    required this.buyerPhotoUrl,
    required this.buyerAvatarUrl,
  });

  final int id;
  final String shopName;
  final int? buyerId;
  final String buyerName;
  final String sellerName;
  final List<PvzOrderItem> items;
  final double totalAmount;
  final double totalValue;
  final DateTime createAt;
  final DateTime? confirmedAt;
  final bool isIssued;
  final DateTime? issuedAt;
  final String? issuedByName;
  /// Hand-over snapshot — only exists once the order has been issued.
  final String? buyerPhotoUrl;

  /// The buyer's own profile photo; present whenever they have one.
  final String? buyerAvatarUrl;

  factory PvzOrder.fromJson(Map<String, dynamic> json) => PvzOrder(
        id: json['id'] as int,
        shopName: json['shop_name'] as String? ?? '',
        buyerId: json['buyer'] as int?,
        buyerName: json['buyer_name'] as String? ?? '',
        sellerName: json['seller_name'] as String? ?? '',
        items: (json['items'] as List? ?? [])
            .map((e) => PvzOrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
        totalValue: (json['total_value'] as num?)?.toDouble() ?? 0,
        createAt: DateTime.parse(json['create_at'] as String),
        confirmedAt: json['confirmed_at'] != null ? DateTime.parse(json['confirmed_at'] as String) : null,
        isIssued: json['is_issued'] as bool? ?? false,
        issuedAt: json['issued_at'] != null ? DateTime.parse(json['issued_at'] as String) : null,
        issuedByName: json['issued_by_name'] as String?,
        buyerPhotoUrl: _imageUrl(json['buyer_photo'] as String?),
        buyerAvatarUrl: _imageUrl(json['buyer_avatar'] as String?),
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

class AnalyticsStockRow {
  AnalyticsStockRow({
    required this.article,
    required this.name,
    required this.color,
    required this.size,
    required this.shopName,
    required this.amount,
    required this.value,
  });

  final String article;
  final String name;
  final String color;
  final String size;
  final String shopName;
  final double amount;
  final double value;

  factory AnalyticsStockRow.fromJson(Map<String, dynamic> json) => AnalyticsStockRow(
        article: json['article'] as String? ?? '',
        name: json['name'] as String? ?? '',
        color: json['color'] as String? ?? '',
        size: json['size'] as String? ?? '',
        shopName: json['shop_name'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        value: (json['value'] as num?)?.toDouble() ?? 0,
      );
}

/// One leaderboard row — a product, a shop or a buyer, depending on which
/// list of [ProductAnalytics] it came from.
class AnalyticsRankRow {
  AnalyticsRankRow({
    required this.title,
    required this.subtitle,
    required this.totalAmount,
    required this.totalValue,
    required this.salesCount,
    this.shopId,
  });

  final String title;
  final String subtitle;
  final double totalAmount;
  final double totalValue;
  final int salesCount;
  final int? shopId;

  static double _n(dynamic v) => (v as num?)?.toDouble() ?? 0;

  factory AnalyticsRankRow.product(Map<String, dynamic> j) => AnalyticsRankRow(
        title: '${j['article'] ?? ''} · ${j['name'] ?? ''}',
        subtitle: j['color'] as String? ?? '',
        totalAmount: _n(j['total_amount']),
        totalValue: _n(j['total_value']),
        salesCount: j['sales_count'] as int? ?? 0,
      );

  factory AnalyticsRankRow.shop(Map<String, dynamic> j) => AnalyticsRankRow(
        title: j['shop_name'] as String? ?? '',
        subtitle: '',
        totalAmount: _n(j['total_amount']),
        totalValue: _n(j['total_value']),
        salesCount: j['sales_count'] as int? ?? 0,
        shopId: j['shop'] as int?,
      );

  factory AnalyticsRankRow.buyer(Map<String, dynamic> j) => AnalyticsRankRow(
        title: j['buyer_name'] as String? ?? '—',
        subtitle: [j['factory_name'], j['shop_name']]
            .where((e) => e != null && '$e'.isNotEmpty)
            .join(' · '),
        totalAmount: _n(j['total_amount']),
        totalValue: _n(j['total_value']),
        salesCount: j['sales_count'] as int? ?? 0,
        shopId: j['shop'] as int?,
      );
}

class ProductAnalytics {
  ProductAnalytics({
    required this.stock,
    required this.stockAmount,
    required this.stockValue,
    required this.topProducts,
    required this.topShops,
    required this.topBuyers,
  });

  final List<AnalyticsStockRow> stock;
  final double stockAmount;
  final double stockValue;
  final List<AnalyticsRankRow> topProducts;
  final List<AnalyticsRankRow> topShops;
  final List<AnalyticsRankRow> topBuyers;

  double get soldAmount => topShops.fold(0, (a, r) => a + r.totalAmount);
  double get soldValue => topShops.fold(0, (a, r) => a + r.totalValue);

  factory ProductAnalytics.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) =>
        (json[key] as List? ?? []).cast<Map<String, dynamic>>();
    final totals = (json['stock_totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ProductAnalytics(
      stock: list('stock').map(AnalyticsStockRow.fromJson).toList(),
      stockAmount: (totals['total_amount'] as num?)?.toDouble() ?? 0,
      stockValue: (totals['total_value'] as num?)?.toDouble() ?? 0,
      topProducts: list('top_products').map(AnalyticsRankRow.product).toList(),
      topShops: list('top_shops').map(AnalyticsRankRow.shop).toList(),
      topBuyers: list('top_buyers').map(AnalyticsRankRow.buyer).toList(),
    );
  }
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

  /// Auth header for `Image.network` — the buyer-face endpoint needs the
  /// same bearer token as the JSON API.
  static Map<String, String> imageHeaders(String jwtToken) =>
      {'Authorization': 'Bearer ${_token(jwtToken)}'};

  /// The buyer's access photo (Employee.face), served as an image. Last
  /// resort when there is neither a profile photo nor a hand-over snapshot.
  static String buyerFaceUrl(int buyerId) => '$API/shop/buyer-face/$buyerId/';

  static Map<String, String> _headers(String jwtToken) => {
        'Authorization': 'Bearer ${_token(jwtToken)}',
        'Content-Type': 'application/json',
      };

  static Future<List<PvzOrder>> fetchPending(
    String jwtToken, {
    String query = '',
    DateTime? dateFrom,
    DateTime? dateTo,
    int? shopId,
  }) async {
    try {
      final params = <String, String>{};
      if (query.isNotEmpty) params['q'] = query;
      if (dateFrom != null) params['date_from'] = _dateOnly(dateFrom);
      if (dateTo != null) params['date_to'] = _dateOnly(dateTo);
      if (shopId != null) params['shop'] = '$shopId';
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
      // This endpoint is paginated ({count, results, ...}, 12 per page by
      // default), so ask for everything and accept a bare list as well.
      final res = await http
          .get(Uri.parse('$API/shop/shop/?limit=500'), headers: _headers(jwtToken))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw PvzApiException(_extractError(res.body, fallback: 'Не удалось загрузить магазины'));
      }
      final body = json.decode(utf8.decode(res.bodyBytes));
      final decoded = body is Map ? (body['results'] as List? ?? const []) : body as List;
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

  static Future<ProductAnalytics> fetchProductAnalytics(
    String jwtToken, {
    int? shopId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String query = '',
  }) async {
    try {
      final params = <String, String>{};
      if (shopId != null) params['shop'] = '$shopId';
      if (dateFrom != null) params['date_from'] = _dateOnly(dateFrom);
      if (dateTo != null) params['date_to'] = _dateOnly(dateTo);
      if (query.isNotEmpty) params['q'] = query;
      final uri = Uri.parse('$API/shop/product-analytics/').replace(queryParameters: params.isNotEmpty ? params : null);
      final res = await http.get(uri, headers: _headers(jwtToken)).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw PvzApiException(_extractError(res.body, fallback: 'Не удалось загрузить аналитику'));
      }
      return ProductAnalytics.fromJson(json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
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
