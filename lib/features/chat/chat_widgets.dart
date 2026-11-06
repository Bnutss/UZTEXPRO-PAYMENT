import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui_blocks.dart';
import 'chat_models.dart';

const Color kChatInk = Color(0xFF1C1C1E);
const Color kChatMuted = Color(0xFF8A8A8E);

/// Where the text of a row starts: 16 padding + 48 avatar + 12 gap.
const double kChatTextIndent = 76;

/// "14:05" today, "Yesterday", else "06.11.26" — no weekday names: their
/// locale data would have to be initialised for every language first.
String chatTimeLabel(DateTime t, S s, {DateTime? now}) {
  final n = now ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return '${two(t.hour)}:${two(t.minute)}';
  if (diff == 1) return s.chatYesterday;
  return '${two(t.day)}.${two(t.month)}.${two(t.year % 100)}';
}

/// A flat list of rows with hairlines that start at the text, like the
/// Telegram chat list. By default on a rounded white card; [plain] drops the
/// card: the rows sit straight on the page and only the lines remain (the
/// contacts list).
class ChatListCard extends StatelessWidget {
  const ChatListCard({super.key, required this.children, this.plain = false});

  final List<Widget> children;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final rows = Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            const Divider(
              height: 0.5,
              thickness: 0.5,
              indent: kChatTextIndent,
              color: Color(0x1F000000),
            ),
          children[i],
        ],
      ],
    );
    if (plain) return rows;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: rows,
    );
  }
}

/// One person / chat: avatar, name, a line under it, and (for chats) the time
/// with an unread badge on the right.
class ChatRow extends StatelessWidget {
  const ChatRow({
    super.key,
    required this.user,
    required this.subtitle,
    required this.onTap,
    this.time,
    this.unread = 0,
  });

  final ChatUser user;
  final String subtitle;
  final VoidCallback onTap;
  final String? time;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unread > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
          child: Row(
            children: [
              ClipOval(
                child: PersonAvatar(
                  name: user.name,
                  size: 48,
                  sources: user.photo == null
                      ? const []
                      : [PhotoSource(user.photo!)],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: kChatInk,
                            ),
                          ),
                        ),
                        if (time != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            time!,
                            style: TextStyle(
                              fontSize: 12,
                              color: hasUnread
                                  ? AppColors.brandOrange
                                  : kChatMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: hasUnread ? kChatInk : kChatMuted,
                            ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            height: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.brandOrange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered icon + text for the empty / error / nothing-found states.
class ChatMessageBlock extends StatelessWidget {
  const ChatMessageBlock({
    super.key,
    required this.icon,
    required this.text,
    this.color = kChatMuted,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 56, left: 32, right: 32),
      child: Column(
        children: [
          Icon(icon, size: 54, color: const Color(0xFFC7C7CC)),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

/// Colour of the wallpaper's paper: behind the picture, and while it loads.
const Color kChatWallpaperBase = Color(0xFFE4F3F5);

/// The chat wallpaper: a picture that fills the screen, slightly blurred so
/// that the bubbles and the glass controls stand out from it, and fixed in
/// place when the keyboard opens (the area above it shrinks, the picture does
/// not).
class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key});

  /// How soft the picture is (logical pixels of blur radius).
  static const double blur = 3;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return RepaintBoundary(
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minWidth: size.width,
          maxWidth: size.width,
          minHeight: size.height,
          maxHeight: size.height,
          child: ColoredBox(
            color: kChatWallpaperBase,
            child: ImageFiltered(
              // The edges repeat the border pixels instead of fading out.
              imageFilter: ImageFilter.blur(
                sigmaX: blur,
                sigmaY: blur,
                tileMode: TileMode.clamp,
              ),
              child: Image.asset(
                'assets/images/background.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                width: size.width,
                height: size.height,
                // The file is large: decode it at the size of the screen.
                cacheWidth: math.min(1080, (size.width * dpr).round()),
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A new, empty chat: our chats icon and a line, centred in the free area.
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.78),
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                'assets/icons/tg_chats.svg',
                width: 46,
                height: 46,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF4FA3AD),
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.78),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: kChatInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
