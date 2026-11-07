import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'chat_api.dart';
import 'chat_media.dart';
import 'chat_models.dart';
import 'chat_voice.dart' show formatVoiceTime;
import 'chat_widgets.dart';

/// What a profile's "Media" grid needs from the chat it belongs to.
class MediaFeed {
  const MediaFeed({
    required this.load,
    required this.canDeleteForAll,
    required this.delete,
    required this.goTo,
    required this.open,
    required this.api,
  });

  /// A page of photos and videos, oldest first; [beforeId] loads older ones.
  final Future<ChatPageResult> Function(int? beforeId) load;
  final bool Function(ChatMessage message) canDeleteForAll;
  final Future<bool> Function(ChatMessage message, {required bool forAll})
  delete;

  /// Closes the profile and scrolls the chat to the message.
  final void Function(ChatMessage message) goTo;

  /// Opens the photo / video (fetching it first when it is not on the phone).
  final Future<void> Function(ChatMessage message) open;
  final ChatRest api;
}

enum _MediaAction { goTo, deleteForMe, deleteForAll }

/// The "Media" tab of a profile: every photo and video of the chat in a grid,
/// newest first, as in Telegram. A tap opens it, a long press offers "Go to
/// message" and "Delete".
class ProfileMediaGrid extends StatefulWidget {
  const ProfileMediaGrid({super.key, required this.feed});

  final MediaFeed feed;

  @override
  State<ProfileMediaGrid> createState() => _ProfileMediaGridState();
}

class _ProfileMediaGridState extends State<ProfileMediaGrid> {
  final List<ChatMessage> _items = []; // newest first
  bool _loading = true;
  bool _hasMore = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    ChatMediaStore.init().then((_) {
      if (mounted) setState(() {});
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final before = _items.isEmpty ? null : _items.last.id;
      final page = await widget.feed.load(before);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.messages.reversed.where((m) => m.isMedia));
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _onMenu(ChatMessage m, _MediaAction? action) async {
    switch (action) {
      case _MediaAction.goTo:
        widget.feed.goTo(m);
      case _MediaAction.deleteForMe:
      case _MediaAction.deleteForAll:
        final ok = await widget.feed.delete(
          m,
          forAll: action == _MediaAction.deleteForAll,
        );
        if (ok && mounted) {
          setState(() => _items.removeWhere((x) => x.id == m.id));
        }
      case null:
        break;
    }
  }

  List<AdaptivePopupMenuEntry> _menu(ChatMessage m, S s) {
    final ios26 = PlatformInfo.isIOS26OrHigher();
    return [
      AdaptivePopupMenuItem<_MediaAction>(
        label: s.chatGoToMessage,
        icon: ios26 ? 'arrow.turn.up.left' : Icons.chat_bubble_outline_rounded,
        value: _MediaAction.goTo,
      ),
      AdaptivePopupMenuItem<_MediaAction>(
        label: s.chatMenuDelete,
        icon: ios26 ? 'trash' : Icons.delete_outline_rounded,
        isDestructive: true,
        children: [
          AdaptivePopupMenuItem<_MediaAction>(
            label: s.chatMenuDeleteForMe,
            icon: ios26 ? 'person' : Icons.person_outline_rounded,
            isDestructive: true,
            value: _MediaAction.deleteForMe,
          ),
          if (widget.feed.canDeleteForAll(m))
            AdaptivePopupMenuItem<_MediaAction>(
              label: s.chatMenuDeleteForAll,
              icon: ios26 ? 'person.2' : Icons.people_outline_rounded,
              isDestructive: true,
              value: _MediaAction.deleteForAll,
            ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : GestureDetector(
                  onTap: _failed ? _load : null,
                  child: Text(
                    _failed ? s.chatLoadError : s.chatNoMedia,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: kChatMuted),
                  ),
                ),
        ),
      );
    }
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: _items.length,
            itemBuilder: (context, i) {
              final m = _items[i];
              // The tile is the menu's trigger: a long press opens the menu, a
              // tap opens the picture (the menu button takes every touch).
              return AdaptivePopupMenuButton.widget<_MediaAction>(
                items: _menu(m, s),
                triggerOnLongPress: true,
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.feed.open(m);
                },
                onSelected: (_, entry) => _onMenu(m, entry.value),
                child: _Tile(message: m),
              );
            },
          ),
        ),
        if (_hasMore)
          InkWell(
            onTap: _loading ? null : _load,
            child: SizedBox(
              height: 48,
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        s.chatShowMore,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.brandOrange,
                        ),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final media = m.media!;
    return ListenableBuilder(
      listenable: ChatMediaManager.instance,
      builder: (context, _) {
        final file = ChatMediaStore.fileOf(m);
        final hasFile = file != null && file.existsSync();
        final thumb = ChatMediaStore.thumbOf(m);
        final hasThumb = thumb != null && thumb.existsSync();
        final progress = ChatMediaManager.instance.progressOf(m);
        final Widget picture;
        if (m.isImage && hasFile) {
          picture = Image.file(file, fit: BoxFit.cover, cacheWidth: 400);
        } else if (hasThumb) {
          picture = Image.file(thumb, fit: BoxFit.cover);
        } else if (media.thumbUrl != null && media.thumbUrl!.isNotEmpty) {
          picture = CachedNetworkImage(
            imageUrl: media.thumbUrl!,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => const _Blank(),
          );
        } else {
          picture = const _Blank();
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            picture,
            if (m.isVideo) ...[
              const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              Positioned(
                left: 5,
                bottom: 4,
                child: Text(
                  formatVoiceTime(media.durationMs),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                ),
              ),
            ],
            if (progress != null)
              Container(
                color: Colors.black38,
                alignment: Alignment.center,
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    value: progress <= 0.01 ? null : progress,
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Blank extends StatelessWidget {
  const _Blank();

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFE5E5EA),
    alignment: Alignment.center,
    child: const Icon(Icons.image_rounded, color: Colors.white, size: 28),
  );
}
