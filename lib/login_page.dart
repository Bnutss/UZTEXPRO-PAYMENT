import 'dart:convert';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uztexpro_payment/main_page.dart';
import 'package:uztexpro_payment/main.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final LocalAuthentication auth = LocalAuthentication();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FlutterSecureStorage storage = FlutterSecureStorage();
  bool btnClick = false;
  bool obsText = true;
  bool _canCheckBiometrics = false;
  bool _useBiometrics = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await fetchSecureStorageData();
    await checkBiometrics();
    await loadBiometricPreference();

    if (_useBiometrics && _canCheckBiometrics) {
      await loginWithBiometrics(context);
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween(begin: 300.0, end: 50.0).animate(_controller)
      ..addListener(() {
        setState(() {});
      });
  }

  Future<void> checkBiometrics() async {
    try {
      _canCheckBiometrics = await auth.canCheckBiometrics;
    } catch (e) {
      print("Error checking biometrics: $e");
    }
  }

  Future<void> loadBiometricPreference() async {
    String? useBiometrics = await storage.read(key: 'useBiometrics');
    setState(() {
      _useBiometrics = useBiometrics == 'true';
    });
  }

  Future<void> toggleBiometricPreference(bool value) async {
    setState(() {
      _useBiometrics = value;
    });
    await storage.write(key: 'useBiometrics', value: value.toString());
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await auth.authenticate(
        localizedReason: 'Authenticate to log in',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      print("Authentication error: $e");
      return false;
    }
  }

  Future<String?> attemptLogIn(String username, String password) async {
    try {
      var res = await http.post(
        Uri.parse("$API/auth/login/"),
        body: {"username": username, "password": password},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          return http.Response('Error', 408);
        },
      );

      if (res.statusCode == 200) {
        return res.body;
      } else {
        return null;
      }
    } on Exception catch (_) {
      return null;
    }
  }

  Future<void> fetchSecureStorageData() async {
    final username = await storage.read(key: 'username') ?? '';
    final password = await storage.read(key: 'password') ?? '';
    _usernameController.text = username;
    _passwordController.text = password;
  }

  Future<void> loginWithBiometrics(BuildContext context) async {
    if (!_canCheckBiometrics) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Биометрия не поддерживается на этом устройстве')),
      );
      return;
    }

    bool authenticated = await authenticateWithBiometrics();
    if (authenticated) {
      final username = await storage.read(key: 'username');
      final password = await storage.read(key: 'password');
      if (username != null && password != null) {
        var jwt = await attemptLogIn(username, password);
        if (jwt != null) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (context) => MainPageScreen(jwtToken: jwt)),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка входа. Проверьте учетные данные.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Учетные данные не найдены')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Аутентификация не удалась')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (btnClick) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      );
    } else {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(60.0),
          child: AppBar(
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade900, Colors.red.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            title: Text(
              "UZTEXPRO",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade800, Colors.red.shade900],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 50.0),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(height: 20),
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Логин',
                          labelStyle: TextStyle(color: Colors.deepPurple),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Colors.deepPurple, width: 2.0),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          prefixIcon:
                              Icon(Icons.person, color: Colors.deepPurple),
                        ),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: _passwordController,
                        obscureText: obsText,
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          labelStyle: TextStyle(color: Colors.deepPurple),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Colors.deepPurple, width: 2.0),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          prefixIcon:
                              Icon(Icons.lock, color: Colors.deepPurple),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obsText ? Icons.visibility : Icons.visibility_off,
                              color: Colors.deepPurple,
                            ),
                            onPressed: () {
                              setState(() {
                                obsText = !obsText;
                              });
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () async {
                          setState(() {
                            btnClick = true;
                          });
                          var username = _usernameController.text;
                          var password = _passwordController.text;
                          var jwt = await attemptLogIn(username, password);
                          if (jwt != null) {
                            var token = jsonDecode(jwt);
                            await storage.write(
                                key: "username", value: username);
                            await storage.write(
                                key: "password", value: password);
                            await storage.write(key: "jwt", value: jwt);
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      MainPageScreen(jwtToken: jwt)),
                              (route) => false,
                            );
                          } else {
                            setState(() {
                              btnClick = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Логин или пароль неправильный')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        child: Text(
                          "Войти",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(height: 20),
                      if (_canCheckBiometrics)
                        ListTile(
                          leading:
                              Icon(Icons.fingerprint, color: Colors.deepPurple),
                          title: Text(
                            'Использовать биометрию для входа',
                            style:
                                TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                          trailing: Switch.adaptive(
                            value: _useBiometrics,
                            onChanged: (value) =>
                                toggleBiometricPreference(value),
                            activeColor: Colors.deepPurple,
                          ),
                        ),
                      if (_canCheckBiometrics && _useBiometrics)
                        ElevatedButton.icon(
                          onPressed: () => loginWithBiometrics(context),
                          icon: Icon(Icons.fingerprint),
                          label: Text(
                            'Войти с помощью биометрии',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30.0),
                            ),
                            elevation: 5,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
}
