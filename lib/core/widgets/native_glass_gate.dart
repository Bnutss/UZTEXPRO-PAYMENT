import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// True while a Flutter overlay that blurs the screen is open (the chat's
/// message menu).
///
/// A native Liquid Glass control (the back button, the name and the avatar in
/// the header) is a UIKit view: Flutter's blur cannot reach it, so it would
/// stay sharp and square on top of the blurred page. While this is true those
/// controls draw a plain Flutter stand-in, which the blur covers like the rest.
final ValueNotifier<bool> nativeGlassHidden = ValueNotifier<bool>(false);

/// A native glass control and its Flutter stand-in.
///
/// The stand-in is drawn instead of the native view
///  * while a Flutter overlay blurs the screen ([nativeGlassHidden]), and
///  * while ANOTHER screen is on its way over this one or away from it (a
///    profile, a photo, whatever is pushed above): a UIKit view does not follow
///    the Flutter transform of the page, so it would hang in place, show through
///    or flicker while the page slides. The stand-in is Flutter's and slides
///    with the page.
///
/// The native view is NOT removed while the stand-in shows: it only stops being
/// painted ([Offstage]), so it stays alive and comes back at once, with no
/// re-creation (which flickered). The stand-in appears instantly and, when the
/// native glass is back, fades out over it instead of vanishing with a jump.
/// Both must have the same size.
class NativeGlassSwap extends StatefulWidget {
  const NativeGlassSwap({
    super.key,
    required this.native,
    required this.standIn,
  });

  final Widget native;
  final Widget standIn;

  @override
  State<NativeGlassSwap> createState() => _NativeGlassSwapState();
}

class _NativeGlassSwapState extends State<NativeGlassSwap> {
  Animation<double>? _above;

  /// A screen above this one is opening, is open, or is closing.
  bool get _covered =>
      (_above?.status ?? AnimationStatus.dismissed) !=
      AnimationStatus.dismissed;

  void _onAbove(AnimationStatus _) {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final above = ModalRoute.of(context)?.secondaryAnimation;
    if (!identical(above, _above)) {
      _above?.removeStatusListener(_onAbove);
      _above = above?..addStatusListener(_onAbove);
    }
  }

  @override
  void dispose() {
    _above?.removeStatusListener(_onAbove);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: nativeGlassHidden,
      builder: (context, hidden, _) {
        final standIn = hidden || _covered;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Offstage(offstage: standIn, child: widget.native),
            IgnorePointer(
              ignoring: !standIn,
              child: AnimatedOpacity(
                opacity: standIn ? 1 : 0,
                duration: standIn
                    ? Duration.zero
                    : const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                child: widget.standIn,
              ),
            ),
          ],
        );
      },
    );
  }
}
