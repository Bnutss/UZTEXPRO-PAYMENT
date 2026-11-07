import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'chat_api.dart' show ChatPageResult;
import 'chat_models.dart';
import 'chat_voice.dart';
import 'chat_widgets.dart';

/// What a profile's voice list needs from the chat it belongs to.
class VoiceFeed {
  const VoiceFeed({
    required this.load,
    required this.authorOf,
    required this.canDeleteForAll,
    required this.delete,
    required this.goTo,
  });

  /// A page of voice messages, oldest first; [beforeId] loads older ones.
  final Future<ChatPageResult> Function(int? beforeId) load;
  final String Function(ChatMessage message) authorOf;
  final bool Function(ChatMessage message) canDeleteForAll;
  final Future<bool> Function(ChatMessage message, {required bool forAll})
  delete;

  /// Closes the profile and scrolls the chat to the message.
  final void Function(ChatMessage message) goTo;
}

enum _VoiceAction { goTo, deleteForMe, deleteForAll }

/// The "Voice" tab of a profile: every voice message of the chat, newest
/// first, as in Telegram. A tap plays it (the player bar on top shows it), a
/// long press offers "Go to message" and "Delete".
class ProfileVoiceList extends StatefulWidget {
  const ProfileVoiceList({super.key, required this.feed});

  final VoiceFeed feed;

  @override
  State<ProfileVoiceList> createState() => _ProfileVoiceListState();
}

class _ProfileVoiceListState extends State<ProfileVoiceList> {
  final List<ChatMessage> _items = []; // newest first
  bool _loading = true;
  bool _hasMore = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
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
        // The page is oldest first; the list shows newest first.
        _items.addAll(page.messages.reversed);
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

  Future<void> _onMenu(ChatMessage m, _VoiceAction? action) async {
    switch (action) {
      case _VoiceAction.goTo:
        widget.feed.goTo(m);
      case _VoiceAction.deleteForMe:
      case _VoiceAction.deleteForAll:
        final ok = await widget.feed.delete(
          m,
          forAll: action == _VoiceAction.deleteForAll,
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
      AdaptivePopupMenuItem<_VoiceAction>(
        label: s.chatGoToMessage,
        icon: ios26 ? 'arrow.turn.up.left' : Icons.chat_bubble_outline_rounded,
        value: _VoiceAction.goTo,
      ),
      AdaptivePopupMenuItem<_VoiceAction>(
        label: s.chatMenuDelete,
        icon: ios26 ? 'trash' : Icons.delete_outline_rounded,
        isDestructive: true,
        children: [
          AdaptivePopupMenuItem<_VoiceAction>(
            label: s.chatMenuDeleteForMe,
            icon: ios26 ? 'person' : Icons.person_outline_rounded,
            isDestructive: true,
            value: _VoiceAction.deleteForMe,
          ),
          if (widget.feed.canDeleteForAll(m))
            AdaptivePopupMenuItem<_VoiceAction>(
              label: s.chatMenuDeleteForAll,
              icon: ios26 ? 'person.2' : Icons.people_outline_rounded,
              isDestructive: true,
              value: _VoiceAction.deleteForAll,
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
                    _failed ? s.chatLoadError : s.chatNoVoice,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: kChatMuted),
                  ),
                ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 68, color: Color(0xFFE5E5EA)),
            _VoiceRow(
              message: _items[i],
              author: widget.feed.authorOf(_items[i]),
              menu: _menu(_items[i], s),
              onMenu: (a) => _onMenu(_items[i], a),
            ),
          ],
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
      ),
    );
  }
}

class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    required this.message,
    required this.author,
    required this.menu,
    required this.onMenu,
  });

  final ChatMessage message;
  final String author;
  final List<AdaptivePopupMenuEntry> menu;
  final void Function(_VoiceAction? action) onMenu;

  static String _date(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year % 100}, '
        '${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final player = ChatVoicePlayer.instance;
    final m = message;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final current = player.isCurrent(m);
        final playing = current && player.playing;
        final progress = current && m.durationMs > 0
            ? (player.position.inMilliseconds / m.durationMs).clamp(0.0, 1.0)
            : 0.0;
        // The whole row is the menu's trigger: a long press opens the menu, a
        // tap plays (the menu button takes every touch of its child).
        return AdaptivePopupMenuButton.widget<_VoiceAction>(
          items: menu,
          triggerOnLongPress: true,
          onTap: () {
            HapticFeedback.selectionClick();
            player.toggle(m);
          },
          onSelected: (_, entry) => onMenu(entry.value),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.brandOrange,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: kChatInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_date(m.createdAt)} · '
                        '${formatVoiceTime(current && player.position > Duration.zero ? player.position.inMilliseconds : m.durationMs)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: kChatMuted,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (progress > 0) ...[
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 3,
                            backgroundColor: AppColors.brandOrange.withValues(
                              alpha: 0.2,
                            ),
                            color: AppColors.brandOrange,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
