import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

// Same two SVG path outlines as the web app's LogoLoaderComponent.js
// (uztexpro_frontend/src/helpers/LogoLoaderComponent.js), viewBox 0 0 2000 2000.
const String _kLogoPath1 =
    'M588.22 639.88c4.99,-40.35 22.79,-117.22 33.44,-159.05 10.64,-41.83 14.11,-48.63 18.02,-54.15 3.91,-5.52 8.25,-9.77 13.03,-13.17 4.78,-3.39 9.99,-5.94 23.02,-7 13.03,-1.07 33.88,-0.64 95.33,-0.64 61.46,0 163.53,-0.43 215.65,-0.85 52.11,-0.42 54.29,-0.85 56.24,-2.76 1.96,-1.91 3.69,-5.31 7.6,-12.95 3.91,-7.65 9.99,-19.54 15.2,-25.91 5.22,-6.37 9.56,-7.22 18.03,-7.43 8.47,-0.21 21.06,0.21 57.33,0 36.26,-0.21 96.2,-1.06 127.91,-0.42 31.7,0.63 35.17,2.76 39.08,6.58 3.91,3.82 8.26,9.34 11.3,15.08 3.04,5.73 4.78,11.67 6.08,15.92 1.3,4.25 2.17,6.79 5.21,8.07 3.04,1.27 8.25,1.27 59.07,1.06 50.82,-0.21 147.24,-0.64 200.23,-0.21 52.98,0.42 62.54,1.7 70.35,4.88 7.82,3.19 13.9,8.28 18.47,14.87 4.55,6.58 7.6,14.65 10.63,23.78 3.05,9.13 6.08,19.32 8.91,30.37 2.82,11.04 5.42,22.93 40.39,189.62 34.96,166.69 102.28,488.18 136.16,653.6 33.88,165.42 34.31,174.76 31.49,183.25 -2.83,8.5 -8.9,16.14 -14.34,23.79 -5.42,7.64 -10.2,15.29 -18.89,19.11 -8.68,3.82 -21.28,3.82 -37.79,3.82 -16.5,0 -36.91,0 -64.05,-0.21 -27.15,-0.21 -61.03,-0.64 -92.51,-0.43 -31.49,0.22 -60.6,1.07 -81.23,1.49 -20.63,0.43 -32.79,0.43 -41.69,0.21 -8.91,-0.21 -14.55,-0.63 -17.59,0.22 -3.04,0.85 -3.48,2.97 -3.48,8.49 0,5.52 0.44,14.44 0.44,22.93 0,8.5 -0.44,16.56 -3.91,24.21 -3.47,7.64 -9.99,14.86 -17.81,20.17 -7.82,5.31 -16.94,8.71 -26.06,10.41 -9.12,1.69 -18.24,1.69 -28.45,1.91 -10.2,0.21 -21.5,0.63 -36.91,0.85 -15.42,0.21 -34.96,0.21 -64.07,0 -29.09,-0.22 -67.75,-0.64 -158.09,0 -90.34,0.63 -232.37,2.33 -305.77,2.54 -73.39,0.22 -78.17,-1.06 -85.56,-5.09 -7.38,-4.04 -17.37,-10.83 -23.45,-19.54 -6.08,-8.7 -8.25,-19.32 -8.69,-28.88 -0.43,-9.55 0.87,-18.04 2.17,-23.99 1.31,-5.95 2.61,-9.34 1.31,-11.04 -1.31,-1.7 -5.21,-1.7 -63.63,-1.7 -58.42,0 -171.34,0 -231.71,-1.06 -60.38,-1.06 -68.19,-3.19 -74.06,-7.22 -5.86,-4.04 -9.77,-9.98 -13.46,-14.44 -3.69,-4.46 -7.16,-7.43 -9.12,-13.17 -1.95,-5.73 -2.39,-14.23 -0.22,-26.76 2.18,-12.52 6.95,-29.08 12.6,-46.71 5.64,-17.63 12.16,-36.31 16.07,-46.72 3.91,-10.4 5.21,-12.53 13.25,-14.01 8.03,-1.49 22.8,-2.33 30.61,-2.55 7.82,-0.21 8.69,0.21 9.12,2.55 0.44,2.33 0.44,6.58 -0.65,10.62 -1.08,4.03 -3.26,7.85 -7.81,25.05 -4.56,17.2 -11.51,47.78 -14.33,63.28 -2.83,15.5 -1.53,15.93 0.86,16.35 2.39,0.43 5.86,0.85 10.21,0.85 4.34,0 9.55,-0.42 242.79,-1.49 233.23,-1.06 694.48,-2.76 924.67,-5.3 230.19,-2.55 229.33,-5.95 228.02,-9.99 -1.3,-4.03 -3.04,-8.7 -39.09,-179.64 -36.05,-170.93 -106.41,-508.14 -143.32,-677.38 -36.92,-169.24 -40.39,-170.51 -45.17,-171.58 -4.78,-1.06 -10.86,-1.91 -168.3,-0.63 -157.45,1.27 -466.25,4.67 -621.08,7 -154.85,2.34 -155.71,3.62 -164.62,42.26 -8.9,38.65 -25.84,114.67 -35.61,152.68 -9.77,38.01 -12.38,38.01 -17.37,37.37 -5,-0.63 -12.39,-1.91 -19.98,-4.46 -7.61,-2.54 -15.42,-6.37 -10.42,-46.71z';
