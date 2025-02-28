import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfidentialityPage extends StatefulWidget {
  @override
  _ConfidentialityPageState createState() => _ConfidentialityPageState();
}

class _ConfidentialityPageState extends State<ConfidentialityPage> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  bool _isAuthenticated = false;
  bool _useBiometrics = false;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _loadBiometricPreference();
  }

  Future<void> _checkBiometrics() async {
    bool canCheckBiometrics;
    List<BiometricType> availableBiometrics;
    try {
      canCheckBiometrics = await auth.canCheckBiometrics;
      availableBiometrics = await auth.getAvailableBiometrics();
      print("Available biometrics: $availableBiometrics");
    } catch (e) {
      canCheckBiometrics = false;
      availableBiometrics = <BiometricType>[];
      print("Error checking biometrics: $e");
    }
    if (!mounted) return;
    setState(() {
      _canCheckBiometrics = canCheckBiometrics;
      _availableBiometrics = availableBiometrics;
    });
  }

  Future<void> _loadBiometricPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? useBiometrics = prefs.getBool('useBiometrics');
    setState(() {
      _useBiometrics = useBiometrics ?? false;
    });
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      authenticated = await auth.authenticate(
        localizedReason: 'Authenticate to access confidentiality settings',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      print("Authentication successful");
    } catch (e) {
      authenticated = false;
      print("Authentication error: $e");
    }
    if (!mounted) return;
    setState(() {
      _isAuthenticated = authenticated;
    });
  }

  Future<void> _toggleBiometricPreference(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _useBiometrics = value;
    });
    await prefs.setBool('useBiometrics', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Конфиденциальность',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange, Colors.red],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: _isAuthenticated
            ? _buildAuthenticatedContent()
            : _buildUnauthenticatedContent(),
      ),
    );
  }

  Widget _buildAuthenticatedContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.security, size: 100, color: Colors.orange),
          SizedBox(height: 20),
          Text(
            'Настройки конфиденциальности',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 40),
          ListTile(
            leading: Icon(Icons.fingerprint, color: Colors.orange),
            title: Text(
              'Использовать биометрическую аутентификацию',
              style: TextStyle(fontSize: 18, color: Colors.black87),
            ),
            trailing: Switch.adaptive(
              value: _useBiometrics,
              onChanged:
                  _canCheckBiometrics ? _toggleBiometricPreference : null,
              activeColor: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnauthenticatedContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 100, color: Colors.orange),
          SizedBox(height: 20),
          Text(
            'Пожалуйста, пройдите биометрическую аутентификацию для доступа к настройкам конфиденциальности.',
            style: TextStyle(fontSize: 18, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _authenticate,
            icon: Icon(Icons.fingerprint),
            label: Text(
              'Аутентификация',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
              elevation: 5,
            ),
          ),
        ],
      ),
    );
  }
}
