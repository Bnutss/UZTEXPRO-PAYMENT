import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui_blocks.dart';
import 'chat_models.dart';
import 'chat_widgets.dart';

// The conversation screen as in Telegram on iOS 26: the controls sit on native
// Liquid Glass. The package only has glass *buttons*, so the name and the input
// are the content of one, as the search field of the header already is. Other
// platforms get plain white shapes.

const double _slot = 46;

double _textWidth(BuildContext context, String text, TextStyle style) {
  final p = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return p.width;
}

/// A glass capsule / circle of a fixed size holding [child]. A tall one (the
/// input with several lines) gets the system's dynamic corners (a rounded
/// rectangle) instead of the ends turning into huge half circles.
Widget _glass({
  required double width,
  required double height,
  required Widget child,
  VoidCallback? onTap,
}) {
  final radius = math.min(height / 2, _slot / 2);
  if (!Platform.isIOS) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
  return AdaptiveButton.child(
    onPressed: onTap ?? () {},
    color: kChatInk,
    style: AdaptiveButtonStyle.glass,
    size: AdaptiveButtonSize.medium,
    useSmoothRectangleBorder: height > _slot + 1,
    padding: EdgeInsets.zero,
    borderRadius: BorderRadius.circular(radius),
    minSize: Size(width, height),
    child: SizedBox(width: width, height: height, child: child),
  );
}

/// The name of the person, centered in the header. [status] (typing…,
/// connecting…) appears under it only while there is one.
class ChatNameCapsule extends StatelessWidget {
  const ChatNameCapsule({super.key, required this.name, this.status});

  final String name;
  final String? status;

  static const _nameStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: kChatInk,
  );
  static const _statusStyle = TextStyle(fontSize: 12, color: kChatMuted);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final maxW = box.maxWidth.isFinite ? box.maxWidth : 240.0;
        final text = math.max(
          _textWidth(context, name, _nameStyle),
          status == null ? 0.0 : _textWidth(context, status!, _statusStyle),
        );
        final width = math.min(maxW, math.max(96.0, text + 44));
        return _glass(
          width: width,
          height: _slot,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _nameStyle,
                ),
                if (status != null)
                  Text(
                    status!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _statusStyle,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The person's photo in a round glass ring, right of the name.
class ChatAvatarButton extends StatelessWidget {
  const ChatAvatarButton({super.key, required this.user});

  final ChatUser user;

  @override
  Widget build(BuildContext context) {
    return _glass(
      width: _slot,
      height: _slot,
      child: Center(
        child: ClipOval(
          child: PersonAvatar(
            name: user.name,
            size: _slot - 8,
            sources: user.photo == null ? const [] : [PhotoSource(user.photo!)],
          ),
        ),
      ),
    );
  }
}

/// The message field: ONE glass capsule across the width, with the round send
/// button inside it at the bottom right (as in Telegram). It grows with the
/// text, up to six lines, turning from a capsule into a rounded rectangle.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.hint,
    required this.canSend,
    required this.onSend,
  });

  final TextEditingController controller;
  final String hint;
  final bool canSend;
  final VoidCallback onSend;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _focus = FocusNode();

  static const _style = TextStyle(fontSize: 16, color: kChatInk, height: 1.25);
  static const _maxLines = 6;
  static const _vPad = 13.0;
  static const _leftPad = 16.0;

  /// The send button: a flat circle inset 5 from the corner of the capsule.
  static const _button = 36.0;
  static const _inset = 5.0;

  /// Space the text keeps clear on the right for the button.
  static const _rightPad = _button + _inset + 8;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Height of the capsule for the current text.
  double _heightFor(BuildContext context, double textWidth) {
    final p = TextPainter(
      text: TextSpan(
        text: widget.controller.text.isEmpty ? ' ' : widget.controller.text,
        style: _style,
      ),
      maxLines: _maxLines,
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: math.max(40, textWidth));
    return math.max(_slot, p.height + 2 * _vPad);
  }

  @override
  Widget build(BuildContext context) {
    // The body is resized by the keyboard; the home-indicator inset only
    // matters while the keyboard is closed.
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 6, 10, 8 + bottom),
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          return ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final h = _heightFor(context, width - _leftPad - _rightPad);
              // The send button is a SIBLING of the glass in this Stack, not
              // its content: the package draws the content of a glass button
              // under IgnorePointer, and a native view there is never
              // registered for touches (the tap hangs and never arrives).
              return SizedBox(
                width: width,
                height: h,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _glass(
                        width: width,
                        height: h,
                        onTap: _focus.requestFocus,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: _leftPad,
                            right: _rightPad,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextField(
                              controller: widget.controller,
                              focusNode: _focus,
                              minLines: 1,
                              maxLines: _maxLines,
                              textCapitalization: TextCapitalization.sentences,
                              keyboardType: TextInputType.multiline,
                              style: _style,
                              cursorColor: AppColors.brandOrange,
                              decoration: InputDecoration(
                                hintText: widget.hint,
                                hintStyle: _style.copyWith(color: kChatMuted),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: _inset,
                      bottom: _inset,
                      child: _SendButton(
                        size: _button,
                        canSend: widget.canSend,
                        onSend: widget.onSend,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Round send button inside the field: grey while there is nothing to send,
/// orange when there is. The field keeps its focus (and the keyboard) when it
/// is tapped.
///
/// On iOS it is a native button of its own, lying over the glass as a sibling
/// of it (see [ChatInputBar]). The glass capsule is ONE native button and
/// everything inside it is drawn under `IgnorePointer`: a Flutter-drawn button
/// there never gets a tap, and a native one there is never registered for
/// touches either.
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.size,
    required this.canSend,
    required this.onSend,
  });

  final double size;
  final bool canSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return SizedBox(
        width: size,
        height: size,
        child: AdaptiveButton.icon(
          // A new native button for each state: switching the style, the
          // enabled flag and the arrow colour of a living one does not reach
          // all of them, and the button stayed grey and dead after typing.
          key: ValueKey(canSend),
          onPressed: canSend ? onSend : null,
          enabled: canSend,
          icon: Icons.arrow_upward_rounded,
          iconColor: canSend ? Colors.white : kChatMuted,
          color: canSend ? AppColors.brandOrange : const Color(0xFFD1D1D6),
          style: canSend
              ? AdaptiveButtonStyle.filled
              : AdaptiveButtonStyle.gray,
          size: AdaptiveButtonSize.medium,
          useSmoothRectangleBorder: false,
          padding: EdgeInsets.zero,
          minSize: Size(size, size),
        ),
      );
    }
    return GestureDetector(
      onTap: canSend ? onSend : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: canSend ? AppColors.brandOrange : const Color(0xFFD1D1D6),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_upward_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
