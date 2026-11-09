import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The user's avatar hangs from the Dynamic Island, the way Telegram's
/// profile does.
///
/// At rest it sits right under the island, joined to it by a liquid neck.
/// Scrolling the page up lets the avatar shrink and sink back into the island;
/// pulling it down stretches the neck until the avatar lets go, and it snaps
/// back on release.
///
/// The island is drawn as a black pill under the real cut-out. A fragment
/// shader (`shaders/island.frag`) adds the fields of the island and the avatar
/// (metaballs), samples the photo inside the circle, shrinks it as it nears the
/// island and blurs and dims it on the way. All of it lives in the root
/// overlay, over the page's own header.
///
/// It only runs on iPhones that have an island; elsewhere [supported] is false
/// and the page shows its own avatar.
class IslandPullAvatar extends StatefulWidget {
  const IslandPullAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    required this.photoHeaders,
    required this.active,
    required this.background,
    required this.child,
  });

  final String name;
  final String? photoUrl;
  final Map<String, String> photoHeaders;

  /// Whether this page is the one on screen (one tab of several, say): the
  /// avatar must not hang over the others.
  final bool active;

  /// The colour of the page behind the island.
  final Color background;

  /// The scrolling page. Its scroll offset drives the effect.
  final Widget child;

  /// Devices with an island have a status bar of 59 pixels or more; notched
  /// iPhones stop at 50.
  static bool supported(BuildContext context) =>
      defaultTargetPlatform == TargetPlatform.iOS &&
      MediaQuery.paddingOf(context).top >= 54;

  static double _islandTop(double top) => top >= 62 ? 14.0 : 11.0;

  /// Where the bottom of the avatar is at rest, from the top of the screen:
  /// the page leaves this much room for it.
  static double restBottom(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return _islandTop(top) +
        _Drop.realHeight / 2 +
        _Drop.restDistance +
        _Drop.restRadius;
  }

  /// The diameter of the avatar at rest. The profile pages use the same size
  /// (and, on an island iPhone, the same place), so going from the settings to
  /// "My Profile" and to "Edit" keeps the photo where it is.
  static const avatarSize = _Drop.restRadius * 2;

  /// Where a profile page puts its avatar, from the top of the screen: where
  /// the hanging avatar rests, or just under the status bar elsewhere.
  static double profileAvatarTop(BuildContext context) => supported(context)
      ? restBottom(context) - avatarSize
      : MediaQuery.paddingOf(context).top + 20;

  /// Scroll distance from expanded to merged.
  static const snapRange = _IslandPullAvatarState._snapRange;

  @override
  State<IslandPullAvatar> createState() => _IslandPullAvatarState();
}

