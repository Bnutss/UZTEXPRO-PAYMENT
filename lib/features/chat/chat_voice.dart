import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'chat_models.dart';

// Voice messages: recording (hold the microphone, as in Telegram) and playing.

/// A finished recording, ready to be sent.
class VoiceClip {
  const VoiceClip(this.path, this.durationMs, this.waveform);

  final String path;
  final int durationMs;

  /// Loudness bars, 0..31 each.
  final List<int> waveform;
}

/// Shortest recording that is sent; anything shorter is a stray tap.
const int kVoiceMinMs = 1000;

/// Longest recording (it stops and is sent by itself).
const Duration kVoiceMax = Duration(minutes: 15);

const int kWaveBars = 64;

/// Turns the loudness samples (0..1) into [bars] bars of 0..31 (the loudest of
/// each slice, so short words are not lost).
List<int> downsampleWave(List<double> samples, {int bars = kWaveBars}) {
  if (samples.isEmpty) return List.filled(bars, 2);
  final out = <int>[];
  for (var i = 0; i < bars; i++) {
    final from = (i * samples.length / bars).floor();
    final to = math.max(from + 1, ((i + 1) * samples.length / bars).ceil());
    var peak = 0.0;
    for (var j = from; j < math.min(to, samples.length); j++) {
      peak = math.max(peak, samples[j]);
    }
    out.add((peak * 31).round().clamp(1, 31));
  }
  return out;
}

