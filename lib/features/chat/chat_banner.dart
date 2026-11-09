import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_strings.dart';
import '../../core/widgets/ui_blocks.dart';
import 'chat_hub.dart';
import 'chat_notify_settings.dart';
import 'chat_media_widgets.dart' show chatPreviewIcon, chatPreviewText;
import 'chat_widgets.dart' show IconText;
import 'chat_push.dart' show ChatPushTarget;

/// The in-app notification, as in Telegram: a message from another chat slides
/// down from the top of ANY screen of the app, shows who wrote and what, goes
/// away by itself or by a swipe up, and a tap opens that chat.
///
/// It is drawn by the app (no server push): the hub hands over every message
/// that came while its chat is not on the screen.
class ChatBanners {
  ChatBanners({
    required this.hub,
    required this.contextOf,
    this.duration = const Duration(seconds: 4),
  });

  final ChatHub hub;

  /// A context under the app's Navigator (null: nothing is shown).
  final BuildContext? Function() contextOf;
  final Duration duration;

  StreamSubscription<ChatIncoming>? _sub;
  OverlayEntry? _entry;
  Timer? _timer;
  String _albumShown = '';

  void start() {
    _sub = hub.incoming.listen(_show);
  }

  void _show(ChatIncoming incoming) {
    final context = contextOf();
    if (context == null || !context.mounted) return;
    final overlay = Navigator.maybeOf(context, rootNavigator: true)?.overlay;
    if (overlay == null) return;
    final m = incoming.message;

    // Photos sent together are one banner, not one for each.
    if (m.albumId.isNotEmpty) {
      if (_entry != null && _albumShown == m.albumId) return;
    }

    _remove();
    _albumShown = m.albumId;
    final c = incoming.conversation;
    final s = S.of(context);
    final title = c.isGroup ? c.peer.name : c.peer.surnameName;
    final body = chatPreviewText(m, s);
    final bodyIcon = chatPreviewIcon(m);
    var bodyPrefix = '';
    if (c.isGroup && m.senderName.isNotEmpty) {
      final who = m.senderName.trim().split(RegExp(r'\s+')).take(2).join(' ');
      bodyPrefix = '$who: ';
    }
    final target = ChatPushTarget(c.id, c.peer, isGroup: c.isGroup);

    // Inside the chat window the hub already plays the sound.
    // The sound and the vibration follow the settings (see ChatSounds).
    if (!hub.isChatOpen) hub.sounds?.incoming();
    // "In-App Preview" off: no banner, only the sound.
    if (!ChatNotifySettings.instance.inAppPreview) return;
    final entry = OverlayEntry(
      builder: (_) => _BannerView(
        title: title,
        body: body,
        bodyIcon: bodyIcon,
        bodyPrefix: bodyPrefix,
        photo: c.peer.photo,
        name: c.peer.name,
        onTap: () {
          _remove();
          hub.requestOpen(target);
        },
        onDismiss: _remove,
        onHold: () => _timer?.cancel(),
        onRelease: _arm,
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(duration, _remove);
  }

  void _remove() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
    _albumShown = '';
  }

  void dispose() {
    _sub?.cancel();
    _remove();
  }
}

class _BannerView extends StatefulWidget {
  const _BannerView({
    required this.title,
    required this.body,
    this.bodyIcon,
    this.bodyPrefix = '',
    required this.photo,
    required this.name,
    required this.onTap,
    required this.onDismiss,
    required this.onHold,
    required this.onRelease,
  });

  final String title;
  final String body;
  final IconData? bodyIcon;
  final String bodyPrefix;
  final String? photo;
  final String name;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final VoidCallback onHold;
  final VoidCallback onRelease;

  @override
  State<_BannerView> createState() => _BannerViewState();
}

class _BannerViewState extends State<_BannerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();
  late final Animation<double> _curve = CurvedAnimation(
    parent: _in,
    curve: Curves.easeOutCubic,
  );

  /// Dragged up by the finger, in pixels (<= 0).
  double _drag = 0;

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (_curve.value - 1) * (top + 110) + _drag),
          child: Opacity(opacity: _curve.value.clamp(0.0, 1.0), child: child),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onVerticalDragStart: (_) => widget.onHold(),
          onVerticalDragUpdate: (d) =>
              setState(() => _drag = (_drag + d.delta.dy).clamp(-200.0, 12.0)),
          onVerticalDragEnd: (d) {
            if (_drag < -24 || (d.primaryVelocity ?? 0) < -300) {
              widget.onDismiss();
            } else {
              setState(() => _drag = 0);
              widget.onRelease();
            }
          },
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, top + 6, 10, 0),
            child: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: (dark ? const Color(0xFF1C1C1E) : Colors.white)
                            .withValues(alpha: dark ? 0.88 : 0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (dark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          PersonAvatar(
                            name: widget.name,
                            size: 42,
                            sources: widget.photo == null
                                ? const []
                                : [PhotoSource(widget.photo!)],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: dark ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                IconText(
                                  widget.body,
                                  icon: widget.bodyIcon,
                                  prefix: widget.bodyPrefix,
                                  maxLines: 2,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.25,
                                    color: dark
                                        ? Colors.white70
                                        : const Color(0xFF3C3C43),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
