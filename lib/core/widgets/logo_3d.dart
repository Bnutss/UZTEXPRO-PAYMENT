import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Triangles of assets/models/logo3d.glb, centered and scaled to fit a unit
/// sphere. Loaded once and shared by every [Logo3D].
class Logo3DModel {
  static const _asset = 'assets/models/logo3d.glb';

  /// x, y, z of the three corners of each triangle.
  final Float32List positions;

  /// Outward unit normal of each triangle.
  final Float32List normals;

  /// sRGB color of each triangle as 0xAARRGGBB.
  final Int32List colors;

  Logo3DModel._(this.positions, this.normals, this.colors);

  int get triangleCount => colors.length;

  static Logo3DModel? instance;
  static Future<Logo3DModel>? _loading;

  /// Starts loading the model; call early (main) so the first frame that
  /// shows the logo already has it.
  static Future<Logo3DModel> preload() => _loading ??= _load();

  static Future<Logo3DModel> _load() async {
    final data = await rootBundle.load(_asset);
    return instance = _parseGlb(data);
  }

  /// Minimal glTF 2.0 binary reader: triangle-list primitives with indexed
  /// float positions and a base color factor — all the exporter writes.
  static Logo3DModel _parseGlb(ByteData data) {
    final jsonLength = data.getUint32(12, Endian.little);
    final json =
        jsonDecode(
              utf8.decode(
                data.buffer.asUint8List(data.offsetInBytes + 20, jsonLength),
              ),
            )
            as Map<String, dynamic>;
    final binStart = 20 + jsonLength + 8;

    final accessors = json['accessors'] as List;
    final views = json['bufferViews'] as List;
    final materials = json['materials'] as List? ?? const [];
    final meshes = json['meshes'] as List;

    List<num> read(int accessorIndex) {
      final acc = accessors[accessorIndex] as Map<String, dynamic>;
      final view = views[acc['bufferView'] as int] as Map<String, dynamic>;
      final width = switch (acc['type']) {
        'VEC3' => 3,
        _ => 1,
      };
      final type = acc['componentType'] as int;
      final size = switch (type) {
        5121 => 1,
        5123 => 2,
        _ => 4,
      };
      final stride = view['byteStride'] as int? ?? width * size;
      final base =
          binStart +
          (view['byteOffset'] as int? ?? 0) +
          (acc['byteOffset'] as int? ?? 0);
      final count = acc['count'] as int;
      final out = <num>[];
      for (var i = 0; i < count; i++) {
        for (var c = 0; c < width; c++) {
          final at = base + i * stride + c * size;
          out.add(switch (type) {
            5126 => data.getFloat32(at, Endian.little),
            5125 => data.getUint32(at, Endian.little),
            5123 => data.getUint16(at, Endian.little),
            _ => data.getUint8(at),
          });
        }
      }
      return out;
    }

    // glTF colors are linear; the screen wants sRGB.
    int toSrgb(num linear) {
      final l = linear.clamp(0, 1).toDouble();
      final s = l <= 0.0031308
          ? l * 12.92
          : 1.055 * math.pow(l, 1 / 2.4) - 0.055;
      return (s * 255).round();
    }

    final pos = <double>[];
    final cols = <int>[];
    for (final mesh in meshes) {
      for (final prim in (mesh as Map<String, dynamic>)['primitives'] as List) {
        final p = prim as Map<String, dynamic>;
        if ((p['mode'] as int? ?? 4) != 4) continue;
        final vertices = read((p['attributes'] as Map)['POSITION'] as int);
        final indices = p['indices'] != null
            ? read(p['indices'] as int)
            : List<int>.generate(vertices.length ~/ 3, (i) => i);
        var color = 0xFFCCCCCC;
        final m = p['material'];
        if (m != null) {
          final f =
              ((materials[m as int] as Map)['pbrMetallicRoughness']
                      as Map?)?['baseColorFactor']
                  as List?;
          if (f != null) {
            color =
                0xFF000000 |
                toSrgb(f[0] as num) << 16 |
                toSrgb(f[1] as num) << 8 |
                toSrgb(f[2] as num);
          }
        }
        for (var i = 0; i + 2 < indices.length; i += 3) {
          for (var k = 0; k < 3; k++) {
            final v = indices[i + k].toInt() * 3;
            pos
              ..add(vertices[v].toDouble())
              ..add(vertices[v + 1].toDouble())
              ..add(vertices[v + 2].toDouble());
          }
          cols.add(color);
        }
      }
    }

    // Center on the bounding box and scale into a unit sphere so the widget
    // can fit any rotation into its box.
    var minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    var maxZ = -double.infinity;
    for (var i = 0; i < pos.length; i += 3) {
      minX = math.min(minX, pos[i]);
      maxX = math.max(maxX, pos[i]);
      minY = math.min(minY, pos[i + 1]);
      maxY = math.max(maxY, pos[i + 1]);
      minZ = math.min(minZ, pos[i + 2]);
      maxZ = math.max(maxZ, pos[i + 2]);
    }
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    final cz = (minZ + maxZ) / 2;
    var radius = 0.0;
    for (var i = 0; i < pos.length; i += 3) {
      pos[i] -= cx;
      pos[i + 1] -= cy;
      pos[i + 2] -= cz;
      radius = math.max(
        radius,
        math.sqrt(
          pos[i] * pos[i] + pos[i + 1] * pos[i + 1] + pos[i + 2] * pos[i + 2],
        ),
      );
    }
    final positions = Float32List(pos.length);
    for (var i = 0; i < pos.length; i++) {
      positions[i] = pos[i] / radius;
    }

    final normals = Float32List(cols.length * 3);
    for (var t = 0; t < cols.length; t++) {
      final o = t * 9;
      final ax = positions[o + 3] - positions[o];
      final ay = positions[o + 4] - positions[o + 1];
      final az = positions[o + 5] - positions[o + 2];
      final bx = positions[o + 6] - positions[o];
      final by = positions[o + 7] - positions[o + 1];
      final bz = positions[o + 8] - positions[o + 2];
      final nx = ay * bz - az * by;
      final ny = az * bx - ax * bz;
      final nz = ax * by - ay * bx;
      final len = math.sqrt(nx * nx + ny * ny + nz * nz);
      if (len > 0) {
        normals[t * 3] = nx / len;
        normals[t * 3 + 1] = ny / len;
        normals[t * 3 + 2] = nz / len;
      }
    }
    return Logo3DModel._(positions, normals, Int32List.fromList(cols));
  }
}

