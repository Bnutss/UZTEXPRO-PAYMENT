import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show TargetPlatform, ValueNotifier, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'chat_models.dart';
import 'chat_glass.dart' show chatFrosted;
import 'chat_voice.dart';
import 'chat_widgets.dart';

// The widgets of voice messages: the wave, the player in a bubble, and the
// recording controls of the input (as in Telegram).

/// Vertical bars of a recording's loudness; the played part is coloured.
class VoiceWave extends StatelessWidget {
  const VoiceWave({
    super.key,
    required this.bars,
    required this.progress,
    required this.active,
    required this.inactive,
    this.height = 28,
  });

  final List<int> bars;
  final double progress;
  final Color active;
  final Color inactive;
  final double height;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(double.infinity, height),
    painter: _WavePainter(bars, progress, active, inactive),
  );
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.bars, this.progress, this.active, this.inactive);

  final List<int> bars;
  final double progress;
  final Color active;
  final Color inactive;

  static const _barW = 2.6;
  static const _gap = 1.8;

  @override
  void paint(Canvas canvas, Size size) {
    final count = math.max(1, (size.width / (_barW + _gap)).floor());
    final src = bars.isEmpty ? List.filled(count, 4) : bars;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _barW;
    for (var i = 0; i < count; i++) {
      // The loudest of the source bars that fall on this one.
      final from = (i * src.length / count).floor();
      final to = math.max(from + 1, ((i + 1) * src.length / count).ceil());
      var v = 0;
      for (var j = from; j < math.min(to, src.length); j++) {
        v = math.max(v, src[j]);
      }
      final h = math.max(3.0, size.height * (v / 31).clamp(0.0, 1.0));
      final x = i * (_barW + _gap) + _barW / 2;
      paint.color = (i + 0.5) / count <= progress ? active : inactive;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter o) =>
      o.progress != progress ||
      o.bars != bars ||
      o.active != active ||
      o.inactive != inactive;
}

/// The size of the player in a bubble (the bubble keeps this room for it).
const double kVoiceBodyWidth = 236;
const double kVoiceBodyHeight = 46;

/// The player inside a message bubble: play / pause, the wave (tap or drag to
/// seek), the length (the position while playing) and the speed.
class VoiceBubbleBody extends StatelessWidget {
  const VoiceBubbleBody({
    super.key,
    required this.message,
    required this.accent,
    required this.meta,
  });

  final ChatMessage message;
  final Color accent;

  /// Time and ticks, at the bottom right.
  final Widget meta;

