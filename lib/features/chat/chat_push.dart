import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_api.dart';
import 'chat_device_model.dart';
import 'chat_models.dart';
import 'chat_session.dart';

/// Push notifications about chat messages (Firebase Cloud Messaging): registering this phone with
/// the backend, showing a notification on Android, and leading a tap to the
/// right conversation.
///
/// On iOS the system shows the notification itself (from the `aps` part the
/// server sends) and only when the app is not in the foreground; on Android
/// the app draws it natively from `data` (ChatFirebaseService.kt), and must not
/// do so while it is open.

// ── What a tapped notification leads to ──────────────────────────────────

/// A conversation to open: from the `data` of a chat push.
class ChatPushTarget {
  const ChatPushTarget(this.conversationId, this.peer, {this.isGroup = false});

  final int conversationId;
  final ChatUser peer;

  /// A group: [peer] stands in for it (its title).
  final bool isGroup;
}

int? _asInt(Object? v) => v is num ? v.toInt() : int.tryParse('$v');

/// The conversation a push is about; null for anything that is not a chat push.
ChatPushTarget? parseChatPush(Map<String, dynamic> data) {
  if (data['type'] != 'chat') return null;
  final conversation = _asInt(data['conversation']);
  final sender = _asInt(data['sender']);
  if (conversation == null || sender == null) return null;
  if (data['group'] == true || data['group'] == 'true') {
    return ChatPushTarget(
      conversation,
      ChatUser.groupStandIn(
        conversation,
        (data['title'] ?? '').toString(),
        null,
      ),
      isGroup: true,
    );
  }
  final name = (data['sender_name'] ?? data['title'] ?? '').toString();
  return ChatPushTarget(conversation, ChatUser(id: sender, name: name));
}

// ── "Is the app open right now?" ─────────────────────────────────────────

/// The Android background handler runs apart from the screens, so the app
/// leaves a heartbeat in the preferences while it is in the foreground. A stale
/// heartbeat (the app was killed) counts as "not in the foreground", so a
/// message is never lost because of a leftover flag.
class PushForeground {
  PushForeground._();

  static const _key = 'chat_fg_beat';
  static const interval = Duration(seconds: 15);

  /// Older than this is stale (a few missed beats).
  static const window = Duration(seconds: 45);

  /// Pure check, for tests.
  static bool isForeground(int? lastBeatMs, DateTime now) {
    if (lastBeatMs == null) return false;
    final age = now.millisecondsSinceEpoch - lastBeatMs;
    return age >= -5000 && age < window.inMilliseconds;
  }

  static Future<void> beat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  /// Called from the background isolate: the safe answer, when in doubt, is
  /// "not in the foreground" (show the notification).
  static Future<bool> appIsOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // another isolate wrote it
      return isForeground(prefs.getInt(_key), DateTime.now());
    } catch (_) {
      return false;
    }
  }
}

// ── The push SDK behind a small interface (a seam for tests) ─────────────

abstract class PushClient {
  /// Starts receiving, asks for the permission where the system needs it, and
  /// returns this phone's token (null when there is none).
  Future<String?> register();

  /// The system gave this phone a new token: it must be registered again.
  void onTokenRefresh(void Function(String token) listener);

  /// A tap on a notification (also one that launched the app).
  void onTap(void Function(Map<String, dynamic> data) listener);

  /// Removes the number from the app icon.
  void clearBadge();
}

class FcmClient implements PushClient {
  static const _channel = MethodChannel('uztexpro/notifications');

  static Future<bool>? _ready;