/// The UztexPro logo as a real 3D model that keeps spinning on its own.
/// Rendered natively (no WebView), so it shows up on the very first frame.
/// With [interactive] the user can spin it with a finger; after letting go
/// it eases back to the idle spin. Fills whatever box it's given.
class Logo3D extends StatefulWidget {
  final bool interactive;

  const Logo3D({super.key, this.interactive = false});

  @override
  State<Logo3D> createState() => _Logo3DState();
}

class _Logo3DState extends State<Logo3D> with SingleTickerProviderStateMixin {
  static const _idleSpeed = 2 * math.pi / 8; // one turn per 8 s

  late final Ticker _ticker;
  final _yaw = ValueNotifier<double>(0);
  Logo3DModel? _model = Logo3DModel.instance;
  Duration _last = Duration.zero;
  double _speed = _idleSpeed;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    if (_model == null) {
      Logo3DModel.preload().then((m) {
        if (mounted) setState(() => _model = m);
      });
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (_dragging || dt <= 0 || dt > 0.25) return;
    // A fling decays back into the idle spin, in whichever direction it
    // was going.
    final target = _speed.isNegative ? -_idleSpeed : _idleSpeed;
    _speed += (target - _speed) * (1 - math.exp(-dt * 1.8));
    _yaw.value += _speed * dt;
  }

  void _onDragStart(DragStartDetails _) => _dragging = true;

  void _onDragUpdate(DragUpdateDetails d) {
    final width = context.size?.width ?? 100;
    _yaw.value += d.delta.dx / width * math.pi;
  }

  void _onDragEnd(DragEndDetails d) {
    final width = context.size?.width ?? 100;
    _speed = (d.velocity.pixelsPerSecond.dx / width * math.pi).clamp(-14, 14);
    if (_speed.abs() < _idleSpeed) {
      _speed = _speed.isNegative ? -_idleSpeed : _idleSpeed;
    }
    _dragging = false;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _yaw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    if (model == null) {
      return Image.asset('assets/icon/logo.png', fit: BoxFit.contain);
    }
    final view = RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _LogoPainter(model, _yaw),
      ),
    );
    if (!widget.interactive) return view;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: () => _dragging = false,
      child: view,
    );
  }
}