class _IslandPullAvatarState extends State<IslandPullAvatar>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Tells the native side where the stand-in island is, so it can cover it
  /// the moment the app goes inactive (see `IslandCover` in AppDelegate.swift).
  static const _coverChannel = MethodChannel('uztexpro/island_cover');
  Rect? _lastCover;

  /// Whether this page is the one on screen. The overlay's frame callbacks can
  /// still fire for a frame or two after another page has covered it; a strip
  /// reported then would stay on the native side and be laid over that page in
  /// the app switcher's snapshot.
  bool _onScreen = false;
  final _offset = ValueNotifier<double>(0);
  final _portal = OverlayPortalController();
  bool _letGo = false;

  /// How much of the drawn island shows, 0 to 1. Gone the moment the app stops
  /// being the active one; back only after it has stayed active for a while,
  /// and then faded in.
  late final AnimationController _island = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 250),
  );
  Timer? _islandTimer;

  /// How long the app has to stay active before the island starts to return.
  static const _islandDelay = Duration(milliseconds: 500);

  ui.FragmentProgram? _program;

  /// The photo, once it has arrived, and the initials that stand in for it.
  ui.Image? _photo;
  ui.Image? _initials;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  String? _photoUrl;
  int _initialsToken = 0;

  static const _initialsInk = Color(0xFFFFFFFF);
  static const _initialsPaper = Color(0xFFFF8C00);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ui.FragmentProgram.fromAsset('shaders/island.frag').then((p) {
      if (mounted) setState(() => _program = p);
    });
    _renderInitials();
    _loadPhoto();
  }

  @override
  void didUpdateWidget(IslandPullAvatar old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name) _renderInitials();
    if (old.photoUrl != widget.photoUrl) _loadPhoto();
  }

  void _reportCover(Rect rect, Color color) {
    if (!mounted || !_onScreen) return;
    final last = _lastCover;
    if (last != null &&
        (last.left - rect.left).abs() < 0.5 &&
        (last.top - rect.top).abs() < 0.5 &&
        (last.right - rect.right).abs() < 0.5 &&
        (last.bottom - rect.bottom).abs() < 0.5) {
      return;
    }
    _lastCover = rect;
    _coverChannel
        .invokeMethod<void>('set', {
          'x': rect.left,
          'y': rect.top,
          'width': rect.width,
          'height': rect.height,
          'color': color.toARGB32(),
        })
        .catchError((_) {});
  }

  void _clearCover() {
    if (_lastCover == null) return;
    _lastCover = null;
    _coverChannel.invokeMethod<void>('clear').catchError((_) {});
  }

  @override
  void dispose() {
    _clearCover();
    WidgetsBinding.instance.removeObserver(this);
    _islandTimer?.cancel();
    _island.dispose();
    _unlisten();
    _photo?.dispose();
    _initials?.dispose();
    _offset.dispose();
    super.dispose();
  }

  /// The system's snapshot for the app switcher has no island in it, so the
  /// pill drawn here would show as a black blob: off at once when the app
  /// stops being the active one, on again once it has settled.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _islandTimer?.cancel();
    if (state != AppLifecycleState.resumed) {
      _island
        ..stop()
        ..value = 0;
      return;
    }
    _islandTimer = Timer(_islandDelay, () {
      if (mounted) _island.forward();
    });
  }

  void _unlisten() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  /// An image still in use by the frame being drawn must not be disposed
  /// under it: let go of it once the frame is done.
  void _release(ui.Image? image) {
    if (image == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  void _loadPhoto() {
    final url = widget.photoUrl;
    final key = (url == null || url.isEmpty) ? null : url;
    if (key == _photoUrl) return;
    _photoUrl = key;
    _unlisten();
    if (key == null) {
      final old = _photo;
      setState(() => _photo = null);
      _release(old);
      return;
    }
    // The old photo stays on screen until the new one arrives.
    final stream = NetworkImage(
      key,
      headers: widget.photoHeaders,
    ).resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, _) {
      final image = info.image.clone();
      if (!mounted || _photoUrl != key) {
        image.dispose();
        return;
      }
      final old = _photo;
      setState(() => _photo = image);
      _release(old);
    }, onError: (_, _) {});
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  static String _initialsOf(String name) {
    final letters = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();
    return letters.isEmpty ? 'U' : letters;
  }

  Future<void> _renderInitials() async {
    final token = ++_initialsToken;
    const size = 256.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, size, size),
      Paint()..color = _initialsPaper,
    );
    final text = TextPainter(
      text: TextSpan(
        text: _initialsOf(widget.name),
        style: const TextStyle(
          color: _initialsInk,
          fontSize: 96,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset((size - text.width) / 2, (size - text.height) / 2),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    picture.dispose();
    if (!mounted || token != _initialsToken) {
      image.dispose();
      return;
    }
    final old = _initials;
    setState(() => _initials = image);
    _release(old);
  }

  /// Scroll distance from expanded to merged.
  static const _snapRange = 120.0;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final offset = n.metrics.pixels;

    // Snapping: let go half way and the avatar runs to whichever end is
    // nearer (it only merges once pulled past two thirds of the way).
    if (n is ScrollEndNotification && offset > 0 && offset < _snapRange) {
      final target = offset > _snapRange * 2 / 3 ? _snapRange : 0.0;
      final context = n.context;
      final position = context == null
          ? null
          : Scrollable.maybeOf(context)?.position;
      if (position != null && target <= n.metrics.maxScrollExtent) {
        // Not right here: while the end of the scroll is being announced the
        // scroll view is still closing its last activity, which would cancel
        // an animation started now. One turn later it is free.
        Future<void>.delayed(Duration.zero, () {
          if (!mounted || !position.hasPixels) return;
          if (position.isScrollingNotifier.value) return; // grabbed again
          final at = position.pixels;
          if (at <= 0 || at >= _snapRange) return;
          position.animateTo(
            target,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        });
      }
    }

    // One tap of feedback when the avatar lets go of the island.
    final pull = offset < 0 ? -offset : 0.0;
    if (pull >= _Drop.letGoAt && !_letGo) HapticFeedback.mediumImpact();
    if (pull < _Drop.letGoAt * 0.4) _letGo = false;
    if (pull >= _Drop.letGoAt) _letGo = true;

    _offset.value = offset;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!IslandPullAvatar.supported(context)) return widget.child;

    final top = MediaQuery.paddingOf(context).top;
    final islandTop = IslandPullAvatar._islandTop(top);

    // Only while this page is the one on screen: another tab, or a page
    // pushed over this one, must not have the avatar hanging over it.
    final active =
        widget.active &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    _onScreen = active;
    if (!active) _clearCover();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (active && !_portal.isShowing) _portal.show();
      if (!active && _portal.isShowing) {
        _portal.hide();
        _clearCover();
      }
    });

    final program = _program;
    final image = _photo ?? _initials;
    final route = ModalRoute.of(context);

    return OverlayPortal(
      overlayLocation: OverlayChildLocation.rootOverlay,
      controller: _portal,
      overlayChildBuilder: (_) => _FadeWithRoute(
        route: route,
        child: Material(
          type: MaterialType.transparency,
          child: program == null || image == null
              ? const SizedBox.shrink()
              : AnimatedBuilder(
                  animation: _island,
                  builder: (context, _) => ValueListenableBuilder<double>(
                    valueListenable: _offset,
                    builder: (context, offset, _) => _Drop(
                      offset: offset,
                      islandTop: islandTop,
                      program: program,
                      image: image,
                      island: _island.value,
                      background: widget.background,
                      onCover: _reportCover,
                    ),
                  ),
                ),
        ),
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      ),
    );
  }
}

