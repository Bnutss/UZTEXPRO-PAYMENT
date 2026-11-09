import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'chat_notify_settings.dart';

/// Sound files of the chat (assets/sound).
const String kSendSound = 'sound/dice.mp3';
const String kIncomingSound = 'sound/sound_17216.mp3';

/// Plays one sound file; a seam for tests.
abstract class ChatSoundPlayer {
  Future<void> play(String asset);
}

/// Short effects through `audioplayers`. They mix with whatever else is
/// playing (music is not interrupted) and follow the silent switch, as the
/// in-app sounds of a messenger do.
class AudioChatSoundPlayer implements ChatSoundPlayer {
  final Map<String, AudioPlayer> _players = {};

  static final AudioContext _context = AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.ambient,
      options: const {},
    ),
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.assistanceSonification,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  @override
  Future<void> play(String asset) async {
    var player = _players[asset];
    if (player == null) {
      player = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      await player.setAudioContext(_context);
      await player.setReleaseMode(ReleaseMode.stop);
      _players[asset] = player;
    }
    await player.stop();
    await player.play(AssetSource(asset));
  }
}

/// "Message sent" and "message came" sounds. Sounds never get in the chat's
/// way: a failure to play is swallowed, a burst of messages makes one sound.
class ChatSounds {
  ChatSounds(
    this._player, {
    this.settings,
    this.sentGap = const Duration(milliseconds: 150),
    this.incomingGap = const Duration(milliseconds: 700),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final ChatSoundPlayer _player;

  /// What the person chose in "Notifications and sounds" (null: the defaults).
  final ChatNotifySettings? settings;
  final Duration sentGap;
  final Duration incomingGap;
  final DateTime Function() _now;

  /// Off switch.
  bool enabled = true;

  final Map<String, DateTime> _last = {};

  /// The user sent a message.
  void sent() =>
      _playChoice(settings?.sentSound ?? ChatNotifySettings.defaultSent, sentGap);

  /// A message from the other person arrived.
  void incoming() {
    if (settings?.inAppVibrate ?? false) HapticFeedback.mediumImpact();
    _playChoice(
      settings?.incomingSound ?? ChatNotifySettings.defaultIncoming,
      incomingGap,
    );
  }

  /// Plays [choice] once, to hear it in the settings (no gaps, no switches).
  void preview(ChatSoundChoice choice) => _fire(choice);

  void _playChoice(ChatSoundChoice choice, Duration gap) {
    if (!enabled) return;
    if (settings != null && !settings!.inAppSounds) return;
    final key = choice.asset ?? choice.name;
    final now = _now();
    final last = _last[key];
    if (last != null && now.difference(last) < gap) return;
    _last[key] = now;
    _fire(choice);
  }

  void _fire(ChatSoundChoice choice) {
    switch (choice) {
      case ChatSoundChoice.none:
        return;
      case ChatSoundChoice.system:
        SystemSound.play(SystemSoundType.alert);
      default:
        unawaited(_player.play(choice.asset!).catchError((_) {}));
    }
  }
}
