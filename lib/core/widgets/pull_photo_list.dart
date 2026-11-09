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
/// top of the screen; the name, the status and the buttons go down with it and
/// end up over its foot, in white. Let go past the half and it stays open; drag
/// up and it closes.
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

  /// How far a finger has to travel before the photo opens (or closes) by
  /// itself: a short pull, and it goes the rest of the way at once.
  static const double _trigger = 10;
  static const _openTime = Duration(milliseconds: 180);

  /// What the finger has travelled in the current direction.
  double _travelled = 0;

  double get _size => IslandPullAvatar.avatarSize;
  bool get _canOpen => widget.sources.isNotEmpty;
  bool get _atTop => !_scroll.hasClients || _scroll.offset <= 0.5;

  @override
  void dispose() {
    _scroll.dispose();
    _open.dispose();
    super.dispose();
  }

  /// On an island iPhone a pull first stretches the avatar's neck (see
  /// [IslandPullAvatar]); only letting go of the island opens the photo.
  bool _island(BuildContext context) => IslandPullAvatar.supported(context);

  void _go(double to) {
    HapticFeedback.mediumImpact();
    _travelled = 0;
    _open.animateTo(to, duration: _openTime, curve: Curves.easeOutCubic);
  }

  void _onMove(PointerMoveEvent e) {
    if (!_canOpen || _open.isAnimating) return;
    final dy = e.delta.dy;
    final island = _island(context);
    if (_open.value == 0) {
      // Closed: a pull down at the top opens it (not on an island iPhone,
      // where the avatar's neck takes the pull first).
      if (dy > 0 && _atTop && !island) {
        _travelled += dy;
        if (_travelled >= _trigger) _go(1);
      } else {
        _travelled = 0;
      }
    } else if (_open.value == 1) {
      // Open: a pull up closes it.
      if (dy < 0) {
        _travelled += -dy;
        if (_travelled >= _trigger) _go(0);
      } else {
        _travelled = 0;
      }
    }
  }

  void _onEnd(PointerEvent _) => _travelled = 0;

  void _letGo() {
    if (!_canOpen || _open.value > 0 || _open.isAnimating) return;
    _go(1);
  }

  @override
  Widget build(BuildContext context) {
    final island = _island(context);
    return Listener(
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
            hidden: t > 0,
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
          if (!island || t > 0)
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
