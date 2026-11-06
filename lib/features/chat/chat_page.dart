import 'dart:async';
import 'dart:io' show Platform;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_refresh.dart';
import '../../core/widgets/fading_header_scaffold.dart';
import '../../core/widgets/floating_notch_bar.dart';
import '../auth/widgets/logo_stroke_loader.dart';
import 'chat_api.dart';
import 'chat_hub.dart';
import 'chat_models.dart';
import 'chat_push.dart' show ChatPushTarget;
import 'chat_socket.dart';
import 'chat_thread_page.dart';
import 'chat_widgets.dart';

/// Messenger window opened from the home toolbar. Two tabs at the bottom, like
/// Telegram: Contacts and Chats (same native tab bar as the main screen).
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.hub, this.openThread});

  /// The session's chat: the connection and the unread count live outside this
  /// window, so closing it does not drop the socket.
  final ChatHub hub;

  /// A conversation to open at once (the user tapped a notification).
  final ChatPushTarget? openThread;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  ChatRest get _api => widget.hub.api;
  ChatLink get _link => widget.hub.link;

  // Tabs: 0 = contacts, 1 = chats (opens on chats).
  int _index = 1;

  @override
  void initState() {
    super.initState();
    // The window shows the real numbers itself; the badge of the chat button
    // waits (and is refreshed on closing).
    widget.hub.chatOpen = true;
    widget.hub.unread.addListener(_onUnread);
    final target = widget.openThread;
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ChatThreadPage(
              api: _api,
              link: _link,
              peer: target.peer,
              conversationId: target.conversationId,
              sounds: widget.hub.sounds,
              onRead: widget.hub.requestRefresh,
            ),
          ),
        );
      });
    }
  }

  /// The total of unread messages changed: the badge on the Chats tab.
  void _onUnread() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.hub.unread.removeListener(_onUnread);
    widget.hub.chatOpen = false;
    super.dispose();
  }

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: AdaptiveScaffold(
        minimizeBehavior: TabBarMinimizeBehavior.never,
        useFixedToolbar: false,
        body: IndexedStack(
          index: _index,
          children: [
            _ContactsTab(api: _api, link: _link, hub: widget.hub),
            _ChatsTab(api: _api, link: _link, hub: widget.hub),
          ],
        ),
        bottomNavigationBar: AdaptiveBottomNavigationBar(
          items: [
            AdaptiveNavigationDestination(
              icon: 'person.crop.circle.fill',
              label: s.contactsTitle,
            ),
            AdaptiveNavigationDestination(
              // Telegram's chats icon (Assets.xcassets/TgChats).
              icon: 'TgChats',
              label: s.chatTitle,
              // The total of unread messages, on the tab (native badge).
              badgeCount: widget.hub.unread.value > 0
                  ? widget.hub.unread.value
                  : null,
            ),
          ],
          selectedIndex: _index,
          onTap: _select,
          useNativeBottomBar: true,
          selectedItemColor: AppColors.brandOrange,
          unselectedItemColor: null,
          bottomNavigationBar: Platform.isIOS
              ? null
              : FloatingNotchBar(
                  selected: _index,
                  onSelected: _select,
                  items: [
                    NotchBarItem(
                      CupertinoIcons.person_crop_circle,
                      CupertinoIcons.person_crop_circle_fill,
                      s.contactsTitle,
                    ),
                    NotchBarItem(
                      Icons.forum_outlined,
                      Icons.forum_rounded,
                      s.chatTitle,
                      badge: widget.hub.unread.value,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Shared list scaffolding ─────────────────────────────────────────────

/// What to tell the user when a load failed: 403 means the chat group was
/// taken away (the app may still hold an old login), anything else is a
/// network / server problem.
String _errorText(Object e, S s) => e is ChatApiException && e.statusCode == 403
    ? s.chatNoAccess
    : s.chatLoadError;

/// Scrollable body of a tab: the loader, an error, an empty hint or the list
/// card, under the floating header and above the tab bar.
class _TabBody extends StatelessWidget {
  const _TabBody({
    required this.topInset,
    required this.onRefresh,
    required this.loading,
    required this.error,
    required this.emptyIcon,
    required this.emptyText,
    required this.rows,
    this.plain = false,
  });

  final double topInset;
  final Future<void> Function() onRefresh;
  final bool loading;
  final String? error;
  final IconData emptyIcon;
  final String emptyText;
  final List<Widget> rows;

  /// Rows straight on the page (no white card), edge to edge.
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (loading && rows.isEmpty) {
      content = const Padding(
        padding: EdgeInsets.only(top: 64),
        child: Center(child: LogoStrokeLoader(size: 80)),
      );
    } else if (error != null && rows.isEmpty) {
      content = ChatMessageBlock(
        icon: Icons.cloud_off_rounded,
        text: error!,
        color: const Color(0xFFD32F2F),
      );
    } else if (rows.isEmpty) {
      content = ChatMessageBlock(icon: emptyIcon, text: emptyText);
    } else {
      content = ChatListCard(plain: plain, children: rows);
    }

    return AppRefresh(
      topOffset: topInset,
      onRefresh: onRefresh,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        // Bottom space: the tab bar floats over the page.
        padding: EdgeInsets.fromLTRB(
          plain ? 0 : 16,
          topInset + 4,
          plain ? 0 : 16,
          110,
        ),
        children: [content],
      ),
    );
  }
}

// ─── Contacts ────────────────────────────────────────────────────────────

class _ContactsTab extends StatefulWidget {
  const _ContactsTab({
    required this.api,
    required this.link,
    required this.hub,
  });

  final ChatRest api;
  final ChatLink link;
  final ChatHub hub;

  @override
  State<_ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<_ContactsTab> {
  final _search = TextEditingController();
  Timer? _debounce;
  bool _searching = false;

  List<ChatUser> _users = [];
  bool _loading = true;
  String? _error;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), _load);
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _search.clear();
    });
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await widget.api.contacts(search: _search.text);
      if (!mounted || seq != _seq) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = _errorText(e, S.of(context));
        _loading = false;
      });
    }
  }

  /// Goes to the conversation at once; the chat is opened on the server inside
  /// the screen, so a slow network never delays the tap.
  void _open(ChatUser user) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatThreadPage(
          api: widget.api,
          link: widget.link,
          peer: user,
          sounds: widget.hub.sounds,
          onRead: widget.hub.requestRefresh,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return FadingHeaderScaffold(
      title: s.contactsTitle,
      background: AppColors.groupedBackground,
      searching: _searching,
      onToggleSearch: _toggleSearch,
      searchController: _search,
      searchHint: s.contactsSearchHint,
      body: (context, topInset) => _TabBody(
        topInset: topInset,
        onRefresh: _load,
        loading: _loading,
        error: _error,
        emptyIcon: Icons.people_outline_rounded,
        emptyText: _search.text.trim().isEmpty
            ? s.contactsEmpty
            : s.chatNothingFound,
        plain: true,
        rows: [
          for (final u in _users)
            ChatRow(user: u, subtitle: u.subtitle, onTap: () => _open(u)),
        ],
      ),
    );
  }
}

