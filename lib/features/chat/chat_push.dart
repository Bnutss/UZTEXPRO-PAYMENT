import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pushy_flutter/pushy_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_api.dart';
import 'chat_models.dart';

/// Push notifications about chat messages (Pushy): registering this phone with
/// the backend, showing a notification on Android, and leading a tap to the
/// right conversation.
///
/// On iOS the system shows the notification itself (from the `notification`
/// part the server sends) and only when the app is not in the foreground; on
/// Android the app shows it from `data`, and must not do so while it is open.

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

/// Runs for every push while the app is not the foreground one (Android: in a
/// background isolate). Must be a top-level function.
@pragma('vm:entry-point')
Future<void> chatBackgroundNotificationListener(
  Map<String, dynamic> data,
) async {
  // iOS: the system has already shown it from the `notification` part.
  if (!Platform.isAndroid) return;
  final isChat = data['type'] == 'chat';
  // Anything else with a text (a test push from the server or the Pushy
  // dashboard) is shown too, so delivery can be checked without a chat.
  if (!isChat && (data['message'] ?? '').toString().isEmpty) return;
  // The app is open: it shows the message itself (and the unread badge).
  if (isChat && await PushForeground.appIsOpen()) return;
  final title = (data['title'] ?? 'UztexPro').toString();
  final text = (data['message'] ?? '').toString();
  Pushy.notify(title, text, data);
}

// ── The push SDK behind a small interface (a seam for tests) ─────────────

abstract class PushClient {
  /// Starts receiving, asks for the permission where the system needs it, and
  /// returns this phone's token (null when there is none).
  Future<String?> register();

  /// A tap on a notification (also one that launched the app).
  void onTap(void Function(Map<String, dynamic> data) listener);

  /// Removes the number from the app icon.
  void clearBadge();
}

class PushyClient implements PushClient {
  @override
  Future<String?> register() async {
    // Android: deliver through Google FCM too, so the phone wakes for a push
    // even while the system has put the app to sleep (as Telegram does).
    Pushy.toggleFCM(true);
    Pushy.listen();
    Pushy.setNotificationListener(chatBackgroundNotificationListener);
    return Pushy.register();
  }

  @override
  void onTap(void Function(Map<String, dynamic> data) listener) =>
      Pushy.setNotificationClickListener(listener);

  static const _channel = MethodChannel('uztexpro/notifications');

  @override
  void clearBadge() {
    Pushy.clearBadge(); // iOS: the number on the icon
    if (Platform.isAndroid) {
      // Android: the number is the notifications still in the shade.
      _channel.invokeMethod<bool>('cancelAll').catchError((_) => false);
    }
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
      await api.registerDevice(token, platform);
      _token = token;
    } catch (_) {}
  }

  /// Call on sign-out, before the login is dropped: the next person on this
  /// phone must not get the previous one's messages.
  Future<void> stop() async {
    final token = _token;
    _token = null;
    if (token == null) return;
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
