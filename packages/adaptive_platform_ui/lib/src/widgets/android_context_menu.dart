import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

import 'ios26/ios26_popup_menu_button.dart';

/// The Android long-press menu, in the manner of Telegram: the pressed widget
/// (a chat message) is lifted over a dimmed, blurred screen, and a rounded card
/// with icons and labels opens next to it. Returns the index (in [items]) of
/// the chosen entry, or null when it was dismissed.
///
/// [boundaryKey] must sit on a `RepaintBoundary` around the pressed widget: its
/// picture is what is lifted. Without it only the card is shown.
Future<int?> showAndroidContextMenu({
  required BuildContext context,
  required GlobalKey boundaryKey,
  required List<AdaptivePopupMenuEntry> items,
  bool lift = true,
}) async {
  Rect? rect;
  ui.Image? image;
  try {
    final box = boundaryKey.currentContext?.findRenderObject();
    if (box is RenderRepaintBoundary && box.hasSize) {
      rect = box.localToGlobal(Offset.zero) & box.size;
      if (lift) {
        image = await box.toImage(
          pixelRatio: MediaQuery.devicePixelRatioOf(context),
        );
      }
    }
  } catch (_) {
    rect = null;
    image = null;
  }
  if (!context.mounted) return null;
  HapticFeedback.mediumImpact();
  final chosen = await Navigator.of(context, rootNavigator: true).push<int>(
    PageRouteBuilder<int>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, _) => _MenuLayer(
        animation: animation,
        anchor: rect,
        image: image,
        items: items,
      ),
    ),
  );
  image?.dispose();
  return chosen;
}

class _MenuLayer extends StatelessWidget {
  const _MenuLayer({
    required this.animation,
    required this.anchor,
    required this.image,
    required this.items,
  });

  final Animation<double> animation;
  final Rect? anchor;
  final ui.Image? image;
  final List<AdaptivePopupMenuEntry> items;

  static const _menuWidth = 244.0;
  static const _rowHeight = 50.0;
  static const _gap = 8.0;

  double get _menuHeight {
    var h = 12.0; // vertical padding
    for (var i = 0; i < items.length; i++) {
      h += items[i] is AdaptivePopupMenuItem ? _rowHeight : 9;
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    final menuH = _menuHeight;
    final topLimit = pad.top + 8;
    final bottomLimit = size.height - pad.bottom - 8;

    // Where the lifted message and the card go: the message stays where it
    // is when it can, and the card is under it (or above, near the bottom).
    final a = anchor;
    var msgTop = a?.top ?? 0;
    final msgH = a == null ? 0.0 : math.min(a.height, size.height * 0.45);
    var menuTop = msgTop + msgH + (a == null ? 0 : _gap);
    var above = false;
    if (a == null) {
      menuTop = (size.height - menuH) / 2;
    } else if (menuTop + menuH > bottomLimit) {
      final over = msgTop - _gap - menuH;
      if (over >= topLimit) {
        menuTop = over;
        above = true;
      } else {
        menuTop = bottomLimit - menuH;
        msgTop = math.max(topLimit, menuTop - _gap - msgH);
      }
    }
    final right = a == null ? false : a.center.dx > size.width / 2;
    final menuLeft = a == null
        ? (size.width - _menuWidth) / 2
        : (right ? a.right - _menuWidth : a.left).clamp(
            12.0,
            size.width - _menuWidth - 12,
          );

    return Stack(
      children: [
        // Dim + blur; a tap anywhere outside the card dismisses.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: AnimatedBuilder(
              animation: curved,
              builder: (context, _) => BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: 7 * curved.value,
                  sigmaY: 7 * curved.value,
                ),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.28 * curved.value),
                ),
              ),
            ),
          ),
        ),
        if (a != null && image != null)
          Positioned(
            left: a.left,
            top: msgTop,
            width: a.width,
            height: msgH,
            child: IgnorePointer(
              child: ScaleTransition(
                scale: Tween<double>(begin: 1, end: 1.025).animate(curved),
                child: RawImage(
                  image: image,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
          ),
        Positioned(
          left: menuLeft,
          top: menuTop,
          width: _menuWidth,
          child: FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.82, end: 1).animate(curved),
              alignment: Alignment(right ? 1 : -1, above ? 1 : -1),
              child: _MenuCard(dark: dark, items: items),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.dark, required this.items});

  final bool dark;
  final List<AdaptivePopupMenuEntry> items;

  @override
  Widget build(BuildContext context) {
    final ink = dark ? Colors.white : const Color(0xFF111111);
    final red = dark ? const Color(0xFFFF6B6B) : const Color(0xFFD93025);
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ColoredBox(
            color: dark ? const Color(0xFF242426) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < items.length; i++)
                    if (items[i] is AdaptivePopupMenuItem)
                      _Row(
                        item: items[i] as AdaptivePopupMenuItem,
                        color: (items[i] as AdaptivePopupMenuItem).isDestructive
                            ? red
                            : ink,
                        onTap: () => Navigator.of(context).pop(i),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: ink.withValues(alpha: 0.08),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.color, required this.onTap});

  final AdaptivePopupMenuItem item;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = item.icon;
    return Semantics(
      button: true,
      enabled: item.enabled,
      label: item.label,
      child: InkWell(
        onTap: item.enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap();
              }
            : null,
        child: Opacity(
          opacity: item.enabled ? 1 : 0.4,
          child: SizedBox(
            height: _MenuLayer._rowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w400,
                        color: color,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  if (icon is IconData) ...[
                    const SizedBox(width: 14),
                    Icon(icon, size: 22, color: color.withValues(alpha: 0.85)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
