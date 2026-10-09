import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

/// Flutter-drawn replacement for `AdaptiveButton.child`.
///
/// The native iOS button is a platform view: it ignores the opacity of our
/// FadeRoute transition and flashes on screen when a page opens or closes.
/// This one takes the same arguments and draws the same tinted / filled /
/// plain looks, but entirely in Flutter.
class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final AdaptiveButtonStyle style;
  final Color color;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Size? minSize;
  final AdaptiveButtonSize? size;
  final Widget child;

  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style = AdaptiveButtonStyle.filled,
    this.color = const Color(0xFFFF8C00),
    this.borderRadius,
    this.padding,
    this.minSize,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12);
    final Color bg;
    switch (style) {
      case AdaptiveButtonStyle.filled:
        bg = color;
        break;
      case AdaptiveButtonStyle.plain:
        bg = Colors.transparent;
        break;
      default:
        bg = color.withOpacity(0.12);
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minSize?.width ?? 0,
        minHeight: minSize?.height ?? 0,
      ),
      child: Material(
        color: bg,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Padding(
            padding:
                padding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(widthFactor: 1, heightFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}
