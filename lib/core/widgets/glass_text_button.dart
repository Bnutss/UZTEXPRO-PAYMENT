import 'dart:io' show Platform;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A word on a glass capsule (the native glass button on iOS, a gray pill on
/// Android): Telegram's "Edit" / "Done" at the top of a page, the twin of
/// [AdaptiveBackButton].
class GlassTextButton extends StatelessWidget {
  const GlassTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.bold = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool bold;

  static const _ink = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 16,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: onPressed == null ? const Color(0xFF8A8A8E) : _ink,
    );
    // The capsule is as wide as its word.
    final width = (TextPainter(
              text: TextSpan(text: label, style: style),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            )..layout())
            .width +
        32;
    void tap() {
      HapticFeedback.lightImpact();
      onPressed?.call();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Center(
        child: Platform.isIOS
            ? AdaptiveButton.child(
                onPressed: onPressed == null ? null : tap,
                color: _ink,
                style: AdaptiveButtonStyle.glass,
                size: AdaptiveButtonSize.medium,
                useSmoothRectangleBorder: false,
                padding: EdgeInsets.zero,
                borderRadius: BorderRadius.circular(23),
                minSize: Size(width, 46),
                child: SizedBox(
                  width: width,
                  height: 46,
                  child: Center(child: Text(label, style: style)),
                ),
              )
            : Material(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(23),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed == null ? null : tap,
                  child: SizedBox(
                    width: width,
                    height: 46,
                    child: Center(child: Text(label, style: style)),
                  ),
                ),
              ),
      ),
    );
  }
}

/// An icon on a round glass button (the native glass on iOS, a gray circle on
/// Android): Telegram's check mark at the top right, the twin of
/// [AdaptiveBackButton].
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  static const _ink = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled ? _ink : const Color(0xFF8A8A8E);
    void tap() {
      HapticFeedback.lightImpact();
      onPressed?.call();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Center(
        child: Platform.isIOS
            ? SizedBox(
                width: 46,
                height: 46,
                child: AdaptiveButton.icon(
                  onPressed: enabled ? tap : null,
                  icon: icon,
                  iconColor: color,
                  color: _ink,
                  style: AdaptiveButtonStyle.glass,
                  size: AdaptiveButtonSize.medium,
                  useSmoothRectangleBorder: false,
                  padding: EdgeInsets.zero,
                  minSize: const Size(46, 46),
                ),
              )
            : Material(
                color: const Color(0xFFF2F2F2),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: enabled ? tap : null,
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Icon(icon, color: color, size: 24),
                  ),
                ),
              ),
      ),
    );
  }
}
