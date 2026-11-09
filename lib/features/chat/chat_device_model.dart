import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// What the "Devices" screen shows of a phone: its model, its system and the
/// version of the app.
class ChatDeviceDetails {
  const ChatDeviceDetails({
    required this.model,
    required this.os,
    required this.appVersion,
  });

  /// "iPhone 17 Pro Max", "Samsung SM-S918B".
  final String model;

  /// "iOS 26.5", "Android 14".
  final String os;
  final String appVersion;
}

/// The names behind Apple's model codes (`iPhone18,2` → "iPhone 17 Pro Max").
const _iphones = <String, String>{
  'iPhone11,2': 'iPhone XS',
  'iPhone11,4': 'iPhone XS Max',
  'iPhone11,6': 'iPhone XS Max',
  'iPhone11,8': 'iPhone XR',
  'iPhone12,1': 'iPhone 11',
  'iPhone12,3': 'iPhone 11 Pro',
  'iPhone12,5': 'iPhone 11 Pro Max',
  'iPhone12,8': 'iPhone SE (2nd generation)',
  'iPhone13,1': 'iPhone 12 mini',
  'iPhone13,2': 'iPhone 12',
  'iPhone13,3': 'iPhone 12 Pro',
  'iPhone13,4': 'iPhone 12 Pro Max',
  'iPhone14,2': 'iPhone 13 Pro',
  'iPhone14,3': 'iPhone 13 Pro Max',
  'iPhone14,4': 'iPhone 13 mini',
  'iPhone14,5': 'iPhone 13',
  'iPhone14,6': 'iPhone SE (3rd generation)',
  'iPhone14,7': 'iPhone 14',
  'iPhone14,8': 'iPhone 14 Plus',
  'iPhone15,2': 'iPhone 14 Pro',
  'iPhone15,3': 'iPhone 14 Pro Max',
  'iPhone15,4': 'iPhone 15',
  'iPhone15,5': 'iPhone 15 Plus',
  'iPhone16,1': 'iPhone 15 Pro',
  'iPhone16,2': 'iPhone 15 Pro Max',
  'iPhone17,1': 'iPhone 16 Pro',
  'iPhone17,2': 'iPhone 16 Pro Max',
  'iPhone17,3': 'iPhone 16',
  'iPhone17,4': 'iPhone 16 Plus',
  'iPhone17,5': 'iPhone 16e',
  'iPhone18,1': 'iPhone 17 Pro',
  'iPhone18,2': 'iPhone 17 Pro Max',
  'iPhone18,3': 'iPhone 17',
  'iPhone18,4': 'iPhone Air',
};

/// The marketing name of an iPhone from its model code; for a code that is not
/// known (a new phone, an iPad, the simulator) [fallback].
String iosModelName(String machine, {String fallback = 'iPhone'}) {
  final known = _iphones[machine];
  if (known != null) return known;
  if (machine.startsWith('iPad')) return 'iPad';
  return fallback;
}

/// "samsung" + "SM-S918B" → "Samsung SM-S918B" (the maker once, capitalised).
String androidModelName(String manufacturer, String model) {
  final maker = manufacturer.trim();
  final name = model.trim();
  if (maker.isEmpty) return name;
  final pretty = maker[0].toUpperCase() + maker.substring(1);
  if (name.toLowerCase().startsWith(maker.toLowerCase())) return name;
  return '$pretty $name'.trim();
}

/// Finds out what this phone is. Anything that cannot be found out is empty.
Future<ChatDeviceDetails> detectDeviceDetails() async {
  var model = '';
  var os = '';
  var app = '';
  try {
    app = (await PackageInfo.fromPlatform()).version;
  } catch (_) {}
  try {
    final info = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final d = await info.iosInfo;
      model = iosModelName(d.utsname.machine, fallback: d.model);
      os = 'iOS ${d.systemVersion}';
    } else if (Platform.isAndroid) {
      final d = await info.androidInfo;
      model = androidModelName(d.manufacturer, d.model);
      os = 'Android ${d.version.release}';
    }
  } catch (_) {}
  return ChatDeviceDetails(model: model, os: os, appVersion: app);
}
