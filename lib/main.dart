import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert' show json, base64, ascii;

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
  runApp(PROApp());
}
