import 'package:flutter/material.dart';
import 'dart:convert' show json, base64, ascii;

import 'package:uztexpro_payment/pro_app.dart';
import 'app_storage.dart';

const API = 'http://pro.uztex.uz/api/v1';
final storage = AppStorage();

void main() {
  runApp(PROApp());
}