/// Depth-sorted flat-shaded rasterization through Canvas.drawVertices. The
/// model's faces are cut small enough that sorting by triangle center gives
/// a correct picture without a depth buffer.
class _LogoPainter extends CustomPainter {
  // Slight look from above so the top edges of the extrusion show.
  static const _pitch = -0.16;
  static final _cp = math.cos(_pitch), _sp = math.sin(_pitch);
  static const _cameraDistance = 4.0;
  // Light from the upper left, a bit in front; a face looking straight at
  // the camera keeps its exact brand color.
  static const _lx = -0.38, _ly = 0.42, _lz = 0.82;
  static const _ambient = 0.76;

  final Logo3DModel model;
  final ValueListenable<double> yaw;

  late final Float32List _screen = Float32List(model.triangleCount * 6);
  late final Int32List _colors = Int32List(model.triangleCount * 3);
  late final Float64List _depth = Float64List(model.triangleCount);
  late final Float32List _projected = Float32List(model.triangleCount * 6);
  final List<int> _visible = [];

  _LogoPainter(this.model, this.yaw) : super(repaint: yaw);

  @override
  void paint(Canvas canvas, Size size) {
    final half = math.min(size.width, size.height) / 2;
    final focal = half * (_cameraDistance - 1);
    final ox = size.width / 2, oy = size.height / 2;
    final cy = math.cos(yaw.value), sy = math.sin(yaw.value);
    final cp = _cp, sp = _sp;
    final lLen = math.sqrt(_lx * _lx + _ly * _ly + _lz * _lz);
    final lx = _lx / lLen, ly = _ly / lLen, lz = _lz / lLen;
    // Normalize so a face pointing at the camera gets shade 1.0.
    final frontShade = _ambient + (1 - _ambient) * lz;

    // Two-sided like a coin: while the back is toward the camera, draw the
    // model mirrored so the wordmark reads correctly instead of backwards.
    // The swap happens edge-on, where it can't be seen.
    final mirror = cy < 0 ? -1.0 : 1.0;

    final p = model.positions, n = model.normals;
    _visible.clear();
    for (var t = 0; t < model.triangleCount; t++) {
      var depthSum = 0.0;
      for (var k = 0; k < 3; k++) {
        final o = t * 9 + k * 3;
        final x = p[o] * mirror, y = p[o + 1], z = p[o + 2];
        final x1 = x * cy + z * sy;
        final z1 = -x * sy + z * cy;
        final y2 = y * cp - z1 * sp;
        final z2 = y * sp + z1 * cp;
        final w = focal / (_cameraDistance - z2);
        _projected[t * 6 + k * 2] = ox + x1 * w;
        _projected[t * 6 + k * 2 + 1] = oy - y2 * w;
        depthSum += z2;
      }
      final q = t * 6;
      final area =
          (_projected[q + 2] - _projected[q]) *
              (_projected[q + 5] - _projected[q + 1]) -
          (_projected[q + 4] - _projected[q]) *
              (_projected[q + 3] - _projected[q + 1]);
      // Facing away (screen y points down; mirroring flips the winding).
      if (area * mirror >= 0) continue;
      _depth[t] = depthSum;
      _visible.add(t);
    }
    _visible.sort((a, b) => _depth[a].compareTo(_depth[b]));

    var i = 0;
    for (final t in _visible) {
      final nx = n[t * 3] * mirror, ny = n[t * 3 + 1], nz = n[t * 3 + 2];
      final nz1 = -nx * sy + nz * cy;
      final nx1 = nx * cy + nz * sy;
      final ny2 = ny * cp - nz1 * sp;
      final nz2 = ny * sp + nz1 * cp;
      final diffuse = math.max(0.0, nx1 * lx + ny2 * ly + nz2 * lz);
      final shade = (_ambient + (1 - _ambient) * diffuse) / frontShade;
      final color = _shade(model.colors[t], shade);
      for (var k = 0; k < 6; k++) {
        _screen[i * 6 + k] = _projected[t * 6 + k];
      }
      _colors[i * 3] = color;
      _colors[i * 3 + 1] = color;
      _colors[i * 3 + 2] = color;
      i++;
    }
    if (i == 0) return;
    final vertices = ui.Vertices.raw(
      VertexMode.triangles,
      Float32List.sublistView(_screen, 0, i * 6),
      colors: Int32List.sublistView(_colors, 0, i * 3),
    );
    canvas.drawVertices(vertices, BlendMode.dst, Paint());
    vertices.dispose();
  }

  static int _shade(int argb, double f) {
    int ch(int shift) => (((argb >> shift) & 0xFF) * f).round().clamp(0, 255);
    return 0xFF000000 | ch(16) << 16 | ch(8) << 8 | ch(0);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.model != model;
}
