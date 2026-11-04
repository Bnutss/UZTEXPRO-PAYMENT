import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The Face ID icon as iOS Settings draws it: the white Face ID mark on a
/// green rounded square, so the row reads as the system's Face ID setting.
class FaceIdTile extends StatelessWidget {
  const FaceIdTile({super.key, this.size});

  final double? size;

  /// The size an icon tile next to text gets for the user's text scale.
  static double adaptiveSize(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(30).clamp(28.0, 40.0);

  static const _top = Color(0xFF6ECB73);
  static const _bottom = Color(0xFF5FBD64);

  @override
  Widget build(BuildContext context) {
    final size = this.size ?? adaptiveSize(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(size * 0.23),
          ),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_top, _bottom],
          ),
        ),
        child: SvgPicture.asset(
          'assets/icons/face_id.svg',
          width: size * 0.62,
          height: size * 0.62,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
    );
  }
}
