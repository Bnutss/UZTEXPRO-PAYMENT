import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Pull-to-refresh with the app's own loader instead of Material's
/// [RefreshIndicator]. Drop-in replacement: wrap any vertical scrollable and
/// pass [onRefresh].
///
/// The loader is a small iOS-style tick spinner in the brand colour: ticks
/// appear as you pull, then it spins while [onRefresh] runs. It floats over
/// the content rather than pushing it down.
class AppRefresh extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const AppRefresh({super.key, required this.onRefresh, required this.child});

  @override
  State<AppRefresh> createState() => _AppRefreshState();
}

class _AppRefreshState extends State<AppRefresh>
    with SingleTickerProviderStateMixin {
  static const double _trigger = 80;
  static const double _size = 22;

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  double _pull = 0;
  bool _refreshing = false;
  bool _armed = false;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;

    if (n is ScrollUpdateNotification || n is OverscrollNotification) {
      final pull = math.max(0.0, -n.metrics.pixels);
      if (!_refreshing && pull != _pull) {
        if (pull >= _trigger && !_armed) {
          _armed = true;
          HapticFeedback.mediumImpact();
        } else if (pull < _trigger) {
          _armed = false;
        }
        setState(() => _pull = pull);
      }
    } else if (n is ScrollEndNotification) {
      if (!_refreshing && _armed) {
        _start();
      } else if (_pull != 0) {
        setState(() => _pull = 0);
      }
      _armed = false;
    }
    return false;
  }

  Future<void> _start() async {
    setState(() => _refreshing = true);
    _spin.repeat();
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        _spin.stop();
        setState(() {
          _refreshing = false;
          _pull = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _refreshing ? 1.0 : (_pull / _trigger).clamp(0.0, 1.0);
    final top = -_size + (_size + 14) * progress;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
          ),
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: widget.child,
          ),
        ),
        AnimatedPositioned(
          duration: _refreshing || _pull == 0
              ? const Duration(milliseconds: 220)
              : Duration.zero,
          curve: Curves.easeOutCubic,
          top: top,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Opacity(
              opacity: progress,
              child: Center(
                child: SizedBox(
                  width: _size,
                  height: _size,
                  child: AnimatedBuilder(
                    animation: _spin,
                    builder: (_, __) => CustomPaint(
                      painter: _TicksPainter(
                        progress: progress,
                        spin: _refreshing ? _spin.value : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// iOS-style activity indicator: [_ticks] thin rounded strokes. While pulling,
/// ticks appear one by one; while refreshing, a fading tail rotates around.
class _TicksPainter extends CustomPainter {
  static const int _ticks = 10;

  final double progress;
  final double? spin;

  _TicksPainter({required this.progress, required this.spin});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.width / 2;
    final inner = outer * 0.52;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.11;

    final head = spin == null ? 0 : (spin! * _ticks).floor();
    for (var i = 0; i < _ticks; i++) {
      final double alpha;
      if (spin == null) {
        // Reveal ticks clockwise as the pull progresses.
        alpha = (progress * _ticks - i).clamp(0.0, 1.0) * 0.9;
      } else {
        final behind = (head - i) % _ticks;
        alpha = 1.0 - behind / _ticks * 0.8;
      }
      if (alpha <= 0) continue;
      final a = i / _ticks * 2 * math.pi - math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + dir * inner,
        c + dir * outer,
        paint..color = AppColors.brandOrange.withOpacity(alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_TicksPainter old) =>
      old.progress != progress || old.spin != spin;
}