const String _kLogoPath2 =
    'M112.81 767.04c48.21,-41.47 146.8,-119.65 196.97,-159.17 50.16,-39.53 51.9,-40.4 72.96,-42.57 21.07,-2.17 61.46,-5.64 81.87,-6.73 20.41,-1.09 20.85,0.22 23.67,7.82 2.83,7.6 8.03,21.49 14.12,33 6.08,11.51 13.03,20.63 23.67,31.06 10.64,10.42 24.97,22.15 37.79,30.4 12.81,8.25 24.1,13.03 38.65,17.16 14.55,4.12 32.35,7.6 52.33,6.95 19.98,-0.65 42.13,-5.43 59.07,-12.16 16.94,-6.74 28.67,-15.42 40.61,-27.58 11.94,-12.17 24.11,-27.8 32.36,-41.92 8.25,-14.11 12.59,-26.71 14.99,-37.56 2.38,-10.86 2.81,-19.98 3.25,-26.28 0.43,-6.3 0.87,-9.77 1.74,-11.73 0.86,-1.95 2.17,-2.39 22.37,-4.34 20.19,-1.96 59.28,-5.43 81,-5.86 21.71,-0.44 26.05,2.17 85.56,32.13 59.5,29.97 174.16,87.3 231.71,116.19 57.54,28.88 57.98,29.31 57.11,30.4 -0.87,1.08 -3.04,2.82 -4.56,4.56 -1.52,1.74 -2.39,3.47 -30.4,39.31 -28.02,35.83 -83.17,105.75 -111.4,140.5 -28.23,34.75 -29.54,34.31 -31.28,33.22 -1.73,-1.08 -3.91,-2.82 -33.22,-22.15 -29.32,-19.32 -85.78,-56.24 -114.66,-74.7 -28.89,-18.46 -30.19,-18.46 -31.05,-17.81 -0.87,0.65 -1.31,1.96 25.84,90.34 27.14,88.39 81.86,263.86 108.14,355.71 26.28,91.86 24.1,100.11 19.55,105.98 -4.57,5.86 -11.51,9.34 -21.93,12.38 -10.43,3.04 -24.33,5.64 -62.55,13.24 -38.22,7.6 -100.76,20.2 -132.9,27.15 -32.14,6.95 -33.88,8.25 -33.66,9.34 0.22,1.08 2.38,1.95 6.73,1.95 4.34,0 10.86,-0.87 140.07,-6.51 129.21,-5.65 381.12,-16.07 519.45,-22.15 138.33,-6.09 163.09,-7.82 190.88,-10.21 27.8,-2.39 58.64,-5.43 79.49,-8.69 20.84,-3.26 31.7,-6.73 38.44,-8.68 6.72,-1.96 9.33,-2.39 11.07,-2.82 1.74,-0.44 2.61,-0.87 3.04,-0.22 0.43,0.65 0.43,2.39 -2.17,6.51 -2.61,4.13 -7.82,10.64 -13.03,16.94 -5.21,6.3 -10.42,12.38 -17.37,16.29 -6.96,3.91 -15.64,5.64 -27.15,7.16 -11.51,1.53 -25.84,2.83 -166.13,8.26 -140.28,5.43 -406.53,14.98 -554.19,20.84 -147.67,5.87 -176.78,8.04 -207.4,10.86 -30.61,2.83 -62.75,6.3 -92.72,10.86 -29.97,4.56 -57.77,10.2 -79.49,15.2 -21.71,5 -37.35,9.34 -46.25,11.51 -8.91,2.17 -11.07,2.17 -12.38,1.74 -1.3,-0.44 -1.73,-1.3 -1.95,-7.39 -0.22,-6.08 -0.22,-17.37 2.39,-24.32 2.6,-6.95 7.81,-9.55 17.81,-12.38 9.98,-2.82 24.75,-5.86 74.26,-18.46 49.52,-12.59 133.78,-34.74 186.33,-47.34 52.55,-12.59 73.4,-15.63 92.29,-18.67 18.89,-3.04 35.83,-6.08 45.17,-8.04 9.34,-1.95 11.08,-2.82 11.95,-4.34 0.87,-1.52 0.87,-3.69 0.43,-5.43 -0.43,-1.74 -1.3,-3.04 -4.78,-3.69 -3.47,-0.65 -9.55,-0.65 -14.98,-0.65 -5.43,0 -10.21,0 -108.59,9.12 -98.37,9.12 -290.34,27.36 -386.54,35.18 -96.21,7.82 -96.64,5.21 -95.77,1.52 0.87,-3.69 3.04,-8.47 6.95,-97.51 3.91,-89.03 9.55,-262.33 11.73,-349.63 2.17,-87.3 0.86,-88.6 -0.87,-87.73 -1.74,0.87 -3.91,3.91 -28.23,28.45 -24.33,24.54 -70.8,70.57 -94.9,94.03 -24.11,23.45 -25.84,24.32 -28.23,24.1 -2.39,-0.22 -5.44,-1.52 -38.44,-27.58 -33.01,-26.06 -95.99,-76.87 -129.21,-104.24 -33.23,-27.36 -36.7,-31.26 -39.96,-33.87 -3.26,-2.61 -6.3,-3.91 -8.9,-6.95 -2.61,-3.04 -4.78,-7.82 43.43,-49.3z';

