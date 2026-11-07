import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import 'chat_media.dart';
import 'chat_models.dart';
import 'chat_voice.dart' show formatVoiceTime;
import 'chat_widgets.dart';

/// One line describing a message, for the chat list and for quotes.
String chatPreviewText(ChatMessage m, S s) {
  if (m.isVoice) return '🎤 ${s.chatVoiceMessage}';
  if (m.isImage) {
    return '📷 ${m.text.trim().isEmpty ? s.chatPhoto : m.text.trim()}';
  }
  if (m.isVideo) {
    return '🎥 ${m.text.trim().isEmpty ? s.chatVideo : m.text.trim()}';
  }
  if (m.isFile) {
    return '📎 ${m.text.trim().isNotEmpty ? m.text.trim() : (m.media?.name ?? '')}';
  }
  return m.text;
}

/// The same for the quote of an answer (it carries the kind and the text).
String chatReplyText(ChatReply r, S s) {
  switch (r.kind) {
    case 'voice':
      return '🎤 ${s.chatVoiceMessage}';
    case 'image':
      return '📷 ${r.text.trim().isEmpty ? s.chatPhoto : r.text.trim()}';
    case 'video':
      return '🎥 ${r.text.trim().isEmpty ? s.chatVideo : r.text.trim()}';
    case 'file':
      return '📎 ${r.text.trim().isEmpty ? s.chatAttachFile : r.text.trim()}';
  }
  return r.text;
}

/// The photo / video / document inside a bubble. A tap on it is handled by the
/// bubble (the menu button around it takes the touches): see `_openMedia`.
class MediaBubbleBody extends StatelessWidget {
  const MediaBubbleBody({
    super.key,
    required this.message,
    required this.accent,
    required this.metaOf,
    required this.maxWidth,
  });

  final ChatMessage message;
  final Color accent;

  /// Time and ticks, in the given colour (white on a picture).
  final Widget Function(Color color) metaOf;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final m = message;
    return ListenableBuilder(
      listenable: ChatMediaManager.instance,
      builder: (context, _) => m.isFile
          ? _FileBody(
              message: m,
              accent: accent,
              meta: metaOf(kChatMuted),
              width: maxWidth,
            )
          : _PictureBody(
              message: m,
              meta: metaOf(Colors.white),
              maxWidth: maxWidth,
            ),
    );
  }
}

class _PictureBody extends StatelessWidget {
  const _PictureBody({
    required this.message,
    required this.maxWidth,
    this.meta,
    this.fixed,
    this.radius = 16,
  });

  final ChatMessage message;

  /// Time and ticks on the picture; null inside an album (it has one).
  final Widget? meta;
  final double maxWidth;

  /// A tile of an album: the size is given, not worked out from the picture.
  final Size? fixed;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final m = message;
    final media = m.media!;
    final manager = ChatMediaManager.instance;
    final progress = manager.progressOf(m);
    final file = ChatMediaStore.fileOf(m);
    final has = file != null && file.existsSync();
    final localThumb = ChatMediaStore.thumbOf(m);
    final hasThumb = localThumb != null && localThumb.existsSync();

    // The size follows the picture's shape, within sane bounds.
    final aspect = media.aspect.clamp(0.62, 1.7);
    final w = fixed?.width ?? math.min(maxWidth, 270.0);
    final h = fixed?.height ?? (w / aspect).clamp(110.0, 340.0);

    Widget picture;
    if (m.isImage && has) {
      picture = Image.file(file, fit: BoxFit.cover, cacheWidth: 800);
    } else if (hasThumb) {
      picture = Image.file(localThumb, fit: BoxFit.cover);
    } else if (media.thumbUrl != null && media.thumbUrl!.isNotEmpty) {
      picture = CachedNetworkImage(
        imageUrl: media.thumbUrl!,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => const _PicturePlaceholder(),
      );
    } else {
      picture = const _PicturePlaceholder();
    }

    final gone = manager.isGone(m);
    final failed = manager.hasFailed(m);
    final uploading = m.isLocal && progress != null;
    Widget? center;
    String? chip; // top-left
    if (progress != null) {
      center = _RingButton(progress: progress);
      chip = '${(progress * 100).round()}%';
    } else if (m.isVideo) {
      if (has || m.isLocal) {
        center = const _RoundIcon(icon: Icons.play_arrow_rounded);
        chip = formatVoiceTime(media.durationMs);
      } else if (gone) {
        center = const _RoundIcon(icon: Icons.cloud_off_rounded);
        chip = s.chatFileGone;
      } else {
        center = _RoundIcon(
          icon: failed ? Icons.refresh_rounded : Icons.arrow_downward_rounded,
        );
        chip =
            '${formatVoiceTime(media.durationMs)} · '
            '${formatFileSize(media.size)}';
      }
    } else if (!has && !m.isLocal) {
      // A photo that is not on the phone (yet).
      if (gone) {
        center = const _RoundIcon(icon: Icons.cloud_off_rounded);
        chip = s.chatFileGone;
      } else if (failed) {
        center = const _RoundIcon(icon: Icons.refresh_rounded);
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            picture,
            if (uploading) Container(color: Colors.black26),
            if (center != null) Center(child: center),
            if (chip != null)
              Positioned(left: 8, top: 8, child: _Chip(text: chip)),
            if (meta != null)
              Positioned(right: 8, bottom: 8, child: _MetaPill(child: meta!)),
          ],
        ),
      ),
    );
  }
}

