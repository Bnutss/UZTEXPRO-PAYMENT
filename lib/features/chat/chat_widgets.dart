import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui_blocks.dart';
import 'chat_appearance_settings.dart';
import 'chat_models.dart';

/// The "delete" icon, the same in every place of the chat: the system's trash
/// on iOS (as the native menus and the photo viewer draw it), the outlined bin
/// on Android.
final IconData kChatDeleteIcon = Platform.isIOS
    ? CupertinoIcons.trash
    : Icons.delete_outline_rounded;

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

/// A flat list of rows with hairlines that start at the text and stop short of
/// the right edge (16 pt), like the Telegram chat list. By default on a rounded white card; [plain] drops the
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
              endIndent: 16,
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

/// A line of text that may start with a small icon (what kind of attachment a
/// message is), after an optional [prefix] ("You: ").
class IconText extends StatelessWidget {
  const IconText(
    this.text, {
    super.key,
    this.icon,
    this.prefix = '',
    required this.style,
    this.maxLines = 1,
  });

  final String text;
  final IconData? icon;
  final String prefix;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final size = (style.fontSize ?? 14) * 1.15;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (prefix.isNotEmpty) TextSpan(text: prefix),
          if (icon != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Icon(icon, size: size, color: style.color),
              ),
            ),
          TextSpan(text: text),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
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
    this.muted = false,
    this.subtitleColor,
    this.subtitleIcon,
    this.subtitlePrefix = '',
    this.timeIcon,
    this.selected,
  });

  /// Not null: a round check at the right end (a list to pick from, as in
  /// Telegram's "Forward"); true when this row is picked.
  final bool? selected;

  /// Ticks before the time when the last message is mine: one when it is sent,
  /// two when it has been read (as in Telegram's chat list).
  final IconData? timeIcon;

  /// An icon between [subtitlePrefix] and [subtitle] (the kind of the last
  /// message: a photo, a voice message…).
  final IconData? subtitleIcon;
  final String subtitlePrefix;

  /// Colour of the line under the name (the "online" status is accented).
  final Color? subtitleColor;

  /// Notifications of this chat are off: a crossed bell by the name, and a
  /// grey (not orange) unread badge.
  final bool muted;

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
                        if (muted) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.notifications_off_rounded,
                            size: 15,
                            color: kChatMuted,
                          ),
                        ],
                        if (time != null) ...[
                          const SizedBox(width: 8),
                          if (timeIcon != null) ...[
                            Icon(
                              timeIcon,
                              size: 16,
                              color: const Color(0xFF5DAA55),
                            ),
                            const SizedBox(width: 2),
                          ],
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
                          child: IconText(
                            subtitle,
                            icon: subtitleIcon,
                            prefix: subtitlePrefix,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  subtitleColor ??
                                  (hasUnread ? kChatInk : kChatMuted),
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
                              color: muted
                                  ? const Color(0xFFB4B4BA)
                                  : AppColors.brandOrange,
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
              if (selected != null) ...[
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected!
                        ? AppColors.brandOrange
                        : Colors.transparent,
                    border: Border.all(
                      color: selected!
                          ? AppColors.brandOrange
                          : const Color(0xFFC7C7CC),
                      width: 1.5,
                    ),
                  ),
                  child: selected!
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
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
    this.svgAsset,
    this.centered = false,
  });

  final IconData icon;
  final String text;
  final Color color;

  /// Our own icon instead of [icon] (the one of the tab bar).
  final String? svgAsset;

  /// Sits in the middle of the free area: no top offset.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: centered ? 0 : 56, left: 32, right: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (svgAsset != null)
            SvgPicture.asset(
              svgAsset!,
              width: 64,
              height: 64,
              colorFilter: const ColorFilter.mode(
                Color(0xFFC7C7CC),
                BlendMode.srcIn,
              ),
            )
          else
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
const Color kChatWallpaperBase = Color(0xFFFFF1E6);

/// The chat wallpaper: a picture that fills the screen, slightly blurred so
/// that the bubbles and the glass controls stand out from it, and fixed in
/// place when the keyboard opens (the area above it shrinks, the picture does
/// not).
class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = ChatAppearanceSettings.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final plain = settings.effectiveWallpaper.color;
        if (plain != null) return ColoredBox(color: plain);
        return _picture(context, settings);
      },
    );
  }

  Widget _picture(BuildContext context, ChatAppearanceSettings settings) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final file = settings.effectiveWallpaper == ChatWallpaperChoice.custom
        ? settings.customFile
        : null;
    // The file is large: decode it at the size of the screen.
    final decodeWidth = math.min(1080, (size.width * dpr).round());
    final Widget image = file != null
        ? Image.file(
            file,
            key: ValueKey(file.path),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            width: size.width,
            height: size.height,
            cacheWidth: decodeWidth,
            gaplessPlayback: true,
          )
        : Image.asset(
            'assets/images/background.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            width: size.width,
            height: size.height,
            cacheWidth: decodeWidth,
            gaplessPlayback: true,
          );
    return RepaintBoundary(
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minWidth: size.width,
          maxWidth: size.width,
          minHeight: size.height,
          maxHeight: size.height,
          child: ColoredBox(
            color: settings.wallpaperBase,
            child: Stack(
              fit: StackFit.expand,
              children: [
                settings.blur < 0.5
                    ? image
                    : ImageFiltered(
                        // The edges repeat the border pixels instead of fading
                        // out.
                        imageFilter: ImageFilter.blur(
                          sigmaX: settings.blur,
                          sigmaY: settings.blur,
                          tileMode: TileMode.clamp,
                        ),
                        child: image,
                      ),
                if (settings.dim > 0.01)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: settings.dim),
                  ),
              ],
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
