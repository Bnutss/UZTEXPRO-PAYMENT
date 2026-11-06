import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fading_header_scaffold.dart';
import '../auth/widgets/logo_stroke_loader.dart';
import 'chat_api.dart';
import 'chat_glass.dart';
import 'chat_models.dart';
import 'chat_socket.dart';
import 'chat_sounds.dart';
import 'chat_thread_controller.dart';
import 'chat_widgets.dart';

/// A conversation with one person: messages (live), the input, "typing…".
///
/// It opens at once, also from a contact: the chat is opened on the server in
/// the background, and a message can be sent before that has finished.
class ChatThreadPage extends StatefulWidget {
  const ChatThreadPage({
    super.key,
    required this.api,
    required this.link,
    required this.peer,
    this.conversationId,
    this.sounds,
    this.onRead,
  });

  final ChatRest api;
  final ChatLink link;
  final ChatUser peer;

  /// Known when opened from the chat list; null from the contacts.
  final int? conversationId;

  /// "Message sent" sound.
  final ChatSounds? sounds;

  /// The peer's messages were marked read (the unread total may have changed).
  final VoidCallback? onRead;

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  late final ChatThreadController _c = ChatThreadController(
    rest: widget.api,
    link: widget.link,
    peer: widget.peer,
    conversationId: widget.conversationId,
    onReadMarked: widget.onRead,
  );
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _hasText = false;

  /// The input bar floats over the messages (they scroll under its glass, as
  /// under the header), so the list needs to know how tall the bar is: it grows
  /// with the text.
  final _inputKey = GlobalKey();
  double _inputHeight = 76;

  void _measureInput() {
    final box = _inputKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final h = box.size.height;
    if ((h - _inputHeight).abs() > 0.5 && mounted) {
      setState(() => _inputHeight = h);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureInput());
    _c.start();
    _scroll.addListener(() {
      // Reverse list: the "top" of the history is the max scroll extent.
      if (_scroll.hasClients &&
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        _c.loadMore();
      }
    });
    _input.addListener(() {
      _c.onTextChanged(_input.text);
      final has = _input.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    widget.sounds?.sent();
    _c.send(text);
    _input.clear();
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_c, widget.link.connected]),
      builder: (context, _) {
        // Only the name; a line under it only while something is going on.
        // Without a connection "typing…" is stale, so "Connecting…" wins.
        final String? status = !widget.link.connected.value
            ? s.chatConnecting
            : _c.peerTyping
            ? s.chatTyping
            : null;
        return FadingHeaderScaffold(
          title: widget.peer.name,
          center: ChatNameCapsule(name: widget.peer.name, status: status),
          trailing: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ChatAvatarButton(user: widget.peer),
            ),
          ],
          background: kChatWallpaperBase,
          // The wallpaper shows behind the glass controls: no plate.
          fade: false,
          body: (context, topInset) => Stack(
            children: [
              const Positioned.fill(child: ChatWallpaper()),
              // The messages fill the whole area, down to the screen edge, and
              // scroll under the glass of the header and of the input bar.
              Positioned.fill(child: _buildMessages(s, topInset)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: NotificationListener<SizeChangedLayoutNotification>(
                  onNotification: (_) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _measureInput(),
                    );
                    return false;
                  },
                  child: SizeChangedLayoutNotifier(
                    child: KeyedSubtree(
                      key: _inputKey,
                      child: ChatInputBar(
                        controller: _input,
                        hint: s.chatInputHint,
                        canSend: _hasText,
                        onSend: _send,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessages(S s, double topInset) {
    if (_c.loading && _c.messages.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topInset, bottom: _inputHeight),
        child: const Center(child: LogoStrokeLoader(size: 80)),
      );
    }
    if (_c.historyFailed && _c.messages.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topInset, bottom: _inputHeight),
        child: GestureDetector(
          onTap: _c.reload,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: ChatMessageBlock(
              icon: Icons.cloud_off_rounded,
              text: s.chatLoadError,
              color: const Color(0xFFD32F2F),
            ),
          ),
        ),
      );
    }
    final entries = _entries(_c.messages);
    if (entries.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topInset, bottom: _inputHeight),
        child: ChatEmptyState(text: s.chatNoMessages),
      );
    }
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      // Reverse list: padding.top is the visual top (under the header).
      // Reverse list: padding.bottom is the visual bottom, above the input bar.
      padding: EdgeInsets.fromLTRB(10, topInset + 8, 10, _inputHeight + 8),
      itemCount: entries.length + (_c.loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == entries.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final e = entries[entries.length - 1 - index];
        if (e.day != null) return _DayChip(label: _dayLabel(e.day!, s));
        return _Bubble(
          message: e.message!,
          mine: _c.isMine(e.message!),
          tail: e.lastInRun,
          gapAbove: e.firstInRun,
          onRetry: () => _c.retry(e.message!),
          notSentHint: s.chatNotSent,
        );
      },
    );
  }

  /// Messages (oldest first) with a day chip before the first of each day, and
  /// the runs of one sender marked, so that bubbles can be grouped.
  List<_Entry> _entries(List<ChatMessage> messages) {
    final out = <_Entry>[];
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final prev = i > 0 ? messages[i - 1] : null;
      final next = i + 1 < messages.length ? messages[i + 1] : null;
      final newDay = prev == null || !_sameDay(prev.createdAt, m.createdAt);
      if (newDay) out.add(_Entry.day(m.createdAt));
      final sameRunAsPrev =
          prev != null &&
          _sameDay(prev.createdAt, m.createdAt) &&
          _c.isMine(prev) == _c.isMine(m);
      final sameRunAsNext =
          next != null &&
          _sameDay(m.createdAt, next.createdAt) &&
          _c.isMine(next) == _c.isMine(m);
      out.add(
        _Entry.message(
          m,
          firstInRun: !sameRunAsPrev,
          lastInRun: !sameRunAsNext,
        ),
      );
    }
    return out;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime d, S s) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff == 0) return s.chatToday;
    if (diff == 1) return s.chatYesterday;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }
}

