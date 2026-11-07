import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_strings.dart';
import '../../core/widgets/routeless_alert.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/adaptive_back_button.dart';
import '../../core/widgets/fading_header_scaffold.dart';
import '../../core/widgets/native_segments.dart';
import '../../core/widgets/ui_blocks.dart';
import 'chat_models.dart';
import 'chat_media_grid.dart';
import 'chat_voice_list.dart';
import 'chat_widgets.dart';

/// The person's card, as in Telegram: a big round photo, the name and the
/// status, action buttons, and a white card with department, position and the
/// phone (only the rows that are filled in).
class ChatProfilePage extends StatefulWidget {
  const ChatProfilePage({
    super.key,
    required this.user,
    required this.listenable,
    required this.statusOf,
    this.canManage = false,
    this.isMuted,
    this.onToggleMute,
    this.onDelete,
    this.onWrite,
    this.showWrite = true,
    this.showManage = true,
    this.voiceFeed,
    this.mediaFeed,
  });

  /// The chat's photos and videos (the "Media" tab); null: nothing to list.
  final MediaFeed? mediaFeed;

  /// The chat's voice messages (the "Voice" tab); null: nothing to list.
  final VoiceFeed? voiceFeed;

  /// "Write": opens the chat with the person. Null: this profile was opened
  /// from that very chat, so it simply goes back to it.
  final VoidCallback? onWrite;
  final bool showWrite;

  /// Sound / delete tiles (a member's card from a group has no such chat).
  final bool showManage;

  final ChatUser user;

  /// Changes when the status does (typing, online, connection).
  final Listenable listenable;
  final String Function() statusOf;

  /// The chat exists on the server, so it can be muted / deleted.
  final bool canManage;
  final bool Function()? isMuted;
  final Future<bool> Function()? onToggleMute;

  /// Deletes the chat: only for me, or for both people. True when done.
  final Future<bool> Function(bool forAll)? onDelete;

  static const _bg = Color(0xFFF2F2F7);
  static const _blue = Color(0xFF3478F6);

  @override
  State<ChatProfilePage> createState() => _ChatProfilePageState();
}

class _ChatProfilePageState extends State<ChatProfilePage> {
  ChatUser get user => widget.user;
  int _tab = 0;

  Future<void> _call() async {
    HapticFeedback.selectionClick();
    final number = user.phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (number.isEmpty) return;
    await launchUrl(Uri(scheme: 'tel', path: number));
  }

  void _write() {
    HapticFeedback.selectionClick();
    final go = widget.onWrite;
    if (go == null) {
      Navigator.of(context).pop();
    } else {
      go();
    }
  }

  Future<void> _toggleMute() async {
    HapticFeedback.selectionClick();
    await widget.onToggleMute?.call();
  }

  /// Native alert: delete for me and the person, or only for me.
  void _confirmDelete(BuildContext context, S s) {
    HapticFeedback.selectionClick();
    showNativeAlert(
      context: context,
      title: s.chatDeleteTitle,
      message: s.chatDeleteMessage,
      actions: [
        AlertAction(
          title: s.chatDeleteForBoth(user.shortName),
          style: AlertActionStyle.destructive,
          onPressed: () => _delete(true),
        ),
        AlertAction(
          title: s.chatDeleteForMe,
          style: AlertActionStyle.destructive,
          onPressed: () => _delete(false),
        ),
        AlertAction(
          title: s.chatCancel,
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
      ],
    );
  }

  Future<void> _delete(bool forAll) async {
    final done = await widget.onDelete?.call(forAll) ?? false;
    if (!mounted || !done) return;
    // Back to the chat list: the profile and the (now empty) chat close.
    final nav = Navigator.of(context);
    nav.pop();
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final hasPhone = user.phone.isNotEmpty;
    final rows = <_Row>[
      if (hasPhone)
        _Row(
          s.attendancePhone,
          user.phone,
          color: ChatProfilePage._blue,
          onTap: _call,
        ),
      if (user.department.isNotEmpty)
        _Row(s.attendanceDepartment, user.department),
      if (user.position.isNotEmpty) _Row(s.attendancePosition, user.position),
    ];

    return Scaffold(
      backgroundColor: ChatProfilePage._bg,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, top + 20, 16, 32),
            children: [
              Center(
                child: ClipOval(
                  child: PersonAvatar(
                    name: user.name,
                    size: 100,
                    sources: user.photo == null
                        ? const []
                        : [PhotoSource(user.photo!)],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                user.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: kChatInk,
                ),
              ),
              const SizedBox(height: 4),
              ListenableBuilder(
                listenable: widget.listenable,
                builder: (context, _) => Text(
                  widget.statusOf(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.brandOrange,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ListenableBuilder(
                listenable: widget.listenable,
                builder: (context, _) {
                  final muted = widget.isMuted?.call() ?? false;
                  return Row(
                    children: [
                      if (widget.showWrite) ...[
                        Expanded(
                          child: _Action(
                            svgIcon: 'assets/icons/tg_chats.svg',
                            label: s.chatWrite,
                            onTap: _write,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (hasPhone) ...[
                        Expanded(
                          child: _Action(
                            icon: Icons.call_rounded,
                            label: s.chatCall,
                            onTap: _call,
                          ),
                        ),
                        if (widget.showManage) const SizedBox(width: 8),
                      ],
                      if (widget.showManage) ...[
                        Expanded(
                          child: _Action(
                            icon: muted
                                ? Icons.notifications_off_rounded
                                : Icons.notifications_rounded,
                            label: muted ? s.chatSoundOff : s.chatSound,
                            enabled: widget.canManage,
                            onTap: _toggleMute,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Action(
                            icon: Icons.delete_outline_rounded,
                            label: s.chatDelete,
                            color: const Color(0xFFFF3B30),
                            enabled: widget.canManage,
                            onTap: () => _confirmDelete(context, s),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              if (rows.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, color: Color(0xFFE5E5EA)),
                        rows[i],
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Center(
                child: NativeSegments(
                  labels: [s.chatMedia, s.chatVoice],
                  selectedIndex: _tab,
                  minSegmentWidth: 110,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              if (_tab == 0 && widget.mediaFeed != null)
                ProfileMediaGrid(
                  key: const ValueKey('media'),
                  feed: widget.mediaFeed!,
                )
              else if (_tab == 1 && widget.voiceFeed != null)
                ProfileVoiceList(
                  key: const ValueKey('voices'),
                  feed: widget.voiceFeed!,
                )
              else
                // The shared media will appear here.
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    s.chatNothingYet,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: kChatMuted),
                  ),
                ),
            ],
          ),
          Positioned(
            top: top,
            left: 0,
            width: 58,
            height: kFadingHeaderRowHeight,
            child: const AdaptiveBackButton(),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    this.icon,
    this.svgIcon,
    required this.label,
    required this.onTap,
    this.color = ChatProfilePage._blue,
    this.enabled = true,
  });

  final IconData? icon;

  /// Our own icon (an svg asset) instead of a material one.
  final String? svgIcon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (svgIcon != null)
                SvgPicture.asset(
                  svgIcon!,
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                )
              else
                Icon(icon, color: color, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.color, this.onTap});

  final String label;
  final String value;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: kChatMuted),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(fontSize: 17, color: color ?? kChatInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
