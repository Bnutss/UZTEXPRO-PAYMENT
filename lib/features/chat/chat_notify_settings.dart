import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A sound the person can pick for a message sent or received in the app.
enum ChatSoundChoice {
  /// The app's own incoming sound.
  standard('sound/sound_17216.mp3'),
  telegram('sound/telegram_soundin.mp3'),
  dice('sound/dice.mp3'),

  /// The system's alert sound (no file).
  system(null),
  none(null);

  const ChatSoundChoice(this.asset);

  /// The file in assets, null when there is none (system / silent).
  final String? asset;

  static ChatSoundChoice parse(String? name, ChatSoundChoice fallback) {
    for (final c in values) {
      if (c.name == name) return c;
    }
    return fallback;
  }
}

/// "Notifications and sounds" of the messenger: what the app does by itself
/// while it is open (sounds, vibration, banners). Kept on the phone.
class ChatNotifySettings extends ChangeNotifier {
  ChatNotifySettings._();

  static final ChatNotifySettings instance = ChatNotifySettings._();

  /// For tests: a fresh object that does not touch the shared one.
  @visibleForTesting
  factory ChatNotifySettings.forTest() = ChatNotifySettings._;

  static const _kSounds = 'chat_notify_sounds';
  static const _kVibrate = 'chat_notify_vibrate';
  static const _kPreview = 'chat_notify_preview';
  static const _kIncoming = 'chat_notify_incoming';
  static const _kSent = 'chat_notify_sent';

  static const defaultIncoming = ChatSoundChoice.standard;
  static const defaultSent = ChatSoundChoice.dice;

  bool inAppSounds = true;
  bool inAppVibrate = true;

  /// The banner with who wrote and what, over any screen of the app.
  bool inAppPreview = true;
  ChatSoundChoice incomingSound = defaultIncoming;
  ChatSoundChoice sentSound = defaultSent;

  bool _loaded = false;

  /// Reads what was saved; safe to call again.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      inAppSounds = p.getBool(_kSounds) ?? true;
      inAppVibrate = p.getBool(_kVibrate) ?? true;
      inAppPreview = p.getBool(_kPreview) ?? true;
      incomingSound = ChatSoundChoice.parse(
        p.getString(_kIncoming),
        defaultIncoming,
      );
      sentSound = ChatSoundChoice.parse(p.getString(_kSent), defaultSent);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kSounds, inAppSounds);
      await p.setBool(_kVibrate, inAppVibrate);
      await p.setBool(_kPreview, inAppPreview);
      await p.setString(_kIncoming, incomingSound.name);
      await p.setString(_kSent, sentSound.name);
    } catch (_) {}
  }

  void update({
    bool? sounds,
    bool? vibrate,
    bool? preview,
    ChatSoundChoice? incoming,
    ChatSoundChoice? sent,
  }) {
    inAppSounds = sounds ?? inAppSounds;
    inAppVibrate = vibrate ?? inAppVibrate;
    inAppPreview = preview ?? inAppPreview;
    incomingSound = incoming ?? incomingSound;
    sentSound = sent ?? sentSound;
    notifyListeners();
    _save();
  }

  /// Back to what a fresh install has.
  void reset() => update(
    sounds: true,
    vibrate: true,
    preview: true,
    incoming: defaultIncoming,
    sent: defaultSent,
  );
}