class _Entry {
  _Entry.day(this.day) : message = null, firstInRun = false, lastInRun = false;
  _Entry.message(
    ChatMessage this.message, {
    required this.firstInRun,
    required this.lastInRun,
  }) : day = null;

  final DateTime? day;
  final ChatMessage? message;
  final bool firstInRun;
  final bool lastInRun;
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kChatMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.tail,
    required this.gapAbove,
    required this.onRetry,
    required this.notSentHint,
  });

  final ChatMessage message;
  final bool mine;
  final bool tail;
  final bool gapAbove;
  final VoidCallback onRetry;
  final String notSentHint;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final failed = m.state == ChatSendState.failed;
    final fg = mine ? Colors.white : kChatInk;
    final meta = mine ? Colors.white.withOpacity(0.75) : kChatMuted;
    const big = Radius.circular(18);
    const small = Radius.circular(5);
    final radius = BorderRadius.only(
      topLeft: big,
      topRight: big,
      bottomLeft: (!mine && tail) ? small : big,
      bottomRight: (mine && tail) ? small : big,
    );
    String two(int v) => v.toString().padLeft(2, '0');
    final time = '${two(m.createdAt.hour)}:${two(m.createdAt.minute)}';

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      padding: const EdgeInsets.fromLTRB(12, 7, 10, 6),
      decoration: BoxDecoration(
        color: mine ? AppColors.brandOrange : Colors.white,
        borderRadius: radius,
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 8,
        children: [
          Text(m.text, style: TextStyle(fontSize: 16, height: 1.25, color: fg)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(time, style: TextStyle(fontSize: 11, color: meta)),
              if (mine) ...[
                const SizedBox(width: 3),
                _Status(message: m, color: meta),
              ],
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: gapAbove ? 6 : 1.5),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: failed
                ? GestureDetector(onTap: onRetry, child: bubble)
                : bubble,
          ),
          if (failed)
            GestureDetector(
              onTap: onRetry,
              child: Padding(
                padding: const EdgeInsets.only(top: 2, right: 4),
                child: Text(
                  notSentHint,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFD32F2F),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Clock while sending, one tick sent, two ticks read, red mark when failed.
class _Status extends StatelessWidget {
  const _Status({required this.message, required this.color});

  final ChatMessage message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    var c = color;
    switch (message.state) {
      case ChatSendState.sending:
        icon = Icons.schedule_rounded;
      case ChatSendState.failed:
        icon = Icons.error_rounded;
        c = const Color(0xFFFFD6D2);
      case ChatSendState.sent:
        icon = message.read ? Icons.done_all_rounded : Icons.done_rounded;
    }
    return Icon(icon, size: 15, color: c);
  }
}
