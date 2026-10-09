import 'package:flutter/material.dart';

/// Plain cross-fade page route. Unlike [MaterialPageRoute] on iOS it does not
/// slide the new page in while parallax-shifting the old one, which made some
/// screens blink while opening.
class FadeRoute<T> extends PageRouteBuilder<T> {
  FadeRoute({required WidgetBuilder builder})
    : super(
        pageBuilder: (context, _, _) => builder(context),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );
}