/// The avatar lives in the root overlay, above the pages, so a page's own
/// transition does not touch it: leaving the messenger the page faded out while
/// the avatar stayed at full strength (and then vanished), which blinked. This
/// fades it with the page: in as the page comes in, out as it goes, and out
/// while another page covers it.
class _FadeWithRoute extends StatelessWidget {
  const _FadeWithRoute({required this.route, required this.child});

  final ModalRoute<dynamic>? route;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = route;
    if (r == null) return child;
    final own = r.animation;
    final over = r.secondaryAnimation;
    return AnimatedBuilder(
      animation: Listenable.merge([?own, ?over]),
      builder: (context, child) {
        final inValue = own == null
            ? 1.0
            : Curves.easeOut.transform(own.value.clamp(0.0, 1.0));
        final coverValue = over == null ? 0.0 : over.value.clamp(0.0, 1.0);
        final opacity = inValue * (1 - coverValue);
        if (opacity <= 0) return const SizedBox.shrink();
        if (opacity >= 1) return child!;
        return Opacity(opacity: opacity, child: child);
      },
      child: child,
    );
  }
}

class _Drop extends StatelessWidget {
  const _Drop({
    required this.offset,
    required this.islandTop,
    required this.program,
    required this.image,
    required this.island,
    required this.background,
    required this.onCover,
  });

  /// Scroll offset of the page: positive scrolled up, negative pulled down.
  final double offset;
  final double islandTop;
  final ui.FragmentProgram program;
  final ui.Image image;

  /// How much of the island shows, 0 to 1.
  final double island;

  /// Colour of the page behind the island, and where to report the strip the
  /// island and its neck cover (for the native side to hide it in snapshots).
  final Color background;
  final void Function(Rect rect, Color color) onCover;

  // The island as the shader draws it: a little smaller than the real
  // 126 x 37 cut-out, so the drawn pill never shows around it.
  static const realHeight = 37.0;

  /// Half size of the area left empty over the real island.
  static const cutHalfW = 61.5;
  static const cutHalfH = 17.0;
  static const halfW = 59.4;
  static const halfH = 14.4;

