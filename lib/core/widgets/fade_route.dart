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

/// A page route with no transition at all: the page is simply there.
///
/// For a page full of native iOS controls (switches, a slider). A native view
/// is a platform view: it ignores the opacity of a fade, so with [FadeRoute] it
/// shows at full strength while the rest of the page is still fading in, and
/// the screen flickers. With no transition everything appears together.
class InstantRoute<T> extends PageRouteBuilder<T> {
  InstantRoute({required WidgetBuilder builder})
    : super(
        pageBuilder: (context, _, _) => builder(context),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
}
