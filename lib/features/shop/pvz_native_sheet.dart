import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_strings.dart';
import 'shop_api.dart';

const _channel = MethodChannel('uztexpro/native_sheet');

/// Opens the native iOS sheet (system close button, detents). Returns false
/// where it isn't available so the caller can fall back to its Flutter UI.
Future<bool> showNativeSheet(Map<String, dynamic> payload) async {
  if (!Platform.isIOS) return false;
  try {
    await _channel.invokeMethod<void>('showSheet', payload);
    return true;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

// Same palette as the settings screen.
const int kSheetBlue = 0xFF3478F6;
const int kSheetIndigo = 0xFF5856D6;
const int kSheetGreen = 0xFF34C759;
const int kSheetOrange = 0xFFFF9500;
const int kSheetRed = 0xFFFF3B30;
const int kSheetGray = 0xFF8E8E93;

String pvzSheetDateTime(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}.${two(l.month)}.${l.year} ${two(l.hour)}:${two(l.minute)}';
}

/// "Items" group (one row per product) and the "Total" group of an order.
List<Map<String, dynamic>> pvzItemSections(
  S s,
  PvzOrder order,
  NumberFormat nf, {
  bool withTitle = true,
}) => [
  {
    if (withTitle) 'title': s.shopPickupItemsHeader,
    'rows': [
      for (final item in order.items)
        {
          'label': '${item.article} — ${item.productName}',
          'subtitle':
              '${item.color} · ${item.sizeName} · ${nf.format(item.amount)} шт',
          'value': '${nf.format(item.subtotal)} сум',
          'accent': true,
        },
    ],
  },
  {
    'rows': [
      {
        'label': s.totalLabel,
        'value': '${nf.format(order.totalValue)} сум',
        'bold': true,
        'accent': true,
      },
    ],
  },
];

Map<String, dynamic> pvzRow(
  String sf,
  int color,
  String label,
  String value,
) => {'sf': sf, 'color': color, 'label': label, 'value': value};
