import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/settings/island_pull_avatar.dart';
import 'ui_blocks.dart';

/// A profile page that does what Telegram's does.
///
/// At rest the round photo hangs under the Dynamic Island (on an iPhone that
/// has one, where scrolling up lets it flow into the island: [IslandPullAvatar])
/// or sits under the status bar, with the name, the status and the buttons
/// under it. Pull the page down and the photo opens into a big picture over the
/// top of the screen: one short swipe is enough, the photo follows the finger
/// for the first stretch and then opens the rest of the way by itself with a
/// smooth ease; the name, the status and the buttons go down with it and end up
/// over its foot, in white. Stopped short, it goes back to round (a quick flick
/// still opens it); drag up and it closes the same way.
///
/// While the page is leaving (the "back" button, the swipe back, another screen
/// coming over it) the avatar that hangs from the island is taken off at once
/// and the page draws its own round photo, which slides away with it.
///
/// There is one set of name, status and buttons, drawn by [blockBuilder] for
/// every state: it is given how open the photo is (0 to 1) and blends its look
/// (dark to white, centred to left) itself.
class PullPhotoList extends StatefulWidget {
  const PullPhotoList({
    super.key,
    required this.top,
    required this.name,
    required this.sources,
    required this.blockHeight,
    required this.blockBuilder,
    required this.children,
    this.gap = 10,
    this.bottomPadding = 32,
  });

  /// Where the round photo starts, from the top of the screen.
  final double top;
  final String name;

  /// The picture; with none there is nothing to open (the page just scrolls).
  final List<PhotoSource> sources;

  /// The height of what sits under the round photo (name, status, buttons).
  final double blockHeight;

  /// Draws it, given how open the photo is, 0 (round) to 1 (open).
  final Widget Function(BuildContext context, double t) blockBuilder;

  /// The rest of the page.
  final List<Widget> children;

  /// Between the round photo and [blockBuilder]'s block.
  final double gap;
  final double bottomPadding;

  /// How tall the open photo is, as a multiple of the screen width.
  static const double openRatio = 1.22;

  @override
  State<PullPhotoList> createState() => _PullPhotoListState();
}

