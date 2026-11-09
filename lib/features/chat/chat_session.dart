import 'package:flutter/foundation.dart';

/// Which phone this is, and what happens when its session is terminated from
/// another one (the "Devices" screen): the chat turns the phone away and the
/// app signs out.
class ChatSession {
  ChatSession._();

  /// The push token of this phone: sent with every chat request so that the
  /// server knows which phone is asking.
  static String? deviceToken;

  /// The server's id of this phone's session (from registering it).
  static int? deviceId;

  /// Signs out (set by the main screen).
  static VoidCallback? onTerminated;

  static bool _fired = false;

  /// The server said this phone's session is over (a 401 `session_terminated`,
  /// or the event over the socket): signs out, once.
  static void terminated() {
    if (_fired) return;
    _fired = true;
    onTerminated?.call();
  }

  /// A new sign-in: the session counts again.
  static void reset() {
    _fired = false;
  }

  /// Signed out on purpose: nothing of this phone's session is kept.
  static void clear() {
    deviceToken = null;
    deviceId = null;
  }
}
