import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:uztexpro_payment/app/pro_app.dart';
import 'core/storage/app_storage.dart';

const API = 'https://pro.uztex.uz/api/v1';
final storage = AppStorage();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  // Known debug-only Flutter framework assertion triggered by native
  // platform views (adaptive_platform_ui's Liquid Glass tab bar/buttons)
  // interacting with the semantics tree. It is caught internally by the
  // scheduler, never affects layout/behavior, and does not exist at all in
  // release builds (assert() is stripped there) — just silence the console
  // spam for it here instead of letting it print on every frame.
  final defaultOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exceptionAsString().contains('semantics.parentDataDirty')) {
      return;
    }
    defaultOnError?.call(details);
  };

  runApp(PROApp());
}
