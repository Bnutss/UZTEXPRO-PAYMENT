import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui_blocks.dart';
import 'chat_models.dart';
import 'chat_spellcheck.dart';
import 'chat_voice.dart';
import 'chat_voice_widgets.dart';
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

/// A frosted-glass capsule made with Flutter (blur + translucent white), for
/// the input: a native glass button there buzzed at every touch and swallowed
/// the touches of the text field, while this one is silent and passive.
Widget _frosted({
  required double width,
  required double height,
  required Widget child,
  VoidCallback? onTap,
}) {
  final radius = BorderRadius.circular(math.min(height / 2, _slot / 2 + 2));
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(borderRadius: radius),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: radius,
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// The frosted capsule for other chat widgets (the voice player on top).
Widget chatFrosted({
  required double width,
  required double height,
  required Widget child,
}) => _frosted(width: width, height: height, child: child);

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
  // The package's child button fills all the width it is given (its child sits
  // in a Center inside a Stack), so the size is pinned from outside.
  return SizedBox(
    width: width,
    height: height,
    child: AdaptiveButton.child(
      onPressed: onTap ?? () {},
      color: kChatInk,
      style: AdaptiveButtonStyle.glass,
      size: AdaptiveButtonSize.medium,
      useSmoothRectangleBorder: height > _slot + 1,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(radius),
      minSize: Size(width, height),
      child: SizedBox(width: width, height: height, child: child),
    ),
  );
}

/// The name of the person, centered in the header. [status] (typing…,
/// connecting…) appears under it only while there is one.
class ChatNameCapsule extends StatelessWidget {
  const ChatNameCapsule({
    super.key,
    required this.name,
    this.status,
    this.onTap,
    this.muted = false,
  });

  /// Notifications are off: a small crossed bell after the name.
  final bool muted;

  final VoidCallback? onTap;
  final String name;
  final String? status;

