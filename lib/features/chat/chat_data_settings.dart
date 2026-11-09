import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_media.dart';

/// How long the files of the chat stay on this phone.
enum ChatKeepMedia {
  forever(null),
  days3(Duration(days: 3)),
  week(Duration(days: 7)),
  month(Duration(days: 30));

  const ChatKeepMedia(this.age);

  /// Files older than this are removed; null: never.
  final Duration? age;

  static ChatKeepMedia parse(String? name) {
    for (final c in values) {
      if (c.name == name) return c;
    }
    return forever;
  }
}

/// "Data and storage" of the messenger: which files of other people are
/// fetched by themselves (per kind and per network) and how long the saved
/// files are kept. Kept on the phone.
class ChatDataSettings extends ChangeNotifier {
  ChatDataSettings._({Future<bool?> Function()? wifiProbe})
    : _probe = wifiProbe;

  static final ChatDataSettings instance = ChatDataSettings._();

  /// For tests: a fresh object that does not touch the shared one, with its own
  /// answer to "is the phone on Wi-Fi".
  @visibleForTesting
  factory ChatDataSettings.forTest({Future<bool?> Function()? wifiProbe}) =
      ChatDataSettings._;

  /// The kinds of file that can be fetched by themselves.
  static const kinds = ['image', 'video', 'file'];

  // What a fresh install does (as the app did before the setting existed):
  // photos come by themselves, videos and documents on a tap.
  static const _defaults = {'image': true, 'video': false, 'file': false};

  final Map<String, bool> mobile = Map.of(_defaults);
  final Map<String, bool> wifi = Map.of(_defaults);
  ChatKeepMedia keep = ChatKeepMedia.forever;

  final Future<bool?> Function()? _probe;
  bool _loaded = false;

  /// On Wi-Fi (or a cable) now; null while unknown (then the mobile rules
  /// apply: the cautious side).
  bool? _onWifi;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  static String _key(String net, String kind) => 'chat_auto_${net}_$kind';

  static bool _isWifi(List<ConnectivityResult> r) =>
      r.contains(ConnectivityResult.wifi) ||
      r.contains(ConnectivityResult.ethernet);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      for (final k in kinds) {
        mobile[k] = p.getBool(_key('mobile', k)) ?? _defaults[k]!;
        wifi[k] = p.getBool(_key('wifi', k)) ?? _defaults[k]!;
      }
      keep = ChatKeepMedia.parse(p.getString('chat_keep_media'));
      notifyListeners();
    } catch (_) {}
    await _watchNetwork();
  }

  Future<void> _watchNetwork() async {
    try {
      if (_probe != null) {
        _onWifi = await _probe();
        return;
      }
      final c = Connectivity();
      _onWifi = _isWifi(await c.checkConnectivity());
      _sub ??= c.onConnectivityChanged.listen((r) => _onWifi = _isWifi(r));
    } catch (_) {
      _onWifi = null;
    }
  }

  /// Whether a file of [kind] (`image`, `video`, `file`) that somebody sent
  /// should be fetched without a tap, on the network the phone is on now.
  bool shouldAutoDownload(String kind) {
    final table = (_onWifi ?? false) ? wifi : mobile;
    return table[kind] ?? false;
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      for (final k in kinds) {
        await p.setBool(_key('mobile', k), mobile[k]!);
        await p.setBool(_key('wifi', k), wifi[k]!);
      }
      await p.setString('chat_keep_media', keep.name);
    } catch (_) {}
  }

  void setAuto({required bool onWifi, required String kind, required bool on}) {
    (onWifi ? wifi : mobile)[kind] = on;
    notifyListeners();
    _save();
  }

  void setKeep(ChatKeepMedia value) {
    keep = value;
    notifyListeners();
    _save();
  }

  /// Removes the saved files that are older than the chosen time.
  Future<void> pruneMedia() async {
    await load();
    final age = keep.age;
    if (age == null) return;
    await ChatMediaStore.init();
    await ChatMediaStore.deleteOlderThan(age);
  }

  void disposeWatch() => _sub?.cancel();
}