/// "0:07" / "12:03".
String formatVoiceTime(int ms) {
  final total = (ms / 1000).round();
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

enum RecorderPhase { idle, starting, holding, locked }

/// Records one voice message at a time. The finger is held on the microphone
/// ([holding]); sliding up locks the recording ([locked]) so the finger can
/// leave; sliding left cancels.
class ChatVoiceRecorder extends ChangeNotifier {
  ChatVoiceRecorder({AudioRecorder? recorder}) : _rec = recorder;

  AudioRecorder? _rec;
  AudioRecorder get _recorder => _rec ??= AudioRecorder();

  RecorderPhase phase = RecorderPhase.idle;
  bool get active =>
      phase == RecorderPhase.holding || phase == RecorderPhase.locked;
  bool get locked => phase == RecorderPhase.locked;

  /// How far the finger went left (0..1, 1 = cancels) and up (0..1, 1 = locks).
  double cancelProgress = 0;
  double lockProgress = 0;

  int elapsedMs = 0;
  final List<double> _samples = [];

  /// The last loud/quiet values, for the live wave while locked.
  List<double> get live => List.unmodifiable(
    _samples.length > 40 ? _samples.sublist(_samples.length - 40) : _samples,
  );

  String? _path;
  Timer? _tick;
  StreamSubscription<Amplitude>? _amp;
  final Stopwatch _clock = Stopwatch();
  bool _releasedEarly = false;

  /// Called when the maximum length is reached: the recording was stopped and
  /// is handed over here (to be sent).
  void Function(VoiceClip clip)? onAutoStop;

  /// Starts recording. False when there is no microphone permission.
  Future<bool> start() async {
    if (phase != RecorderPhase.idle) return false;
    phase = RecorderPhase.starting;
    _releasedEarly = false;
    notifyListeners();
    try {
      if (!await _recorder.hasPermission()) {
        phase = RecorderPhase.idle;
        notifyListeners();
        return false;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 48000,
          sampleRate: 32000,
          numChannels: 1,
        ),
        path: path,
      );
      _path = path;
    } catch (_) {
      phase = RecorderPhase.idle;
      notifyListeners();
      return false;
    }
    _samples.clear();
    elapsedMs = 0;
    cancelProgress = 0;
    lockProgress = 0;
    _clock
      ..reset()
      ..start();
    _amp = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 70))
        .listen((a) {
          // dB: -160 (silence) .. 0 (loudest); speech sits around -40..-10.
          _samples.add(((a.current + 45) / 45).clamp(0.0, 1.0));
        });
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      elapsedMs = _clock.elapsedMilliseconds;
      if (_clock.elapsed >= kVoiceMax) {
        unawaited(finish().then((c) => c == null ? null : onAutoStop?.call(c)));
      }
      notifyListeners();
    });
    if (_releasedEarly) {
      // The finger was already lifted while the microphone was opening.
      await cancel();
      return true;
    }
    phase = RecorderPhase.holding;
    notifyListeners();
    return true;
  }

  /// The finger moved: [dx] left is negative, [dy] up is positive.
  void drag(double dx, double dy) {
    if (phase != RecorderPhase.holding) return;
    cancelProgress = (-dx / 110).clamp(0.0, 1.0);
    lockProgress = (dy / 70).clamp(0.0, 1.0);
    if (lockProgress >= 1) {
      phase = RecorderPhase.locked;
      cancelProgress = 0;
    }
    notifyListeners();
  }

  /// The finger was lifted while still holding.
  bool get cancelling => cancelProgress >= 1;

  /// Pointer released before the microphone was ready.
  void releasedBeforeReady() => _releasedEarly = true;

  /// Stops and returns the clip; null when it is too short (discarded).
  Future<VoiceClip?> finish() async {
    if (!active) return null;
    final ms = _clock.elapsedMilliseconds;
    await _stopEngine(keepFile: ms >= kVoiceMinMs);
    final path = _path;
    _path = null;
    final wave = downsampleWave(_samples);
    _reset();
    if (path == null || ms < kVoiceMinMs) {
      if (path != null) _delete(path);
      return null;
    }
    return VoiceClip(path, ms, wave);
  }

  /// Throws the recording away.
  Future<void> cancel() async {
    if (phase == RecorderPhase.idle) return;
    await _stopEngine(keepFile: false);
    final path = _path;
    _path = null;
    if (path != null) _delete(path);
    _reset();
  }

  Future<void> _stopEngine({required bool keepFile}) async {
    _tick?.cancel();
    _tick = null;
    await _amp?.cancel();
    _amp = null;
    _clock.stop();
    try {
      await _recorder.stop();
    } catch (_) {}
  }

  void _reset() {
    phase = RecorderPhase.idle;
    cancelProgress = 0;
    lockProgress = 0;
    elapsedMs = 0;
    _samples.clear();
    notifyListeners();
  }

  void _delete(String path) {
    try {
      File(path).deleteSync();
    } catch (_) {}
  }

  @override
  void dispose() {
    _tick?.cancel();
    _amp?.cancel();
    final path = _path;
    final rec = _rec;
    () async {
      try {
        await rec?.stop();
        await rec?.dispose();
      } catch (_) {}
      if (path != null) _delete(path);
    }();
    super.dispose();
  }
}

/// Plays voice messages: one at a time (a new one stops the old one), with a
/// position and a speed (1x / 1.5x / 2x) as in Telegram.
class ChatVoicePlayer extends ChangeNotifier {
  ChatVoicePlayer._();
  static final ChatVoicePlayer instance = ChatVoicePlayer._();

  AudioPlayer? _player;
  String? currentKey;

  /// Which voice message follows [message] in the open chat (null: none). The
  /// chat screen sets it; the next one starts when one has been heard to the
  /// end.
  ChatMessage? Function(ChatMessage message)? nextResolver;

  /// The message being played (or paused): the player bar on top shows it.
  ChatMessage? current;
  bool playing = false;
  Duration position = Duration.zero;
  Duration total = Duration.zero;
  double speed = 1.0;

  /// The same message has one key before and after it reached the server.
  static String keyOf(ChatMessage m) =>
      m.clientId.isNotEmpty ? m.clientId : 'id${m.id}';

  bool isCurrent(ChatMessage m) => currentKey == keyOf(m);