  /// Starts Firebase once; false when it cannot start (no config file, no
  /// Play services): push is then off, nothing else breaks. Android reads its
  /// settings from google-services.json, iOS from GoogleService-Info.plist;
  /// both are added by the build.
  static Future<bool> _init() => _ready ??= () async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      return true;
    } catch (_) {
      return false;
    }
  }();

  @override
  Future<String?> register() async {
    if (!await _init()) return null;
    final messaging = FirebaseMessaging.instance;
    // iOS asks the person here; on Android 13+ MainActivity asks at start.
    await messaging.requestPermission();
    if (Platform.isIOS) {
      // The FCM token exists only once Apple has handed over the APNs one,
      // which can take a moment after the first launch.
      for (var i = 0; i < 10 && await messaging.getAPNSToken() == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return messaging.getToken();
  }

  @override
  void onTokenRefresh(void Function(String token) listener) {
    _init().then((ok) {
      if (ok) FirebaseMessaging.instance.onTokenRefresh.listen(listener);
    });
  }

  @override
  void onTap(void Function(Map<String, dynamic> data) listener) {
    // iOS: the system showed it; a tap comes through Firebase.
    _init()
        .then((ok) async {
          if (!ok) return;
          FirebaseMessaging.onMessageOpenedApp.listen((m) => listener(m.data));
          final first = await FirebaseMessaging.instance.getInitialMessage();
          if (first != null) listener(first.data);
        })
        .catchError((_) {});
    // Android: the app drew it (ChatFirebaseService), and MainActivity hands
    // the tap over: the one that launched the app, and later ones.
    if (Platform.isAndroid) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'pushTapped') _deliver(call.arguments, listener);
      });
      _channel
          .invokeMethod<String>('initialPush')
          .then((payload) => _deliver(payload, listener))
          .catchError((_) {});
    }
  }

  static void _deliver(
    Object? payload,
    void Function(Map<String, dynamic>) listener,
  ) {
    if (payload is! String || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload);
      if (data is Map) listener(Map<String, dynamic>.from(data));
    } catch (_) {}
  }

  @override
  void clearBadge() {
    // iOS: the number on the icon; Android: the notifications in the shade.
    _channel.invokeMethod<bool>('clearBadge').catchError((_) => false);
  }
}

// ── The service the main screen owns ─────────────────────────────────────

class ChatPushService with WidgetsBindingObserver {
  ChatPushService({
    required this.api,
    required this.client,
    String? platform,
    this.unread,
  }) : platform = platform ?? (Platform.isIOS ? 'ios' : 'android');

  final ChatRest api;
  final PushClient client;
  final String platform;

  /// The current unread count; when it is 0 on returning to the app, the
  /// notifications left in the shade (and the number on the icon) are removed.
  final int Function()? unread;

  /// Set when a notification was tapped: the screen opens that conversation.
  final ValueNotifier<ChatPushTarget?> openRequest = ValueNotifier(null);

  String? _token;
  Timer? _beat;
  bool _disposed = false;

  /// This phone's token once it is registered.
  String? get token => _token;

  /// The token of this phone as the last registration left it (for the
  /// settings, which show which of my devices is this one).
  static String? lastToken;

  /// Call after sign-in. Failing to register (no permission, no network) is
  /// not an error: the next start tries again.
  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    _startBeat();
    // Opening the app with nothing unread: drop stale notifications. Wait a
    // moment so the unread count has been loaded.
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!_disposed && unread?.call() == 0) clearBadge();
    });
    client.onTap((data) {
      final target = parseChatPush(data);
      if (target != null && !_disposed) openRequest.value = target;
    });
    try {
      final token = await client.register();
      if (token == null || token.isEmpty || _disposed) return;
      await _registerToken(token);
      client.onTokenRefresh((fresh) {
        if (!_disposed && _token != null && fresh != _token) {
          _registerToken(fresh).catchError((_) {});
        }
      });
    } catch (_) {}
  }

  Future<void> _registerToken(String token) async {
    // The chat asks the server about this phone in every request from now on.
    ChatSession.deviceToken = token;
    final d = await detectDeviceDetails();
    final id = await api.registerDevice(
      token,
      platform,
      name: d.model,
      model: d.model,
      osVersion: d.os,
      appVersion: d.appVersion,
    );
    ChatSession.deviceId = id;
    _token = token;
    lastToken = token;
  }

  /// Call on sign-out, before the login is dropped: the next person on this
  /// phone must not get the previous one's messages.
  Future<void> stop() async {
    final token = _token;
    _token = null;
    if (token == null) return;
    // (the request below still says which phone it is; afterwards none)
    Future<void>.delayed(const Duration(seconds: 6), ChatSession.clear);
    try {
      await api.removeDevice(token).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  void clearBadge() => client.clearBadge();

  void _startBeat() {
    _beat?.cancel();
    PushForeground.beat();
    _beat = Timer.periodic(
      PushForeground.interval,
      (_) => PushForeground.beat(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startBeat();
      if (unread?.call() == 0) clearBadge();
    } else {
      _beat?.cancel();
      _beat = null;
      PushForeground.clear();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _beat?.cancel();
    PushForeground.clear();
    openRequest.dispose();
  }
}
