import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Sound files of the chat (assets/sound).
const String kSendSound = 'sound/telegram_soundin.mp3';
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
    this.sentGap = const Duration(milliseconds: 150),
    this.incomingGap = const Duration(milliseconds: 700),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final ChatSoundPlayer _player;
  final Duration sentGap;
  final Duration incomingGap;
  final DateTime Function() _now;

  /// Off switch (a future setting).
  bool enabled = true;

  final Map<String, DateTime> _last = {};

  /// The user sent a message.
  void sent() => _play(kSendSound, sentGap);

  /// A message from the other person arrived.
  void incoming() => _play(kIncomingSound, incomingGap);

  void _play(String asset, Duration gap) {
    if (!enabled) return;
    final now = _now();
    final last = _last[asset];
    if (last != null && now.difference(last) < gap) return;
    _last[asset] = now;
    unawaited(_player.play(asset).catchError((_) {}));
  }
}
