import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// One action of a chat in the list: in the swipe panel and in the native
/// long-press menu.
class ChatListAction {
  const ChatListAction({
    required this.icon,
    required this.label,
    required this.shortLabel,
    required this.onTap,
    this.sfSymbol = '',
    this.color = const Color(0xFF3478F6),
    this.destructive = false,
  });

  final IconData icon;

  /// The same icon as an SF Symbol (the native menu of iOS 26).
  final String sfSymbol;

  /// In the long-press menu.
  final String label;

  /// Under the icon in the swipe panel.
  final String shortLabel;
  final VoidCallback onTap;

  /// The colour of the swipe button.
  final Color color;

  /// Red in the menu.
  final bool destructive;
}

// ── Swipe to reveal actions ─────────────────────────────────────────────

/// A row that slides to the left and shows action buttons, as in Telegram: the
/// buttons are revealed by a drag, the row stays open until it is tapped or
/// another row is opened, and a long drag to the far end runs the last action.
class ChatSwipeRow extends StatefulWidget {
  const ChatSwipeRow({
    super.key,
    required this.id,
    required this.open,
    required this.actions,
    required this.child,
    this.background = AppColors.groupedBackground,
  });

  final int id;

  /// Which row is open now (only one at a time).
  final ValueNotifier<int?> open;

  /// The last one is the "full swipe" action (delete / leave).
  final List<ChatListAction> actions;
  final Widget child;
  final Color background;

  @override
  State<ChatSwipeRow> createState() => _ChatSwipeRowState();
}

class _ChatSwipeRowState extends State<ChatSwipeRow>
    with SingleTickerProviderStateMixin {
  static const _buttonWidth = 78.0;

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  /// Offset of the row: 0 closed, negative open.
  double _dx = 0;
  double _from = 0;
  double _to = 0;
  bool _dragging = false;
  bool _armed = false;

  double get _panel => _buttonWidth * widget.actions.length;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      final t = Curves.easeOutCubic.transform(_anim.value);
      setState(() => _dx = _from + (_to - _from) * t);
    });
    widget.open.addListener(_onOpenChanged);
  }

  @override
  void dispose() {
    widget.open.removeListener(_onOpenChanged);
    _anim.dispose();
    super.dispose();
  }

  void _onOpenChanged() {
    // Another row was opened: this one closes.
    if (widget.open.value != widget.id && _dx != 0 && !_dragging) _settle(0);
  }

  void _settle(double to) {
    _from = _dx;
    _to = to;
    _anim.forward(from: 0);
  }

  void _close() {
    if (widget.open.value == widget.id) widget.open.value = null;
    _settle(0);
  }

  void _start(DragStartDetails d) {
    _anim.stop();
    _dragging = true;
    _armed = false;
    // Opening this one closes any other.
    if (widget.open.value != widget.id) widget.open.value = widget.id;
  }

  void _update(DragUpdateDetails d) {
    final width = context.size?.width ?? 400;
    // Past the panel it still follows, up to the far end (the full swipe).
    final next = (_dx + d.delta.dx).clamp(-width * 0.9, 0.0);
    final armed = next < -width * 0.55;
    if (armed && !_armed) HapticFeedback.mediumImpact();
    setState(() {
      _dx = next;
      _armed = armed;
    });
  }

  void _end(DragEndDetails d) {
    _dragging = false;
    final v = d.primaryVelocity ?? 0;
    if (_armed) {
      // The full swipe: the last action, and the row slides back.
      final action = widget.actions.last;
      _close();
      action.onTap();
      return;
    }
    final open = _dx < -_panel * 0.45 || v < -500;
    if (open && v < 500) {
      HapticFeedback.selectionClick();
      widget.open.value = widget.id;
      _settle(-_panel);
    } else {
      _close();
    }
  }

  void _runAction(ChatListAction a) {
    _close();
    a.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final revealed = -_dx;
    final isOpen = _dx < -1;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _start,
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      child: ClipRect(
        child: Stack(
          children: [
            // The buttons: they take the room the row leaves, and stretch
            // while the row is dragged past them.
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: revealed.clamp(0.0, double.infinity),
                  child: Row(
                    children: [
                      for (var i = 0; i < widget.actions.length; i++)
                        Expanded(
                          child: _SwipeButton(
                            action: widget.actions[i],
                            onTap: () => _runAction(widget.actions[i]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(_dx, 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // An open row only closes when tapped.
                onTap: isOpen ? _close : null,
                child: ColoredBox(
                  color: widget.background,
                  child: IgnorePointer(ignoring: isOpen, child: widget.child),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeButton extends StatelessWidget {
  const _SwipeButton({required this.action, required this.onTap});

  final ChatListAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: action.color,
        alignment: Alignment.center,
        child: OverflowBox(
          maxWidth: 90,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, color: Colors.white, size: 26),
              const SizedBox(height: 3),
              Text(
                action.shortLabel,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Long press: the native preview of a chat ────────────────────────────

/// Shows the native preview (iOS): the chat's last messages in a card that
/// scrolls, and the menu of [actions] under it. It is a silent look: nothing on
/// the card opens the chat (and nothing is marked read); a tap on an action runs it. Returns false where there is no
/// native preview (the caller shows a menu instead).
Future<bool> showNativeChatPreview({
  required Map<String, dynamic> preview,
  required List<ChatListAction> actions,
}) async {
  if (!Platform.isIOS) return false;
  try {
    final res = await const MethodChannel('uztexpro/native_sheet')
        .invokeMapMethod<String, dynamic>('chatPreview', {
          'preview': preview,
          'actions': [
            for (final a in actions)
              {
                'label': a.label,
                'symbol': a.sfSymbol,
                'destructive': a.destructive,
              },
          ],
        });
    if (res == null) return true; // closed
    final i = (res['index'] as num?)?.toInt();
    if (i != null && i >= 0 && i < actions.length) actions[i].onTap();
    return true;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}
