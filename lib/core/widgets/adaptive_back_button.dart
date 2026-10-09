import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

/// Round glass back button used as an `AppBar.leading` on every pushed
/// screen, instead of the platform's default flat back arrow — kept as one
/// shared widget so every screen renders it identically instead of each
/// screen re-implementing its own slightly-different copy.
class AdaptiveBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const AdaptiveBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    void handlePressed() {
      HapticFeedback.lightImpact();
      if (onPressed != null) {
        onPressed!();
      } else {
        Navigator.of(context).maybePop();
      }
    }

    if (Platform.isIOS) {
      return SizedBox(
        width: 46,
        height: 46,
        child: AdaptiveButton.icon(
          onPressed: handlePressed,
          icon: Icons.arrow_back_ios_new_rounded,
          iconColor: const Color(0xFF1C1C1E),
          color: const Color(0xFF1C1C1E),
          style: AdaptiveButtonStyle.glass,
          size: AdaptiveButtonSize.medium,
          useSmoothRectangleBorder: false,
          minSize: const Size(46, 46),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: handlePressed,
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFF2F2F2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF1C1C1E),
            size: 22,
          ),
        ),
      ),
    );
  }
}
