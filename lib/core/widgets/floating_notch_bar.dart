import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

class NotchBarItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NotchBarItem(this.icon, this.activeIcon, this.label);
}

/// Нижнее меню: плавающая панель с вырезом, в котором «сидит» круглая кнопка
/// активного пункта. Круг и вырез плавно переезжают на выбранный пункт.
class FloatingNotchBar extends StatelessWidget {
  final List<NotchBarItem> items;
  final int selected;
  final ValueChanged<int> onSelected;

  const FloatingNotchBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  static const double _barHeight = 66;
  static const double _lift = 24; // насколько круг выступает над панелью
  static const double _circle = 56;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final off = MediaQuery.disableAnimationsOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final outline = isDark
        ? Colors.white.withOpacity(0.09)
        : Colors.black.withOpacity(0.06);
    final idleIcon = isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
    final idleLabel = isDark ? const Color(0xFFAEAEB2) : const Color(0xFF636366);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 10 + (bottom > 0 ? bottom - 6 : 0)),
      child: SizedBox(
        height: _barHeight + _lift,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            const pad = 12.0;
            final slot = (w - pad * 2) / items.length;
            double centerOf(int i) => pad + slot * (i + 0.5);

            return TweenAnimationBuilder<double>(
              tween: Tween(end: centerOf(selected)),
              duration: off ? Duration.zero : const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              builder: (context, cx, _) => Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _lift,
                    height: _barHeight,
                    child: CustomPaint(
                      painter: _BarPainter(
                        cx: cx,
                        fill: surface,
                        outline: outline,
                        shadow: Colors.black.withOpacity(isDark ? 0.5 : 0.16),
                      ),
                    ),
                  ),
                  Positioned(
                    left: cx - _circle / 2,
                    top: 0,
                    child: ExcludeSemantics(
                      child: Container(
                        width: _circle,
                        height: _circle,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.brandOrange, AppColors.brandRed],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.brandOrange.withOpacity(0.18),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brandRed.withOpacity(0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: off
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          transitionBuilder: (child, a) => ScaleTransition(
                            scale: a,
                            child: FadeTransition(opacity: a, child: child),
                          ),
                          child: Icon(
                            items[selected].activeIcon,
                            key: ValueKey(selected),
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (final (i, item) in items.indexed)
                    Positioned(
                      left: pad + slot * i,
                      width: slot,
                      top: _lift,
                      height: _barHeight,
                      child: Semantics(
                        button: true,
                        selected: i == selected,
                        label: item.label,
                        excludeSemantics: true,
                        child: _Pressable(
                          onTap: () {
                            if (i != selected) HapticFeedback.selectionClick();
                            onSelected(i);
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: i == selected ? 0 : 1,
                                child: Icon(item.icon, size: 26, color: idleIcon),
                              ),
                              const SizedBox(height: 4),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.1,
                                  fontWeight: i == selected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: i == selected
                                      ? AppColors.brandRed
                                      : idleLabel,
                                ),
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 9),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final double cx;
  final Color fill;
  final Color outline;
  final Color shadow;

  _BarPainter({
    required this.cx,
    required this.fill,
    required this.outline,
    required this.shadow,
  });

  static const double _r = 28; // радиус углов панели
  static const double _notchR = 34; // половина ширины выреза у основания
  static const double _dip = 30; // глубина выреза

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final shoulderL = cx - (_notchR + 16);
    final shoulderR = cx + (_notchR + 16);
    // Когда вырез у самого края, угол панели уменьшается, чтобы формы не накладывались
    final rl = shoulderL.clamp(0.0, _r).toDouble();
    final rr = (w - shoulderR).clamp(0.0, _r).toDouble();

    final p = Path()
      ..moveTo(0, rl)
      ..quadraticBezierTo(0, 0, rl, 0)
      ..lineTo(shoulderL.clamp(rl, w), 0)
      ..cubicTo(cx - _notchR * 0.62, 0, cx - _notchR * 0.82, _dip, cx, _dip)
      ..cubicTo(cx + _notchR * 0.82, _dip, cx + _notchR * 0.62, 0,
          shoulderR.clamp(0, w - rr), 0)
      ..lineTo(w - rr, 0)
      ..quadraticBezierTo(w, 0, w, rr)
      ..lineTo(w, h - _r)
      ..quadraticBezierTo(w, h, w - _r, h)
      ..lineTo(_r, h)
      ..quadraticBezierTo(0, h, 0, h - _r)
      ..close();

    canvas.drawShadow(p, shadow, 14, true);
    canvas.drawPath(p, Paint()..color = fill);
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = outline,
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.cx != cx || old.fill != fill || old.outline != outline || old.shadow != shadow;
}

/// Нажимаемая область без «ряби» Material: пункт слегка уменьшается и тускнеет.
class _Pressable extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _Pressable({required this.onTap, required this.child});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.9 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 110),
            opacity: _down ? 0.65 : 1,
            child: widget.child,
          ),
        ),
      );
}