  static const _nameStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: kChatInk,
    height: 1.15,
  );
  static const _statusStyle = TextStyle(
    fontSize: 11.5,
    color: AppColors.brandOrange,
    height: 1.15,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final maxW = math.min(
          box.maxWidth.isFinite ? box.maxWidth : 170.0,
          170.0,
        );
        final text = math.max(
          _textWidth(context, name, _nameStyle) + (muted ? 19 : 0),
          status == null ? 0.0 : _textWidth(context, status!, _statusStyle),
        );
        final width = math.min(maxW, math.max(80.0, text + 32));
        return _glass(
          width: width,
          height: _slot,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _nameStyle,
                      ),
                    ),
                    if (muted) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.notifications_off_rounded,
                        size: 15,
                        color: kChatMuted,
                      ),
                    ],
                  ],
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
  const ChatAvatarButton({super.key, required this.user, this.onTap});

  final VoidCallback? onTap;

  final ChatUser user;

  @override
  Widget build(BuildContext context) {
    return _glass(
      width: _slot,
      height: _slot,
      onTap: onTap,
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
    this.editTitle,
    this.editText,
    this.editIcon,
    this.onCancelEdit,
    this.onVoice,
    this.onAttach,
  });

  /// The paperclip: pick a photo, video or file. Null: no such button.
  final VoidCallback? onAttach;

  /// A voice message was recorded (hold the microphone): send it. Null: no
  /// microphone in this input.
  final void Function(VoiceClip clip)? onVoice;

  /// Editing a message: a strip with the old text sits on top of the field,
  /// inside the same capsule (as in Telegram).
  final String? editTitle;
  final String? editText;

  /// An icon before [editText] (the kind of message being answered).
  final IconData? editIcon;
  final VoidCallback? onCancelEdit;

  final TextEditingController controller;
  final String hint;
  final bool canSend;
  final VoidCallback onSend;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _focus = FocusNode();
  final _rec = ChatVoiceRecorder();

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
  void initState() {
    super.initState();
    _rec.onAutoStop = (clip) => widget.onVoice?.call(clip);
  }

  @override
  void didUpdateWidget(ChatInputBar old) {
    super.didUpdateWidget(old);
    // Editing starts: the keyboard comes up on the text being edited.
    if (old.editTitle == null && widget.editTitle != null) {
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _rec.dispose();
    super.dispose();
  }

  void _hint(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
      );
  }

  /// Height of the strip with the old text (editing only).
  static const _editStrip = 44.0;
  bool get _editing => widget.editTitle != null;

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
            listenable: Listenable.merge([widget.controller, _rec]),
            builder: (context, _) {
              final recording = _rec.active;
              // The microphone always stands to the right of the field; the
              // send arrow always stays inside it.
              final mic = widget.onVoice != null && !_editing;
              // The paperclip stands left of the field (a round glass button,
              // as the microphone on the right); not while recording.
              final attach = widget.onAttach != null && !_editing && !recording;
              final capW =
                  width - (mic ? _slot + 8 : 0.0) - (attach ? _slot + 8 : 0.0);
              final h =
                  _heightFor(context, capW - _leftPad - _rightPad) +
                  (_editing ? _editStrip : 0);
              // The send button is a SIBLING of the glass in this Stack, not
              // its content: the package draws the content of a glass button
              // under IgnorePointer, and a native view there is never
              // registered for touches (the tap hangs and never arrives).
              return SizedBox(
                width: width,
                height: h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      left: attach ? _slot + 8 : 0,
                      top: 0,
                      bottom: 0,
                      width: capW,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: _frosted(
                              width: capW,
                              height: h,
                              onTap: _focus.requestFocus,
                              child: recording
                                  ? VoiceRecordingStrip(
                                      recorder: _rec,
                                      rightPad: 14,
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.only(
                                        left: _leftPad,
                                        right: _rightPad,
                                      ),
                                      child: Column(
                                        children: [
                                          if (_editing)
                                            SizedBox(
                                              height: _editStrip,
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8,
                                                  right: 30,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 3,
                                                      height: 30,
                                                      decoration: BoxDecoration(
                                                        color: AppColors
                                                            .brandOrange,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              2,
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            widget.editTitle!,
                                                            maxLines: 1,
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: AppColors
                                                                  .brandOrange,
                                                              height: 1.2,
                                                            ),
                                                          ),
                                                          IconText(
                                                            widget.editText ??
                                                                '',
                                                            icon:
                                                                widget.editIcon,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 14,
                                                                  color:
                                                                      kChatInk,
                                                                  height: 1.2,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                          // The text field is a SIBLING above the glass, not its content:
                          // inside the glass button it sat under IgnorePointer, so it
                          // got no long press, selection or paste, and a tap went to
                          // the native button (which buzzes). Here it is a real iOS
                          // text field: caret, selection, paste menu, and the system
                          // spell check with its red dotted underline.
                          if (!recording)
                            Positioned(
                              left: 0,
                              right: _rightPad,
                              top: _editing ? _editStrip : 0,
                              bottom: 0,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TextField(
                                  controller: widget.controller,
                                  focusNode: _focus,
                                  minLines: 1,
                                  maxLines: _maxLines,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  keyboardType: TextInputType.multiline,
                                  autocorrect: true,
                                  enableSuggestions: true,
                                  spellCheckConfiguration: chatSpellCheck(),
                                  style: _style,
                                  cursorColor: AppColors.brandOrange,
                                  decoration: InputDecoration(
                                    hintText: widget.hint,
                                    hintStyle: _style.copyWith(
                                      color: kChatMuted,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.only(
                                      left: _leftPad,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Cancel: a sibling of the glass too (its own content gets
                          // no touches).
                          if (_editing)
                            Positioned(
                              right: 10,
                              top: 8,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: widget.onCancelEdit,
                                child: const SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                    color: kChatMuted,
                                  ),
                                ),
                              ),
                            ),
                          if (!recording)
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
                    ),
                    if (attach)
                      Positioned(
                        left: 0,
                        bottom: 0,
                        child: _frosted(
                          width: _slot,
                          height: _slot,
                          onTap: widget.onAttach,
                          child: const Icon(
                            Icons.attach_file_rounded,
                            size: 24,
                            color: kChatInk,
                          ),
                        ),
                      ),
                    // The microphone is a round glass button of its own, to the
                    // right of the field (as in Telegram); typing takes it away and
                    // the field spreads over the whole width.
                    if (mic)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: SizedBox(
                          width: _slot,
                          height: _slot,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _frosted(
                                width: _slot,
                                height: _slot,
                                child: const SizedBox.shrink(),
                              ),
                              Positioned.fill(
                                child: VoiceMicButton(
                                  recorder: _rec,
                                  size: _slot,
                                  onClip: widget.onVoice!,
                                  onDenied: () =>
                                      _hint(S.of(context).chatMicDenied),
                                  onTooShort: () =>
                                      _hint(S.of(context).chatHoldToRecord),
                                ),
                              ),
                            ],
                          ),
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
