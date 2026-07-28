import 'package:flutter/widgets.dart';

/// Fades + slides a child in once, after [delay]. Skips straight to the
/// visible end state when the OS accessibility setting for reduced motion
/// is on, instead of running the animation anyway.
class StaggerIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const StaggerIn({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations) {
      _visible = true;
      return;
    }
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 0.06),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
