import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uztexpro_payment/main_page.dart';
import 'dart:convert' show json, base64, ascii;
import 'package:uztexpro_payment/login_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PROApp extends StatefulWidget {
  @override
  _ProMobile createState() => _ProMobile();
}

class _ProMobile extends State<PROApp> {
  final storage = FlutterSecureStorage();

  Future<String> get jwtOrEmpty async {
    try {
      var jwt = await storage.read(key: "jwt");
      return jwt ?? "";
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
        ),
        scaffoldBackgroundColor: Colors.blueGrey,
      ),
      home: FutureBuilder<String>(
        future: jwtOrEmpty,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text("Ошибка: ${snapshot.error}"),
            );
          }

          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final jwt = snapshot.data!;
            final parts = jwt.split(".");
            if (parts.length != 3) {
              return LoginPage();
            }

            try {
              final payload = json.decode(
                ascii.decode(base64.decode(base64.normalize(parts[1]))),
              );
              final expirationTime =
                  DateTime.fromMillisecondsSinceEpoch(payload["exp"] * 1000);
              if (expirationTime.isAfter(DateTime.now())) {
                return MainPageScreen(jwtToken: jwt);
              }
            } catch (e) {
              return LoginPage();
            }
          }
          return LoginPage();
        },
      ),
    );
  }
}