  /// The avatar's nominal radius; the drawn one follows from its distance to
  /// the island.
  static const nominalRadius = 80.0;

  /// Must match `REACH` in the shader.
  static const reach = 2.5;

  /// The avatar's centre below the island's, expanded and fully merged.
  static const restDistance = 92.5;
  static const mergedDistance = -27.5;

  /// Radius of the avatar at rest.
  static const restRadius = 38.0;

  /// Pull distance at which the neck snaps and the avatar lets go.
  static const letGoAt = 50.0;

  /// The avatar's radius at [centerY], the same way the shader works it out.
  static double radiusAt(double centerY, double islandCenterY) {
    final surf = (centerY - islandCenterY).abs() - halfH;
    final t = (surf / (nominalRadius * reach)).clamp(0.0, 1.0);
    final proximity = t * t * (3 - 2 * t);
    return ui.lerpDouble(halfH, nominalRadius, proximity)!;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final centerX = width / 2;
    final islandCenterY = islandTop + realHeight / 2;

    // The one value that drives everything: the avatar's centre.
    final restY = islandCenterY + restDistance;
    final minY = islandCenterY + mergedDistance;
    final double cy;
    if (offset >= 0) {
      // Scrolled up: follows the page up into the island.
      cy = math.max(restY - offset, minY);
    } else {
      // Pulled down: the avatar goes down with the page, its foot always a
      // fixed distance above the name, so it never stays behind. It swells as
      // it leaves the island, so the centre is worked out from the foot: the
      // neck stretches and lets go by itself once the field is too weak.
      final foot = restY + radiusAt(restY, islandCenterY) + (-offset);
      var c = restY + (-offset);
      for (var i = 0; i < 6; i++) {
        c = foot - radiusAt(c, islandCenterY);
      }
      cy = c;
    }
    final radius = radiusAt(cy, islandCenterY);

    // From the island down to just above the avatar: everything of the
    // stand-in island that is not the avatar.
    final cover = Rect.fromLTRB(
      centerX - halfW - 4,
      islandTop - 2,
      centerX + halfW + 4,
      math.max(islandTop + realHeight + 2, cy - radius - 1.5),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => onCover(cover, background),
    );

    return SizedBox.expand(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _DropPainter(
            program: program,
            image: image,
            island: island,
            center: Offset(centerX, cy),
            islandCenter: Offset(centerX, islandCenterY),
            bottom: cy + nominalRadius + 10,
          ),
        ),
      ),
    );
  }
}

/// Runs `shaders/island.frag` over the strip of screen the drop can reach.
/// The uniforms go in the order the shader declares them.
class _DropPainter extends CustomPainter {
  _DropPainter({
    required this.program,
    required this.image,
    required this.island,
    required this.center,
    required this.islandCenter,
    required this.bottom,
  });

  final ui.FragmentProgram program;
  final ui.Image image;
  final double island;
  final Offset center;
  final Offset islandCenter;
  final double bottom;

  static const _threshold = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader()
      ..setFloat(0, islandCenter.dx) // uCenter1
      ..setFloat(1, islandCenter.dy)
      ..setFloat(2, _Drop.halfW) // uHalfSize1
      ..setFloat(3, _Drop.halfH)
      ..setFloat(4, _Drop.halfH) // uCornerR1
      ..setFloat(5, center.dx) // uCenter2
      ..setFloat(6, center.dy)
      ..setFloat(7, _Drop.nominalRadius) // uRadius2
      ..setFloat(8, _threshold) // uThreshold
      ..setFloat(9, image.width.toDouble()) // uImageSize
      ..setFloat(10, image.height.toDouble())
      ..setFloat(11, island) // uIslandOn
      ..setFloat(12, _Drop.cutHalfW) // uCutHalf
      ..setFloat(13, _Drop.cutHalfH)
      ..setImageSampler(0, image);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, bottom.clamp(0.0, size.height)),
      Paint()..shader = shader,
    );
    // Created on every paint and holds GPU resources.
    shader.dispose();
  }

  @override
  bool shouldRepaint(_DropPainter old) =>
      old.image != image ||
      old.island != island ||
      old.center != center ||
      old.bottom != bottom;
}
