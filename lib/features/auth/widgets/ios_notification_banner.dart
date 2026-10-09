import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/localization/app_strings.dart';

/// A banner that looks and behaves like a native iOS notification: frosted
/// glass capsule with the app icon, bold title, message and a "now" stamp.
/// It drops in from the top with a slight overshoot, can be swiped up (or
/// tapped) to dismiss, and goes away on its own after a few seconds.
///
/// Only one banner is shown at a time; a new one replaces the current one.
class IosNotificationBanner {
  IosNotificationBanner._();

  static OverlayEntry? _current;

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    bool isError = true,
  }) {
    _current?.remove();
    _current = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _BannerWidget(
        title: title,
        message: message,
        isError: isError,
        onDismissed: () {
          if (_current == entry) _current = null;
          entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
    if (isError) HapticFeedback.heavyImpact();
  }
}

class _BannerWidget extends StatefulWidget {
  final String title;
  final String message;
  final bool isError;
  final VoidCallback onDismissed;

  const _BannerWidget({
    required this.title,
    required this.message,
    required this.isError,
    required this.onDismissed,
  });

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  double _drag = 0;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 260),
    )..forward();
    _timer = Timer(const Duration(seconds: 4), _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (mounted) await _controller.reverse();
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final slide = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: slide,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (slide.value - 1) * 140 + _drag),
          child: Opacity(
            opacity: _controller.value.clamp(0.0, 1.0),
            child: child,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
            child: Semantics(
              liveRegion: true,
              label: '${widget.title}. ${widget.message}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _dismiss,
                onVerticalDragUpdate: (d) {
                  // Follow the finger upward only; resist downward pulls.
                  setState(() => _drag = (_drag + d.delta.dy).clamp(-160, 8));
                },
                onVerticalDragEnd: (d) {
                  if (_drag < -24 || (d.primaryVelocity ?? 0) < -300) {
                    _dismiss();
                  } else {
                    setState(() => _drag = 0);
                  }
                },
                child: _BannerCard(
                  title: widget.title,
                  message: widget.message,
                  isError: widget.isError,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final String title;
  final String message;
  final bool isError;

  const _BannerCard({
    required this.title,
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.84),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withOpacity(0.7)),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _AppIcon(isError: isError),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF1C1C1E),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              S.of(context).notificationNow,
                              style: const TextStyle(
                                color: Color(0xFF8A8A8E),
                                fontSize: 12.5,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message,
                          style: const TextStyle(
                            color: Color(0xFF3A3A3C),
                            fontSize: 14.5,
                            height: 1.25,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final bool isError;

  const _AppIcon({required this.isError});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/icon/logo.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
          if (isError)
            Positioned(
              right: -5,
              bottom: -5,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.priority_high_rounded,
                  size: 11,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