// ─── Chats ───────────────────────────────────────────────────────────────

class _ChatsTab extends StatefulWidget {
  const _ChatsTab({required this.api, required this.link, required this.hub});

  final ChatRest api;
  final ChatLink link;
  final ChatHub hub;

  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<_ChatsTab> {
  final _search = TextEditingController();
  bool _searching = false;

  List<ChatConversation> _chats = [];
  bool _loading = true;
  String? _error;

  StreamSubscription<ChatEvent>? _events;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _events = widget.link.events.listen(_onEvent);
    _wasConnected = widget.link.connected.value;
    widget.link.connected.addListener(_onConnection);
    _load();
  }

  @override
  void dispose() {
    _events?.cancel();
    widget.link.connected.removeListener(_onConnection);
    _search.dispose();
    super.dispose();
  }

  bool _wasConnected = false;

  /// The socket is back: what arrived meanwhile is only on the server.
  void _onConnection() {
    final now = widget.link.connected.value;
    final returned = now && !_wasConnected;
    _wasConnected = now;
    if (returned && !_loading) _load(silent: true);
  }

  /// A new message: the chat jumps to the top with it, and the unread counter
  /// grows when it is from the other person. A chat not in the list yet (the
  /// first message) is picked up by a reload.
  void _onEvent(ChatEvent e) {
    if (e.type != 'message') return;
    final m = ChatMessage.fromJson(e.data);
    final i = _chats.indexWhere((c) => c.id == m.conversation);
    if (i < 0) {
      _load(silent: true);
      return;
    }
    final c = _chats[i];
    final incoming = m.sender == c.peer.id;
    setState(() {
      _chats = [
        c.copyWith(
          lastMessage: m,
          unread: incoming ? c.unread + 1 : c.unread,
          updatedAt: m.createdAt,
        ),
        ..._chats.where((x) => x.id != c.id),
      ];
    });
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _search.clear();
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final chats = await widget.api.conversations();
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // A silent refresh that fails keeps what is on the screen.
      if (silent && _chats.isNotEmpty) return;
      setState(() {
        _error = _errorText(e, S.of(context));
        _loading = false;
      });
    }
  }

  Future<void> _open(ChatConversation chat) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatThreadPage(
          api: widget.api,
          link: widget.link,
          peer: chat.peer,
          conversationId: chat.id,
          sounds: widget.hub.sounds,
          onRead: widget.hub.requestRefresh,
        ),
      ),
    );
    // Back from the conversation: unread counts and the last line changed.
    if (mounted) _load();
  }

  String _preview(ChatConversation c, S s) {
    final m = c.lastMessage;
    if (m == null) return '';
    // A chat of two people: anything not from the peer is mine.
    final mine = m.sender != c.peer.id;
    return mine ? '${s.chatYou}: ${m.text}' : m.text;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final q = _search.text.trim().toLowerCase();
    final shown = q.isEmpty
        ? _chats
        : _chats
              .where(
                (c) =>
                    c.peer.name.toLowerCase().contains(q) ||
                    (c.lastMessage?.text.toLowerCase().contains(q) ?? false),
              )
              .toList();

    return FadingHeaderScaffold(
      title: s.chatTitle,
      background: AppColors.groupedBackground,
      searching: _searching,
      onToggleSearch: _toggleSearch,
      searchController: _search,
      searchHint: s.chatsSearchHint,
      body: (context, topInset) => _TabBody(
        topInset: topInset,
        onRefresh: _load,
        loading: _loading,
        error: _error,
        emptyIcon: Icons.forum_outlined,
        emptyText: q.isEmpty ? s.chatsEmpty : s.chatNothingFound,
        plain: true,
        rows: [
          for (final c in shown)
            ChatRow(
              user: c.peer,
              subtitle: _preview(c, s),
              time: chatTimeLabel(c.lastMessage?.createdAt ?? c.updatedAt, s),
              unread: c.unread,
              onTap: () => _open(c),
            ),
        ],
      ),
    );
  }
}