/// Neon stroke-draw animation of the UZTEX logo mark, matching the web
/// app's `.logo-loader` CSS animation (stroke-dasharray/dashoffset drawing
/// a glowing orange outline on an endless loop) via Flutter's PathMetrics.
class LogoStrokeLoader extends StatefulWidget {
  final double size;
  final Duration duration;

  const LogoStrokeLoader({
    super.key,
    this.size = 160,
    this.duration = const Duration(milliseconds: 2200),
  });

  @override
  State<LogoStrokeLoader> createState() => _LogoStrokeLoaderState();
}

class _LogoStrokeLoaderState extends State<LogoStrokeLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Path _path1;
  late final Path _path2;

  @override
  void initState() {
    super.initState();
    _path1 = parseSvgPathData(_kLogoPath1);
    _path2 = parseSvgPathData(_kLogoPath2);
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _LogoStrokePainter(
            path1: _path1,
            path2: _path2,
            progress: _controller.value,
          ),
        ),
      ),
    );
  }
}

class _LogoStrokePainter extends CustomPainter {
  final Path path1;
  final Path path2;
  final double progress;

  static const double _srcSize = 2000;

  _LogoStrokePainter({
    required this.path1,
    required this.path2,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _srcSize;
    canvas.save();
    canvas.scale(scale);

    // Tuned for a white/light background — the web version's pale core +
    // wide translucent glow was designed to pop on a near-black backdrop
    // and reads as a faint smudge here, so the core is now a fully opaque
    // brand orange and the halo is narrower/softer.
    final glowOuter = Paint()
      ..color = const Color(0xFFFF8C00).withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);

    final glowInner = Paint()
      ..color = const Color(0xFFFF8C00).withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final core = Paint()
      ..color = const Color(0xFFFF8C00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final path in [path1, path2]) {
      final drawn = _extractAnimated(path, progress);
      canvas.drawPath(drawn, glowOuter);
      canvas.drawPath(drawn, glowInner);
      canvas.drawPath(drawn, core);
    }

    canvas.restore();
  }

  Path _extractAnimated(Path path, double t) {
    final result = Path();
    for (final metric in path.computeMetrics()) {
      // Reveals the outline from its start point straight through to `t`
      // of its length — the same stroke-dashoffset "draw once, then snap
      // back and redraw" trick the web version uses, not a moving segment.
      final end = metric.length * t;
      if (end > 0) {
        result.addPath(metric.extractPath(0, end), Offset.zero);
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant _LogoStrokePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
