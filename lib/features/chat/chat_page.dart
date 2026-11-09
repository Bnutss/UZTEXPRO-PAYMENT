import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_strings.dart';
import '../../core/widgets/routeless_alert.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_refresh.dart';
import '../../core/widgets/fading_header_scaffold.dart';
import '../../core/widgets/floating_notch_bar.dart';
import '../auth/widgets/logo_stroke_loader.dart';
import '../settings/settings_screen.dart';
import 'chat_api.dart';
import 'chat_group_picker.dart';
import 'chat_hub.dart';
import 'chat_list_actions.dart';
import 'chat_system.dart';
import 'chat_models.dart';
import 'chat_mute_sheet.dart';
import 'chat_my_photo.dart';
import 'chat_media_widgets.dart' show chatPreviewIcon, chatPreviewText;
import 'chat_push.dart' show ChatPushTarget;
import 'chat_socket.dart';
import 'chat_thread_controller.dart' show ChatOpenThreads;
import 'chat_thread_page.dart';
import 'chat_widgets.dart';

/// Messenger window opened from the home toolbar. Three tabs at the bottom, like
/// Telegram: Contacts, Chats and Settings with the user's photo (same native
/// tab bar as the main screen).
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

  // Tabs: 0 = contacts, 1 = chats (opens on chats), 2 = settings.
  int _index = 1;

  /// The user's own photo, the icon of the Settings tab (null: a plain one).
  File? _myPhoto;

  @override
  void initState() {
    super.initState();
    // The window shows the real numbers itself; the badge of the chat button
    // waits (and is refreshed on closing).
    widget.hub.chatOpen = true;
    ChatMyPhoto.load().then((f) {
      if (mounted && f != null) setState(() => _myPhoto = f);
    });
    widget.hub.unread.addListener(_onUnread);
    widget.hub.openRequest.addListener(_onOpenRequest);
    final target = widget.openThread;
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openThread(target));
    }
  }

  /// A tap on an in-app banner while the chat window is open.
  void _onOpenRequest() {
    final target = widget.hub.openRequest.value;
    if (target == null || !mounted) return;
    if (ChatOpenThreads.isOpen(target.conversationId)) return;
    // From inside another conversation: back to the window, then forward.
    final route = ModalRoute.of(context);
    if (route != null) Navigator.of(context).popUntil((r) => r == route);
    _openThread(target);
  }

  Future<void> _openThread(ChatPushTarget target) async {
    // The push carries only the id and the name: the photo, position and the
    // rest of the profile come from the server first.
    final peer = await _fullPeer(target);
    if (!mounted) return;
    Navigator.of(context).push(
      chatInstantRoute(
        (_) => ChatThreadPage(
          api: _api,
          link: _link,
          peer: peer,
          conversationId: target.conversationId,
          sounds: widget.hub.sounds,
          mutedChats: widget.hub.mutedConversations,
          onRead: widget.hub.requestRefresh,
          isGroup: target.isGroup,
        ),
      ),
    );
  }

  /// The whole profile of the person (or the group) a notification is about;
  /// the bare one from the push when the server cannot be reached.
  Future<ChatUser> _fullPeer(ChatPushTarget target) async {
    try {
      final c = target.isGroup
          ? await _api.group(target.conversationId)
          : await _api.openConversation(target.peer.id);
      return c.peer;
    } catch (_) {
      return target.peer;
    }
  }

  /// The total of unread messages changed: the badge on the Chats tab.
  void _onUnread() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.hub.unread.removeListener(_onUnread);
    widget.hub.openRequest.removeListener(_onOpenRequest);
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
            FadingHeaderScaffold(
              // No heading: the profile below is the page.
              title: '',
              centerTitle: true,
              background: AppColors.groupedBackground,
              body: (context, topInset) => SettingsScreen(
                topInset: topInset,
                chatOnly: true,
                islandActive: _index == 2,
                chatApi: widget.hub.api,
              ),
            ),
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
            AdaptiveNavigationDestination(
              // The user's round photo, like Telegram (a person until loaded).
              icon: _myPhoto != null
                  ? FileImage(_myPhoto!)
                  : 'person.crop.circle',
              selectedIcon: _myPhoto != null
                  ? FileImage(_myPhoto!)
                  : 'person.crop.circle.fill',
              label: s.settingsTitle,
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
                      // The same chat bubbles as "Write" in a profile.
                      svgAsset: 'assets/icons/tg_chats.svg',
                    ),
                    NotchBarItem(
                      Icons.settings_outlined,
                      Icons.settings_rounded,
                      s.settingsTitle,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Shared list scaffolding ─────────────────────────────────────────────

/// Telegram-style header: "Connecting…" while the socket is down, "Updating…"
/// while the list is being loaded, otherwise the page's own [title].
String _statusTitle(
  S s, {
  required String title,
  required bool connected,
  required bool updating,
}) => !connected
    ? s.chatConnecting
    : updating
    ? s.chatUpdating
    : title;

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
    this.emptySvg,
    this.plain = false,
  });

  final double topInset;
  final Future<void> Function() onRefresh;
  final bool loading;
  final String? error;
  final IconData emptyIcon;
  final String emptyText;
  final String? emptySvg;
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
        centered: true,
      );
    } else if (rows.isEmpty) {
      content = ChatMessageBlock(
        icon: emptyIcon,
        svgAsset: emptySvg,
        text: emptyText,
        centered: true,
      );
    } else {
      content = ChatListCard(plain: plain, children: rows);
    }

    // A hint or an error sits in the middle of the free area (between the
    // header and the tab bar), not under the header.
    final centered = !(loading && rows.isEmpty) && rows.isEmpty;
    return AppRefresh(
      topOffset: topInset,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, box) {
          const bottom = 110.0; // the tab bar floats over the page
          final free = box.maxHeight - topInset - 4 - bottom;
          return ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              plain ? 0 : 16,
              topInset + 4,
              plain ? 0 : 16,
              bottom,
            ),
            children: [
              if (centered)
                SizedBox(
                  height: free > 0 ? free : 0,
                  child: Center(child: content),
                )
              else
                content,
            ],
          );
        },
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
      chatInstantRoute(
        (_) => ChatThreadPage(
          api: widget.api,
          link: widget.link,
          peer: user,
          sounds: widget.hub.sounds,
          mutedChats: widget.hub.mutedConversations,
          onRead: widget.hub.requestRefresh,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: widget.link.connected,
      builder: (context, connected, _) => _buildScaffold(s, connected),
    );
  }

  Widget _buildScaffold(S s, bool connected) {
    return FadingHeaderScaffold(
      title: _statusTitle(
        s,
        title: s.contactsTitle,
        connected: connected,
        updating: _loading,
      ),
      centerTitle: true,
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
            ChatRow(
              user: u,
              subtitle: u.online ? s.chatOnline : s.chatLastSeen(u.lastSeen),
              subtitleColor: u.online ? AppColors.brandOrange : null,
              onTap: () => _open(u),
            ),
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

  /// The row that is swiped open (one at a time).
  final _openRow = ValueNotifier<int?>(null);

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
    ChatOpenThreads.closed.addListener(_onThreadClosed);
    _load();
  }

  /// A conversation window was closed: take the unread counts again. (After
  /// the frame: the window is being disposed right now.)
  void _onThreadClosed() {
    Future<void>.microtask(() {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    ChatOpenThreads.closed.removeListener(_onThreadClosed);
    widget.link.connected.removeListener(_onConnection);
    _search.dispose();
    _openRow.dispose();
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
    if (e.type == 'cleared' ||
        e.type == 'message_edited' ||
        e.type == 'message_deleted' ||
        e.type == 'conversations_changed' ||
        e.type == 'conversation_removed') {
      _load(silent: true);
      return;
    }
    if (e.type != 'message') return;
    final m = ChatMessage.fromJson(e.data);
    final i = _chats.indexWhere((c) => c.id == m.conversation);
    if (i < 0) {
      _load(silent: true);
      return;
    }
    final c = _chats[i];
    final me = widget.api.myId;
    final incoming = c.isGroup
        ? (m.sender != 0 && (me == null || m.sender != me))
        : m.sender == c.peer.id;
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

  /// Background refreshes in flight (the header says "Updating…").
  int _syncing = 0;

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _syncing++);
    }
    try {
      final chats = await widget.api.conversations();
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _loading = false;
      });
      widget.hub.mutedConversations
        ..clear()
        ..addAll(chats.where((c) => c.muted).map((c) => c.id));
    } catch (e) {
      if (!mounted) return;
      // A silent refresh that fails keeps what is on the screen.
      if (silent && _chats.isNotEmpty) return;
      setState(() {
        _error = _errorText(e, S.of(context));
        _loading = false;
      });
    } finally {
      if (silent && mounted) setState(() => _syncing--);
    }
  }

  Future<void> _open(ChatConversation chat) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      chatInstantRoute(
        (_) => ChatThreadPage(
          api: widget.api,
          link: widget.link,
          peer: chat.peer,
          conversationId: chat.id,
          sounds: widget.hub.sounds,
          mutedChats: widget.hub.mutedConversations,
          onRead: widget.hub.requestRefresh,
          isGroup: chat.isGroup,
        ),
      ),
    );
    // Back from the conversation: unread counts and the last line changed.
    if (mounted) _load();
  }

  // ── swipe / long-press actions ───────────────────────────────────────

  void _fail() {
    if (!mounted) return;
    final s = S.of(context);
    showNativeAlert(
      context: context,
      title: s.chatActionFailed,
      actions: [
        AlertAction(
          title: s.close,
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
      ],
    );
  }

  /// A chat is gone from the list (deleted, left): drop it and refresh the badge.
  void _drop(ChatConversation c) {
    if (!mounted) return;
    setState(() => _chats = _chats.where((x) => x.id != c.id).toList());
    widget.hub.mutedConversations.remove(c.id);
    widget.hub.requestRefresh();
  }

  Future<void> _toggleMute(ChatConversation c) async {
    HapticFeedback.selectionClick();
    final next = !c.muted;
    // Turning notifications off asks for how long; turning them on does not.
    int? hours;
    if (next) {
      final picked = await askMuteDuration(context);
      if (picked == null || !mounted) return;
      hours = picked == 0 ? null : picked;
    }
    try {
      await widget.api.setMuted(c.id, next, hours: hours);
    } catch (_) {
      return _fail();
    }
    if (!mounted) return;
    next
        ? widget.hub.mutedConversations.add(c.id)
        : widget.hub.mutedConversations.remove(c.id);
    setState(() {
      _chats = [
        for (final x in _chats) x.id == c.id ? x.copyWith(muted: next) : x,
      ];
    });
  }

  /// A personal chat: delete for me, or for the other person too.
  void _deleteDirect(ChatConversation c) {
    final s = S.of(context);
    showNativeAlert(
      context: context,
      title: s.chatDeleteTitle,
      message: s.chatDeleteMessage,
      actions: [
        AlertAction(
          title: s.chatDeleteForBoth(c.peer.shortName),
          style: AlertActionStyle.destructive,
          onPressed: () => _runDelete(c, forAll: true),
        ),
        AlertAction(
          title: s.chatDeleteForMe,
          style: AlertActionStyle.destructive,
          onPressed: () => _runDelete(c, forAll: false),
        ),
        AlertAction(
          title: s.chatCancel,
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
      ],
    );
  }

  Future<void> _runDelete(ChatConversation c, {required bool forAll}) async {
    try {
      await widget.api.deleteConversation(c.id, forAll: forAll);
    } catch (_) {
      return _fail();
    }
    _drop(c);
  }

  void _confirmLeave(ChatConversation c) {
    final s = S.of(context);
    showNativeAlert(
      context: context,
      title: s.chatLeaveTitle,
      message: c.peer.name,
      actions: [
        AlertAction(
          title: s.chatLeaveConfirm,
          style: AlertActionStyle.destructive,
          onPressed: () => _runLeave(c),
        ),
        AlertAction(
          title: s.chatCancel,
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
      ],
    );
  }

  Future<void> _runLeave(ChatConversation c) async {
    final me = widget.api.myId;
    if (me == null) return _fail();
    try {
      await widget.api.removeMember(c.id, me);
    } catch (e) {
      if (!(e is ChatApiException && e.statusCode == 404)) return _fail();
    }
    _drop(c);
  }

  void _confirmDeleteGroup(ChatConversation c) {
    final s = S.of(context);
    showNativeAlert(
      context: context,
      title: s.chatDeleteGroupTitle,
      message: c.peer.name,
      actions: [
        AlertAction(
          title: s.chatDeleteGroup,
          style: AlertActionStyle.destructive,
          onPressed: () => _runDeleteGroup(c),
        ),
        AlertAction(
          title: s.chatCancel,
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
      ],
    );
  }

  Future<void> _runDeleteGroup(ChatConversation c) async {
    try {
      await widget.api.deleteGroup(c.id);
    } catch (e) {
      if (!(e is ChatApiException && e.statusCode == 404)) return _fail();
    }
    _drop(c);
  }

  /// The owner of a group chooses: leave it, or delete it for everybody.
  void _ownerChoice(ChatConversation c) {
    final s = S.of(context);
    showNativeAlert(
      context: context,
      title: c.peer.name,
      actions: [
        AlertAction(
          title: s.chatLeaveGroupAction,
          style: AlertActionStyle.destructive,
          onPressed: () => _confirmLeave(c),
        ),
        AlertAction(
          title: s.chatDeleteGroup,
          style: AlertActionStyle.destructive,
          onPressed: () => _confirmDeleteGroup(c),
        ),
        AlertAction(
          title: s.chatCancel,
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
      ],
    );
  }

  /// What can be done with a chat from the list.
  /// Personal: delete. Group: leave; the owner may also delete the group.
  /// The last one is the "full swipe" action.
  List<ChatListAction> _actionsFor(ChatConversation c, S s) {
    const red = Color(0xFFFF3B30);
    final mute = ChatListAction(
      icon: c.muted
          ? Icons.notifications_rounded
          : Icons.notifications_off_rounded,
      sfSymbol: c.muted ? 'bell' : 'bell.slash',
      label: c.muted ? s.chatUnmuteAction : s.chatMuteAction,
      shortLabel: c.muted ? s.chatUnmuteShort : s.chatMuteShort,
      color: const Color(0xFFFF9500),
      onTap: () => _toggleMute(c),
    );
    if (!c.isGroup) {
      return [
        mute,
        ChatListAction(
          icon: Icons.delete_rounded,
          sfSymbol: 'trash',
          label: s.chatDeleteChatAction,
          shortLabel: s.chatDeleteShort,
          color: red,
          destructive: true,
          onTap: () => _deleteDirect(c),
        ),
      ];
    }
    final owner = c.myRole == 'owner';
    return [
      mute,
      ChatListAction(
        icon: owner ? Icons.delete_rounded : Icons.logout_rounded,
        sfSymbol: owner ? 'trash' : 'rectangle.portrait.and.arrow.right',
        label: s.chatLeaveGroupAction,
        shortLabel: owner ? s.chatDeleteShort : s.chatLeaveShort,
        color: red,
        destructive: true,
        // The owner picks (leave / delete); a member just leaves.
        onTap: () => owner ? _ownerChoice(c) : _confirmLeave(c),
      ),
    ];
  }

  /// The long-press menu: like the swipe, but the owner sees both choices.
  List<ChatListAction> _menuFor(ChatConversation c, S s) {
    final base = _actionsFor(c, s);
    if (c.isGroup && c.myRole == 'owner') {
      return [
        base.first,
        ChatListAction(
          icon: Icons.logout_rounded,
          sfSymbol: 'rectangle.portrait.and.arrow.right',
          label: s.chatLeaveGroupAction,
          shortLabel: s.chatLeaveShort,
          destructive: true,
          onTap: () => _confirmLeave(c),
        ),
        ChatListAction(
          icon: Icons.delete_rounded,
          sfSymbol: 'trash',
          label: s.chatDeleteGroup,
          shortLabel: s.chatDeleteShort,
          destructive: true,
          onTap: () => _confirmDeleteGroup(c),
        ),
      ];
    }
    return base;
  }

  /// What the native preview needs: the chat, and how to load its messages.
  Map<String, dynamic> _previewConfig(ChatConversation c, S s) => {
    'conversationId': c.id,
    'apiBase': widget.api.apiBase,
    'token': widget.api.apiToken,
    'myId': widget.api.myId ?? 0,
    'peerId': c.peer.id,
    'isGroup': c.isGroup,
    'title': c.peer.name,
    'photo': c.peer.photo ?? '',
    'subtitle': c.isGroup
        ? s.chatMembersCount(c.membersCount)
        : (c.peer.online ? s.chatOnline : s.chatLastSeen(c.peer.lastSeen)),
    'emptyText': s.chatNoMessagesYet,
  };

  /// "New group": the button is in place, the group itself comes next.
  Future<void> _newGroup() async {
    HapticFeedback.selectionClick();
    final List<ChatUser> contacts;
    try {
      contacts = await widget.api.contacts();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final draft = await pickGroupMembers(context, contacts);
    if (draft == null || draft.ids.isEmpty || draft.name.isEmpty || !mounted) {
      return;
    }
    final ChatConversation group;
    try {
      group = await widget.api.createGroup(
        draft.name,
        draft.ids,
        photo: draft.photo,
      );
    } catch (e) {
      if (!mounted) return;
      // A native alert: a snackbar can sit hidden behind the floating tab bar.
      final s = S.of(context);
      showNativeAlert(
        context: context,
        title: s.chatActionFailed,
        message: e is ChatApiException && e.statusCode != null
            ? '${e.statusCode}'
            : null,
        actions: [
          AlertAction(
            title: s.close,
            style: AlertActionStyle.cancel,
            onPressed: () {},
          ),
        ],
      );
      return;
    }
    if (!mounted) return;
    await _open(group);
  }

  /// The line under a chat's name: who wrote, an icon for the kind of message,
  /// and the text.
  ({String prefix, IconData? icon, String text}) _preview(
    ChatConversation c,
    S s,
  ) {
    final m = c.lastMessage;
    if (m == null) return (prefix: '', icon: null, text: '');
    if (m.isSystem) {
      return (prefix: '', icon: null, text: chatSystemText(m, s, widget.api.myId));
    }
    final text = chatPreviewText(m, s);
    final icon = chatPreviewIcon(m);
    if (c.isGroup) {
      final me = widget.api.myId;
      final mine = m.sender == 0 || (me != null && m.sender == me);
      final who = mine
          ? s.chatYou
          : (m.senderName.isEmpty
                ? s.chatMemberFallback
                : m.senderName.split(' ').first);
      return (prefix: '$who: ', icon: icon, text: text);
    }
    // A chat of two people: no name in front of the text (as in Telegram); that
    // the last message is mine shows in the ticks by the time.
    return (prefix: '', icon: icon, text: text);
  }

  /// Ticks for the time in the list: only when the last message of a chat of
  /// two people is mine.
  IconData? _tick(ChatConversation c) {
    final m = c.lastMessage;
    if (m == null || c.isGroup || m.isSystem) return null;
    if (m.sender == c.peer.id) return null;
    return m.read ? Icons.done_all_rounded : Icons.done_rounded;
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

    return ValueListenableBuilder<bool>(
      valueListenable: widget.link.connected,
      builder: (context, connected, _) => _buildScaffold(s, connected, shown),
    );
  }

  Widget _buildScaffold(S s, bool connected, List<ChatConversation> shown) {
    return FadingHeaderScaffold(
      title: _statusTitle(
        s,
        title: s.chatTitle,
        connected: connected,
        updating: _loading || _syncing > 0,
      ),
      centerTitle: true,
      background: AppColors.groupedBackground,
      searching: _searching,
      onToggleSearch: _toggleSearch,
      searchController: _search,
      searchHint: s.chatsSearchHint,
      // The second button of the capsule next to search: a new group (the
      // button only, for now).
      onFilterTap: _newGroup,
      filterIcon: Icons.add_rounded,
      filterSfSymbol: 'plus',
      body: (context, topInset) => _TabBody(
        topInset: topInset,
        onRefresh: _load,
        loading: _loading,
        error: _error,
        emptyIcon: Icons.forum_outlined,
        emptySvg: 'assets/icons/tg_chats.svg',
        emptyText: _search.text.trim().isEmpty
            ? s.chatsEmpty
            : s.chatNothingFound,
        plain: true,
        rows: [
          for (final c in shown)
            ChatSwipeRow(
              id: c.id,
              open: _openRow,
              actions: _actionsFor(c, s),
              // Long press: iOS shows a native preview of the chat (scrolls)
              // with the menu under it; elsewhere a plain menu.
              child: _LongPressMenu(
                native: (row) => showNativeChatPreview(
                  preview: {
                    ..._previewConfig(c, s),
                    // The pressed row: the preview sits beside it, not on it.
                    'rowTop': row.top,
                    'rowBottom': row.bottom,
                  },
                  actions: _menuFor(c, s),
                ),
                fallbackActions: [
                  for (final a in _menuFor(c, s))
                    AdaptiveContextMenuAction(
                      title: a.label,
                      icon: a.icon,
                      isDestructive: a.destructive,
                      onPressed: a.onTap,
                    ),
                ],
                child: ColoredBox(
                  color: AppColors.groupedBackground,
                  child: ChatRow(
                    user: c.peer,
                    subtitle: _preview(c, s).text,
                    subtitleIcon: _preview(c, s).icon,
                    subtitlePrefix: _preview(c, s).prefix,
                    timeIcon: _tick(c),
                    time: chatTimeLabel(
                      c.lastMessage?.createdAt ?? c.updatedAt,
                      s,
                    ),
                    unread: c.unread,
                    muted: c.muted,
                    onTap: () => _open(c),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A long press on a chat: the native preview on iOS (the last messages, a card
/// that scrolls, the menu under it), a plain menu elsewhere.
class _LongPressMenu extends StatelessWidget {
  const _LongPressMenu({
    required this.native,
    required this.fallbackActions,
    required this.child,
  });

  final Future<bool> Function(Rect row) native;
  final List<AdaptiveContextMenuAction> fallbackActions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: () => native(rowRect(context)),
        child: child,
      );
    }
    return AdaptiveContextMenu(actions: fallbackActions, child: child);
  }
}

/// Where a widget is on the screen (in points).
Rect rowRect(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return Rect.zero;
  return box.localToGlobal(Offset.zero) & box.size;
}