class _PullPhotoListState extends State<PullPhotoList>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  /// How far a finger travels for the photo to go from round to fully open.
  static const double _span = 110;

  /// Past this much opening the photo no longer waits for the finger: it goes
  /// the rest of the way by itself, so a short swipe is enough.
  static const double _autoAt = 0.3;

  /// A flick faster than this (px per move) opens it even from a short pull.
  static const double _flick = 6;

  /// A finger is down and the photo follows it.
  bool _tracking = false;

  /// What the following started from: 0 (round, opening) or 1 (open, closing).
  double _from = 0;
  int _fingers = 0;

  /// The last non-zero step of the finger (+ down, - up): where it was going.
  double _lastDy = 0;

  // The route this page is on: while it is leaving the avatar hanging from the
  // island must not stay (see the class comment).
  ModalRoute<dynamic>? _route;
  Animation<double>? _own;
  Animation<double>? _above;
  ValueNotifier<bool>? _gesture;
  bool _leaving = false;

  void _routeChanged([Object? _]) {
    final own = _own?.status ?? AnimationStatus.completed;
    final above = _above?.status ?? AnimationStatus.dismissed;
    final leaving =
        own == AnimationStatus.reverse ||
        own == AnimationStatus.dismissed ||
        above != AnimationStatus.dismissed ||
        (_gesture?.value ?? false);
    if (leaving != _leaving && mounted) setState(() => _leaving = leaving);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!identical(route, _route)) {
      _own?.removeStatusListener(_routeChanged);
      _above?.removeStatusListener(_routeChanged);
      _route = route;
      _own = route?.animation;
      _above = route?.secondaryAnimation;
      _own?.addStatusListener(_routeChanged);
      _above?.addStatusListener(_routeChanged);
    }
    final gesture = Navigator.maybeOf(context)?.userGestureInProgressNotifier;
    if (!identical(gesture, _gesture)) {
      _gesture?.removeListener(_routeChanged);
      _gesture = gesture?..addListener(_routeChanged);
    }
  }

  double get _size => IslandPullAvatar.avatarSize;
  bool get _canOpen => widget.sources.isNotEmpty;
  bool get _atTop => !_scroll.hasClients || _scroll.offset <= 0.5;

  @override
  void dispose() {
    _own?.removeStatusListener(_routeChanged);
    _above?.removeStatusListener(_routeChanged);
    _gesture?.removeListener(_routeChanged);
    _scroll.dispose();
    _open.dispose();
    super.dispose();
  }

  /// On an island iPhone a pull first stretches the avatar's neck (see
  /// [IslandPullAvatar]); only letting go of the island opens the photo.
  bool _island(BuildContext context) => IslandPullAvatar.supported(context);

  /// Gliding to [to]: a smooth ease-out, quick to start and soft to arrive.
  void _glide(double to) {
    if (to == _open.value) return;
    final opening = to > _open.value;
    HapticFeedback.selectionClick();
    _open.animateTo(
      to,
      duration: Duration(milliseconds: opening ? 360 : 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _begin(double from) {
    _tracking = true;
    _from = from;
  }

  /// The photo follows the finger; once it is [_autoAt] of the way (opening) or
  /// that far from open (closing) it goes on by itself.
  void _follow(double dy) {
    _open.value = (_open.value + dy / _span).clamp(0.0, 1.0);
    if (_from == 0 && _open.value >= _autoAt) {
      _tracking = false;
      _glide(1);
    } else if (_from == 1 && _open.value <= 1 - _autoAt) {
      _tracking = false;
      _glide(0);
    }
  }

  void _onDown(PointerDownEvent e) {
    _fingers++;
    _lastDy = 0;
  }

  void _onMove(PointerMoveEvent e) {
    if (!_canOpen || _leaving) return;
    final dy = e.delta.dy;
    if (dy != 0) _lastDy = dy;
    if (_tracking) {
      _follow(dy);
      return;
    }
    if (_open.isAnimating) return;
    if (_open.value == 0) {
      // Closed: a pull down at the top starts opening it (not on an island
      // iPhone, where the avatar's neck takes the pull first).
      if (dy > 0 && _atTop && !_island(context)) {
        _begin(0);
        _follow(dy);
      }
    } else if (_open.value == 1 && dy < 0) {
      // Open: a pull up starts closing it.
      _begin(1);
      _follow(dy);
    }
  }

  void _onEnd(PointerEvent _) {
    if (_fingers > 0) _fingers--;
    if (!_tracking) return;
    _tracking = false;
    // It stopped short of the point where it goes on by itself: it goes back,
    // unless the finger was flicking the way it was heading.
    final flick = _lastDy.abs() > _flick;
    final toward = _from == 0 ? _lastDy > 0 : _lastDy < 0;
    _glide(flick && toward ? 1 - _from : _from);
  }

  /// On an island iPhone: the neck of the avatar snapped. The photo opens the
  /// moment it does, with a smooth ease (it used to jump open in 180 ms).
  void _letGo() {
    if (!_canOpen || _open.value > 0 || _open.isAnimating || _leaving) return;
    _glide(1);
  }

  @override
  Widget build(BuildContext context) {
    final island = _island(context);
    return Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onEnd,
      onPointerCancel: _onEnd,
      child: AnimatedBuilder(
        animation: _open,
        builder: (context, _) {
          final t = _open.value;
          final list = ListView(
            controller: _scroll,
            // Open (or half open) the finger belongs to the photo. Closed, an
            // island iPhone bounces (the neck stretches), others just stop.
            physics: t > 0
                ? const NeverScrollableScrollPhysics()
                : island
                ? const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  )
                : const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              widget.top * (1 - t),
              16,
              widget.bottomPadding,
            ),
            children: [_header(context, t, island), ...widget.children],
          );
          if (!island) return list;
          final photo = widget.sources.isEmpty ? null : widget.sources.first;
          return IslandPullAvatar(
            name: widget.name,
            photoUrl: photo?.url,
            photoHeaders: photo?.headers ?? const {},
            active: true,
            background: const Color(0xFFF2F2F7),
            hidden: t > 0 || _leaving,
            onLetGo: _letGo,
            child: list,
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, double t, bool island) {
    final sw = MediaQuery.sizeOf(context).width;
    final full = sw * PullPhotoList.openRatio;
    final rest = _size + widget.gap + widget.blockHeight;
    final height = rest + (full - rest) * t;
    final w = _size + (sw - _size) * t;
    final h = _size + (full - _size) * t;
    final radius = (_size / 2) * (1 - t);
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The photo: round at rest, opening to the full width at the top.
          // On an island iPhone the round one is the island's own (drawn over
          // the page), so only the open one is drawn here.
          if (!island || t > 0 || _leaving)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              // A fixed height: without it the box below is asked to be as
              // tall as it likes and fails with an infinite size.
              height: h,
              child: OverflowBox(
                minWidth: 0,
                maxWidth: sw,
                minHeight: h,
                maxHeight: h,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: w,
                  height: h,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: _photo(sw, full, t),
                  ),
                ),
              ),
            ),
          // Name, status, buttons: under the round photo, over the foot of the
          // open one - always at the bottom of the header, so they travel down
          // with it.
          Positioned(
            left: 0,
            right: 0,
            bottom: 16 * t,
            height: widget.blockHeight,
            child: widget.blockBuilder(context, t),
          ),
        ],
      ),
    );
  }

  Widget _photo(double sw, double full, double t) {
    final small = PersonAvatar(
      name: widget.name,
      size: _size,
      sources: widget.sources,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        // The small photo, grown: it is on the screen the moment the pull
        // starts, and the sharp one fades in over it.
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(width: _size, height: _size, child: small),
        ),
        if (t > 0 && widget.sources.isNotEmpty)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: sw,
              height: full,
              child: FallbackNetworkImage(
                sources: widget.sources,
                width: sw,
                height: full,
                placeholder: () => const SizedBox.shrink(),
              ),
            ),
          ),
        // So that white text reads on any photo.
        if (t > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: t,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x66000000),
                        Color(0x00000000),
                        Color(0x00000000),
                        Color(0xAA000000),
                      ],
                      stops: [0, 0.22, 0.55, 1],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
