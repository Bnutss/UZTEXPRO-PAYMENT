import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fading_header_scaffold.dart';
import 'chat_api.dart';
import 'chat_forward.dart';
import 'chat_models.dart';
import 'chat_widgets.dart';

/// "Forward": the chats and the people to send a message to, with a round
/// check on each (several can be picked) and a button at the bottom. Pops with
/// the picked [ForwardTarget]s (null when closed).
class ChatForwardPage extends StatefulWidget {
  const ChatForwardPage({super.key, required this.api});

  final ChatRest api;

  @override
  State<ChatForwardPage> createState() => _ChatForwardPageState();
}

class _ChatForwardPageState extends State<ChatForwardPage> {
  final _search = TextEditingController();
  bool _searching = false;
  List<ChatConversation> _chats = [];
  List<ChatUser> _people = [];
  bool _loading = true;
  bool _failed = false;

  /// What is picked, in the order it was picked.
  final Map<String, ForwardTarget> _picked = {};

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final results = await Future.wait([
        widget.api.conversations(),
        widget.api.contacts(),
      ]);
      if (!mounted) return;
      setState(() {
        _chats = results[0] as List<ChatConversation>;
        _people = results[1] as List<ChatUser>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _toggle(ForwardTarget t) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_picked.remove(t.key) == null) _picked[t.key] = t;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final q = _search.text.trim().toLowerCase();

    final chats = [
      for (final c in _chats)
        if (q.isEmpty || c.peer.name.toLowerCase().contains(q)) c,
    ];
    // People one has no personal chat with yet.
    final haveChat = {
      for (final c in _chats)
        if (!c.isGroup) c.peer.id,
    };
    final people = [
      for (final u in _people)
        if (!haveChat.contains(u.id) &&
            (q.isEmpty || u.name.toLowerCase().contains(q)))
          u,
    ];

    Widget row(ForwardTarget t, String subtitle) => ChatRow(
      user: t.peer,
      subtitle: subtitle,
      selected: _picked.containsKey(t.key),
      onTap: () => _toggle(t),
    );

    Widget section(String title, List<Widget> rows) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: kChatMuted,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
        ),
        ChatListCard(children: rows),
        const SizedBox(height: 16),
      ],
    );

    return FadingHeaderScaffold(
      title: s.forwardTitle,
      background: AppColors.groupedBackground,
      searching: _searching,
      onToggleSearch: () => setState(() {
        _searching = !_searching;
        if (!_searching) _search.clear();
      }),
      searchController: _search,
      searchHint: s.forwardSearch,
      body: (context, topInset) => Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_failed)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.chatLoadError, style: const TextStyle(color: kChatMuted)),
                  TextButton(onPressed: _load, child: Text(s.devicesRetry)),
                ],
              ),
            )
          else
            ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                topInset + 8,
                16,
                // Room for the button at the bottom.
                MediaQuery.paddingOf(context).bottom + 96,
              ),
              children: [
                if (chats.isNotEmpty)
                  section(s.forwardChats, [
                    for (final c in chats)
                      row(
                        ForwardTarget.chat(c),
                        c.isGroup
                            ? s.chatMembersCount(c.membersCount)
                            : c.peer.position,
                      ),
                  ]),
                if (people.isNotEmpty)
                  section(s.forwardContacts, [
                    for (final u in people)
                      row(ForwardTarget.person(u), u.position),
                  ]),
              ],
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 12,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: _picked.isEmpty
                  ? const SizedBox.shrink()
                  : SizedBox(
                      key: const ValueKey('send'),
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () =>
                            Navigator.pop(context, _picked.values.toList()),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandOrange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          s.forwardSendTo(_picked.length),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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