class _PicturePlaceholder extends StatelessWidget {
  const _PicturePlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFE5E5EA),
    alignment: Alignment.center,
    child: const Icon(Icons.image_rounded, color: Colors.white, size: 40),
  );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.5),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: Colors.white, size: 32),
  );
}

/// A download / upload in progress: a ring around the percent.
class _RingButton extends StatelessWidget {
  const _RingButton({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.5),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            value: progress <= 0.01 ? null : progress,
            strokeWidth: 3,
            color: Colors.white,
            backgroundColor: Colors.white24,
          ),
        ),
        // A tap on the ring stops the upload / download.
        const Icon(Icons.close_rounded, color: Colors.white, size: 18),
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}

/// The time and ticks on the picture, on a dark pill.
class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(10),
    ),
    // The time and the ticks are drawn in white here.
    child: IconTheme(
      data: const IconThemeData(color: Colors.white),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 12),
        child: child,
      ),
    ),
  );
}

class _FileBody extends StatelessWidget {
  const _FileBody({
    required this.message,
    required this.accent,
    required this.meta,
    required this.width,
  });

  final ChatMessage message;
  final Color accent;
  final Widget meta;
  final double width;

  static IconData _icon(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'xls':
      case 'xlsx':
      case 'csv':
      case 'ods':
        return Icons.table_chart_rounded;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final m = message;
    final media = m.media!;
    final manager = ChatMediaManager.instance;
    final progress = manager.progressOf(m);
    final has = ChatMediaStore.has(m);
    final gone = manager.isGone(m);
    final failed = manager.hasFailed(m);

    final String sub;
    if (progress != null) {
      sub = '${(progress * 100).round()}% · ${formatFileSize(media.size)}';
    } else if (gone) {
      sub = s.chatFileGone;
    } else if (failed) {
      sub = s.chatDownloadFailed;
    } else {
      sub = formatFileSize(media.size);
    }
    final IconData icon = progress != null
        ? Icons.close_rounded
        : (!has && !m.isLocal && !gone)
        ? Icons.arrow_downward_rounded
        : _icon(media.name);

    return SizedBox(
      width: math.min(width, 270),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: gone ? kChatMuted : accent,
              shape: BoxShape.circle,
            ),
            child: progress != null
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 38,
                        height: 38,
                        child: CircularProgressIndicator(
                          value: progress <= 0.01 ? null : progress,
                          strokeWidth: 3,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  )
                : Icon(
                    gone ? Icons.cloud_off_rounded : icon,
                    color: Colors.white,
                    size: 26,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  media.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kChatInk,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: failed ? const Color(0xFFD32F2F) : kChatMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    meta,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// How the tiles of an album lie in a square-ish block (Telegram's rows).
class AlbumLayout {
  AlbumLayout._();

  static const double gap = 2;

  /// Tiles per row for [n] pictures.
  static List<int> rows(int n) {
    switch (n) {
      case 2:
        return [2];
      case 3:
        return [1, 2];
      case 4:
        return [2, 2];
      case 5:
        return [2, 3];
      case 6:
        return [3, 3];
      case 7:
        return [2, 2, 3];
      case 8:
        return [3, 3, 2];
      case 9:
        return [3, 3, 3];
      default:
        return [2, 3, 2, 3];
    }
  }

  /// The rectangle of every tile in a block [width] wide.
  static List<Rect> rects(double width, int n) {
    final out = <Rect>[];
    var y = 0.0;
    for (final k in rows(n)) {
      final h = k == 1 ? width * 0.62 : (width - gap * (k - 1)) / k * 0.92;
      final w = (width - gap * (k - 1)) / k;
      for (var i = 0; i < k && out.length < n; i++) {
        out.add(Rect.fromLTWH(i * (w + gap), y, w, h));
      }
      y += h + gap;
    }
    return out;
  }

  static double height(double width, int n) {
    final r = rects(width, n);
    return r.isEmpty ? 0 : r.last.bottom;
  }

  /// Which tile a point (in the block's own coordinates) falls on.
  static int? tileAt(double width, int n, Offset p) {
    final r = rects(width, n);
    for (var i = 0; i < r.length; i++) {
      if (r[i].inflate(gap / 2).contains(p)) return i;
    }
    return null;
  }
}

/// Several photos / videos sent together, as one block of tiles. A tap on a
/// tile is worked out by the screen from the touch point (the menu button
/// around the bubble takes the touches): see `AlbumLayout.tileAt`.
class AlbumBody extends StatelessWidget {
  const AlbumBody({
    super.key,
    required this.messages,
    required this.width,
    required this.meta,
  });

  final List<ChatMessage> messages;
  final double width;

  /// Time and ticks, bottom right of the block.
  final Widget meta;

  @override
  Widget build(BuildContext context) {
    final rects = AlbumLayout.rects(width, messages.length);
    return ListenableBuilder(
      listenable: ChatMediaManager.instance,
      builder: (context, _) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: width,
          height: AlbumLayout.height(width, messages.length),
          child: Stack(
            children: [
              for (var i = 0; i < messages.length && i < rects.length; i++)
                Positioned.fromRect(
                  rect: rects[i],
                  child: _PictureBody(
                    message: messages[i],
                    maxWidth: rects[i].width,
                    fixed: rects[i].size,
                    radius: 0,
                  ),
                ),
              Positioned(right: 8, bottom: 8, child: _MetaPill(child: meta)),
            ],
          ),
        ),
      ),
    );
  }
}
