import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

/// Round glass search button for `AppBar.actions`, same look and size as
/// [AdaptiveBackButton]. Shows a magnifier while the search is closed and a
/// cross while it is open.
class SearchToggleButton extends StatelessWidget {
  final bool active;
  final VoidCallback onPressed;

  const SearchToggleButton({
    super.key,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final icon = active ? Icons.close_rounded : Icons.search_rounded;

    void handlePressed() {
      HapticFeedback.lightImpact();
      onPressed();
    }

    final Widget button;
    if (Platform.isIOS) {
      button = SizedBox(
        width: 46,
        height: 46,
        child: AdaptiveButton.icon(
          onPressed: handlePressed,
          icon: icon,
          iconColor: const Color(0xFF1C1C1E),
          color: const Color(0xFF1C1C1E),
          style: AdaptiveButtonStyle.glass,
          size: AdaptiveButtonSize.medium,
          useSmoothRectangleBorder: false,
          minSize: const Size(46, 46),
        ),
      );
    } else {
      button = Material(
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
            child: Icon(icon, color: const Color(0xFF1C1C1E), size: 22),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Center(child: button),
    );
  }
}

/// Collapsible container for a search bar: slides open / closed with a fade
/// when [open] flips. The child is only built while open, so a `TextField`
/// with `autofocus: true` grabs focus each time the search is opened.
class AnimatedSearchSlot extends StatelessWidget {
  final bool open;
  final Widget child;

  const AnimatedSearchSlot({
    super.key,
    required this.open,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: open
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              builder: (_, v, c) => Opacity(opacity: v, child: c),
              child: child,
            )
          : const SizedBox(width: double.infinity),
    );
  }
}