  AudioPlayer _ensure() {
    final existing = _player;
    if (existing != null) return existing;
    final p = AudioPlayer();
    p.onPositionChanged.listen((d) {
      position = d;
      notifyListeners();
    });
    p.onDurationChanged.listen((d) {
      total = d;
      notifyListeners();
    });
    p.onPlayerComplete.listen((_) {
      // Listened to the end: the player bar goes away, as in Telegram, unless
      // the next voice message of the chat follows by itself.
      final finished = current;
      _completed = true;
      playing = false;
      currentKey = null;
      current = null;
      position = Duration.zero;
      final next = finished == null ? null : nextResolver?.call(finished);
      if (next != null) toggle(next);
      notifyListeners();
    });
    p.onPlayerStateChanged.listen((st) {
      final now = st == PlayerState.playing;
      if (now != playing) {
        playing = now;
        notifyListeners();
      }
    });
    return _player = p;
  }

  /// Set when the last attempt to play failed (what the screen tells the person).
  String? error;
  bool _completed = false;
  bool _contextSet = false;

  Future<void> _setContext(AudioPlayer player) async {
    if (_contextSet) return;
    try {
      // After a recording iOS leaves the session on the earpiece: play loudly.
      await player.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
          android: const AudioContextAndroid(
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
      _contextSet = true;
    } catch (e) {
      debugPrint('voice: audio context failed: $e');
    }
  }

  /// The ways to play a message: the file on this phone first, then the
  /// address on the server.
  List<Source> _sourcesOf(ChatMessage m) {
    final out = <Source>[];
    final local = m.localAudioPath;
    if (local != null && File(local).existsSync()) {
      out.add(DeviceFileSource(local));
    }
    final url = m.audioUrl;
    if (url != null && url.isNotEmpty) out.add(UrlSource(url));
    return out;
  }

  Future<bool> _playFrom(AudioPlayer player, ChatMessage m) async {
    for (final source in _sourcesOf(m)) {
      try {
        await player.stop();
        await player.play(source);
        if (speed != 1.0) await player.setPlaybackRate(speed);
        return true;
      } catch (e) {
        debugPrint('voice: cannot play $source: $e');
        error = '$e';
      }
    }
    return false;
  }

  /// Tap on play: starts this message, or pauses / resumes it. False when it
  /// could not be played ([error] says why).
  Future<bool> toggle(ChatMessage m) async {
    final player = _ensure();
    error = null;
    await _setContext(player);
    if (isCurrent(m)) {
      if (playing) {
        await player.pause();
        return true;
      }
      if (!_completed) {
        try {
          await player.resume();
          return true;
        } catch (e) {
          debugPrint('voice: resume failed: $e');
        }
      }
      // Finished (or could not resume): from the start.
    }
    currentKey = keyOf(m);
    current = m;
    position = Duration.zero;
    total = Duration(milliseconds: m.durationMs);
    _completed = false;
    playing = true;
    notifyListeners();
    final ok = await _playFrom(player, m);
    if (!ok) {
      playing = false;
      error ??= 'no source';
      notifyListeners();
    }
    return ok;
  }

  /// Jumps to [fraction] (0..1) of the message being played.
  Future<void> seek(ChatMessage m, double fraction) async {
    if (!isCurrent(m)) {
      await toggle(m);
    }
    final ms = (m.durationMs * fraction.clamp(0.0, 1.0)).round();
    await _ensure().seek(Duration(milliseconds: ms));
    position = Duration(milliseconds: ms);
    notifyListeners();
  }

  /// 1x → 1.5x → 2x → 1x.
  Future<void> cycleSpeed() async {
    speed = speed == 1.0 ? 1.5 : (speed == 1.5 ? 2.0 : 1.0);
    await _player?.setPlaybackRate(speed);
    notifyListeners();
  }

  Future<void> stop() async {
    await _player?.stop();
    playing = false;
    currentKey = null;
    current = null;
    position = Duration.zero;
    notifyListeners();
  }
}
