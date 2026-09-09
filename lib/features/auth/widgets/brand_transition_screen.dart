import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'logo_stroke_loader.dart';

/// Full-screen branded overlay used both while a login request is in
/// flight and right after it succeeds — adapted from the web app's
/// `BrandLoadingScreen` (glow pulse + drawing logo mark + staggered
/// title/subtitle) but on the app's own light/white background instead of
/// the web version's dark gradient, replacing the plain circular spinner.
class BrandTransitionScreen extends StatefulWidget {
  final String title;
  final String subtitle;

  const BrandTransitionScreen({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  State<BrandTransitionScreen> createState() => _BrandTransitionScreenState();
}

class _BrandTransitionScreenState extends State<BrandTransitionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _glowLoop;
  late final AnimationController _dotsLoop;

  late final Animation<double> _overlayFade;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subFade;
  late final Animation<Offset> _subSlide;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _glowLoop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _dotsLoop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _overlayFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _logoFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _titleFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
    );
    _titleSlide =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entrance,
            curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
          ),
        );
    _subFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.5, 0.9, curve: Curves.easeOut),
    );
    _subSlide =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entrance,
            curve: const Interval(0.5, 0.9, curve: Curves.easeOut),
          ),
        );
  }

  @override
  void dispose() {
    _entrance.dispose();
    _glowLoop.dispose();
    _dotsLoop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: FadeTransition(
        opacity: _overlayFade,
        child: Material(
          color: Colors.transparent,
          child: Container(
            color: AppColors.groupedBackground,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _glowLoop,
                  builder: (context, _) {
                    final pulse =
                        0.5 + 0.5 * math.sin(_glowLoop.value * 2 * math.pi);
                    return Container(
                      width: 460,
                      height: 460,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.brandOrange.withOpacity(
                              0.14 + 0.1 * pulse,
                            ),
                            AppColors.brandOrange.withOpacity(0),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoFade,
                        child: const LogoStrokeLoader(size: 180),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SlideTransition(
                      position: _titleSlide,
                      child: FadeTransition(
                        opacity: _titleFade,
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: Color(0xFF1C1C1E),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SlideTransition(
                      position: _subSlide,
                      child: FadeTransition(
                        opacity: _subFade,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.subtitle,
                              style: const TextStyle(
                                color: Color(0xFF8A8A8E),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _BouncingDots(loop: _dotsLoop),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BouncingDots extends StatelessWidget {
  final Animation<double> loop;
  const _BouncingDots({required this.loop});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loop,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (loop.value + i * 0.125) % 1.0;
            final bounce = math.sin(phase * math.pi).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, -5 * bounce),
                child: Opacity(
                  opacity: 0.4 + 0.6 * bounce,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Color(0xFF8A8A8E),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