  @override
  Widget build(BuildContext context) {
    final player = ChatVoicePlayer.instance;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final m = message;
        final current = player.isCurrent(m);
        final totalMs = m.durationMs > 0
            ? m.durationMs
            : (current ? player.total.inMilliseconds : 0);
        final progress = current && totalMs > 0
            ? (player.position.inMilliseconds / totalMs).clamp(0.0, 1.0)
            : 0.0;
        final started = current && (player.playing || progress > 0);
        final playing = current && player.playing;
        final shown = started ? player.position.inMilliseconds : totalMs;
        return SizedBox(
          width: kVoiceBodyWidth,
          height: kVoiceBodyHeight,
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () async {
                  HapticFeedback.selectionClick();
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  final text = S.of(context).chatVoiceFailed;
                  final ok = await player.toggle(m);
                  if (!ok && messenger != null) {
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text('$text\n${player.error ?? ''}'),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                  }
                },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, box) {
                        void seek(double dx) =>
                            player.seek(m, dx / math.max(1, box.maxWidth));
                        return GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapUp: (d) => seek(d.localPosition.dx),
                          // Dragging along the wave rewinds, but only a message
                          // that is already the current one. On any other the
                          // wave must not claim the horizontal drag: it beat
                          // the swipe-to-reply (a deeper recogniser wins) and
                          // "rewinding" started the voice message.
                          onHorizontalDragUpdate: current
                              ? (d) => seek(d.localPosition.dx)
                              : null,
                          child: VoiceWave(
                            bars: m.waveform,
                            progress: progress,
                            active: accent,
                            inactive: accent.withValues(alpha: 0.30),
                            height: 24,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          formatVoiceTime(shown),
                          style: TextStyle(
                            fontSize: 12,
                            color: accent,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (started) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: player.cycleSpeed,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                player.speed == 1.0 ? '1x' : '${player.speed}x',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        meta,
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The microphone of the input. Hold to record; slide left to cancel, slide up
/// to lock (then the finger can leave and the button sends).
class VoiceMicButton extends StatefulWidget {
  const VoiceMicButton({
    super.key,
    required this.recorder,
    required this.size,
    required this.onClip,
    required this.onDenied,
    required this.onTooShort,
  });

  final ChatVoiceRecorder recorder;
  final double size;
  final void Function(VoiceClip clip) onClip;
  final VoidCallback onDenied;
  final VoidCallback onTooShort;

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton> {
  ChatVoiceRecorder get _rec => widget.recorder;
  Offset? _origin;
  bool _held = false;

  Future<void> _down(PointerDownEvent e) async {
    _origin = e.position;
    _held = true;
    HapticFeedback.mediumImpact();
    final ok = await _rec.start();
    if (!ok) {
      _held = false;
      if (mounted) widget.onDenied();
      return;
    }
    // Lifted while the microphone was opening: start() already cancelled.
  }

  void _move(PointerMoveEvent e) {
    final o = _origin;
    if (o == null || !_held) return;
    _rec.drag(e.position.dx - o.dx, o.dy - e.position.dy);
    if (_rec.cancelling) {
      _held = false;
      HapticFeedback.heavyImpact();
      _rec.cancel();
    }
  }

  Future<void> _up(PointerEvent e) async {
    if (!_held) return;
    _held = false;
    if (_rec.phase == RecorderPhase.starting) {
      _rec.releasedBeforeReady();
      return;
    }
    if (_rec.phase != RecorderPhase.holding) return; // locked: buttons rule
    // The callbacks are taken BEFORE the wait: whatever happens to this button
    // meanwhile, a finished recording must be delivered (it used to be dropped
    // with `if (!mounted) return`, and the clip was lost).
    final onClip = widget.onClip;
    final onTooShort = widget.onTooShort;
    final clip = await _rec.finish();
    if (clip != null) {
      onClip(clip);
    } else if (mounted) {
      onTooShort();
    }
  }

  Future<void> _sendLocked() async {
    HapticFeedback.lightImpact();
    final clip = await _rec.finish();
    if (clip != null) widget.onClip(clip);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _rec,
      builder: (context, _) {
        final size = widget.size;
        if (_rec.locked) {
          // Locked: the button is "send".
          return GestureDetector(
            onTap: _sendLocked,
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: AppColors.brandOrange,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          );
        }
        final holding = _rec.phase == RecorderPhase.holding;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (holding)
                  Positioned(
                    bottom: size + 14 + 38 * _rec.lockProgress,
                    child: _LockPill(progress: _rec.lockProgress),
                  ),
                AnimatedScale(
                  scale: holding ? 1.5 : 1,
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: holding
                          ? AppColors.brandOrange
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mic_rounded,
                      size: 24,
                      color: holding ? Colors.white : kChatInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LockPill extends StatelessWidget {
  const _LockPill({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 72 - 20 * progress,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          progress > 0.7 ? Icons.lock_rounded : Icons.lock_open_rounded,
          size: 18,
          color: kChatMuted,
        ),
        if (progress < 0.5) ...[
          const SizedBox(height: 2),
          Icon(
            Icons.keyboard_arrow_up_rounded,
            size: 18,
            color: kChatMuted.withValues(alpha: 1 - progress * 2),
          ),
        ],
      ],
    ),
  );
}

/// What the capsule shows while recording: the pulsing dot, the timer and the
/// "slide to cancel" hint; locked: the trash and the live wave.
class VoiceRecordingStrip extends StatelessWidget {
  const VoiceRecordingStrip({
    super.key,
    required this.recorder,
    required this.rightPad,
  });

  final ChatVoiceRecorder recorder;
  final double rightPad;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: recorder,
      builder: (context, _) {
        final locked = recorder.locked;
        return Padding(
          padding: EdgeInsets.only(left: 16, right: rightPad),
          child: Row(
            children: [
              const _RecDot(),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                // Minutes, seconds and hundredths ("0:07,34") as in Telegram;
                // scaled down rather than cut when a long one needs more room.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _RecTimer(recorder: recorder),
                ),
              ),
              Expanded(
                child: locked
                    // Locked, as in Telegram: a text button "Cancel" right in
                    // the bar, next to the time (the round button at the right
                    // sends).
                    ? Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            recorder.cancel();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            child: Text(
                              s.chatCancel,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: AppColors.brandOrange,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Opacity(
                        opacity: (1 - recorder.cancelProgress).clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(-70 * recorder.cancelProgress, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.chevron_left_rounded,
                                size: 20,
                                color: kChatMuted,
                              ),
                              Flexible(
                                child: Text(
                                  s.chatSlideToCancel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: kChatMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The recording time with hundredths. It is redrawn on every frame (a ticker),
/// not with the recorder's 100 ms beat, or the hundredths would jump by tens.
class _RecTimer extends StatefulWidget {
  const _RecTimer({required this.recorder});

  final ChatVoiceRecorder recorder;

  @override
  State<_RecTimer> createState() => _RecTimerState();
}

class _RecTimerState extends State<_RecTimer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => setState(() {}))..start();

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    formatVoiceTimeFine(widget.recorder.liveMs),
    maxLines: 1,
    style: const TextStyle(
      fontSize: 16,
      color: kChatInk,
      // Equal-width digits: the line does not tremble as the hundredths run.
      fontFeatures: [FontFeature.tabularFigures()],
    ),
  );
}

class _RecDot extends StatefulWidget {
  const _RecDot();

  @override
  State<_RecDot> createState() => _RecDotState();
}

class _RecDotState extends State<_RecDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.25, end: 1.0).animate(_c),
    child: Container(
      width: 11,
      height: 11,
      decoration: const BoxDecoration(
        color: Color(0xFFFF3B30),
        shape: BoxShape.circle,
      ),
    ),
  );
}

/// The player bar under the header while a voice message is playing (or
/// paused), as in Telegram: play / pause, who is speaking, the speed and a
/// cross that stops it.
class VoiceTopBar extends StatelessWidget {
  const VoiceTopBar({super.key, required this.authorOf});

  /// The name shown for the message being played.
  final String Function(ChatMessage message) authorOf;

  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    final player = ChatVoicePlayer.instance;
    final s = S.of(context);
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final m = player.current;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, -0.4),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: m == null
              ? const SizedBox.shrink(key: ValueKey('none'))
              : LayoutBuilder(
                  key: const ValueKey('bar'),
                  builder: (context, box) => chatFrosted(
                    width: box.maxWidth,
                    height: height,
                    child: Row(
                      children: [
                        const SizedBox(width: 7),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            player.toggle(m);
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: AppColors.brandOrange,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              player.playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authorOf(m),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: kChatInk,
                                  height: 1.2,
                                ),
                              ),
                              Text(
                                '${s.chatVoiceMessage} · '
                                '${formatVoiceTime(player.position.inMilliseconds)}'
                                ' / ${formatVoiceTime(m.durationMs)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: kChatMuted,
                                  height: 1.2,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            player.cycleSpeed();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandOrange.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              player.speed == 1.0 ? '1x' : '${player.speed}x',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandOrange,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            player.stop();
                          },
                          child: const SizedBox(
                            width: 44,
                            height: height,
                            child: Icon(
                              Icons.close_rounded,
                              size: 22,
                              color: kChatMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// The player bar for a chat screen: on iOS the native glass bar (UIKit, see
/// `VoiceBar` in AppDelegate), elsewhere the Flutter one. Put it in the chat's
/// Stack; [top] is its distance from the top of the screen.
class VoiceTopBarHost extends StatelessWidget {
  const VoiceTopBarHost({super.key, required this.top, required this.authorOf});

  final double top;
  final String Function(ChatMessage message) authorOf;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _NativeVoiceBar(top: top, authorOf: authorOf);
    }
    return Positioned(
      top: top,
      left: 10,
      right: 10,
      child: VoiceTopBar(authorOf: authorOf),
    );
  }
}

class _NativeVoiceBar extends StatefulWidget {
  const _NativeVoiceBar({required this.top, required this.authorOf});

  final double top;
  final String Function(ChatMessage message) authorOf;

  @override
  State<_NativeVoiceBar> createState() => _NativeVoiceBarState();
}

class _NativeVoiceBarState extends State<_NativeVoiceBar> {
  static const _channel = MethodChannel('uztexpro/native_sheet');
  final _player = ChatVoicePlayer.instance;
  String? _last;
  bool _shown = false;

  /// This chat is the screen on top. The native bar lies over the whole
  /// window, so it must go away while another screen (a profile) covers it.
  bool _onTop = true;

  /// The page is being dragged back (the swipe from the left edge). The native
  /// bar is a UIKit view over the whole window: it does not follow the Flutter
  /// transform, so it would hang in place over the chat list showing through,
  /// while the chat slides away. It is hidden for the gesture and comes back if
  /// the swipe is cancelled (when it completes, the chat is gone and so is it).
  ValueNotifier<bool>? _gesture;
  bool get _swiping => _gesture?.value ?? false;

  /// The two transitions that move this chat on the screen: its own (closing
  /// by the "back" button) and the one of a screen above it (a profile that
  /// opens over it, or slides away from it). The native bar does not follow
  /// either: `isCurrent` turns true at the START of the profile's closing, so
  /// the bar jumped up over the profile that was still sliding off. It is shown
  /// only when both transitions are at rest.
  ModalRoute<dynamic>? _route;
  Animation<double>? _own;
  Animation<double>? _above;

  bool get _settled =>
      (_own?.status ?? AnimationStatus.completed) ==
          AnimationStatus.completed &&
      (_above?.status ?? AnimationStatus.dismissed) ==
          AnimationStatus.dismissed;

  void _onAnimation(AnimationStatus _) => _push();

  void _watch(ModalRoute<dynamic>? route) {
    if (identical(route, _route)) return;
    _own?.removeStatusListener(_onAnimation);
    _above?.removeStatusListener(_onAnimation);
    _route = route;
    _own = route?.animation;
    _above = route?.secondaryAnimation;
    _own?.addStatusListener(_onAnimation);
    _above?.addStatusListener(_onAnimation);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watch(ModalRoute.of(context));
    final gesture = Navigator.maybeOf(context)?.userGestureInProgressNotifier;
    if (!identical(gesture, _gesture)) {
      _gesture?.removeListener(_push);
      _gesture = gesture?..addListener(_push);
    }
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;
    if (onTop != _onTop) {
      _onTop = onTop;
      _push();
    }
  }

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_onCall);
    _player.addListener(_push);
    WidgetsBinding.instance.addPostFrameCallback((_) => _push());
  }

  @override
  void didUpdateWidget(_NativeVoiceBar old) {
    super.didUpdateWidget(old);
    if (old.top != widget.top) _push();
  }

  @override
  void dispose() {
    _own?.removeStatusListener(_onAnimation);
    _above?.removeStatusListener(_onAnimation);
    _gesture?.removeListener(_push);
    _player.removeListener(_push);
    _channel.setMethodCallHandler(null);
    if (_shown) _channel.invokeMethod<void>('voiceBarHide');
    super.dispose();
  }

  /// A button of the native bar.
  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method != 'voiceBarAction') return null;
    final m = _player.current;
    switch (call.arguments) {
      case 'toggle':
        if (m != null) _player.toggle(m);
      case 'speed':
        _player.cycleSpeed();
      case 'close':
        _player.stop();
    }
    return null;
  }

  void _push() {
    if (!mounted) return;
    final m = _player.current;
    if (m == null || !_onTop || _swiping || !_settled) {
      if (_shown) {
        _shown = false;
        _last = null;
        _channel.invokeMethod<void>('voiceBarHide');
      }
      return;
    }
    final s = S.of(context);
    final args = <String, dynamic>{
      'title': widget.authorOf(m),
      'subtitle':
          '${s.chatVoiceMessage} · '
          '${formatVoiceTime(_player.position.inMilliseconds)}'
          ' / ${formatVoiceTime(m.durationMs)}',
      'playing': _player.playing,
      'speed': _player.speed == 1.0 ? '1x' : '${_player.speed}x',
      'top': widget.top,
    };
    final key = args.values.join('|');
    if (key == _last) return; // the position moves often: send changes only
    _last = key;
    _shown = true;
    _channel.invokeMethod<void>('voiceBarShow', args).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
