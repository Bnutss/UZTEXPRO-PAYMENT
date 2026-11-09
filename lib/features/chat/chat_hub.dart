import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'chat_api.dart';
import 'chat_models.dart';
import 'chat_push.dart' show ChatPushTarget;
import 'chat_socket.dart';
import 'chat_notify_settings.dart';
import 'chat_sounds.dart';
import 'chat_thread_controller.dart' show ChatOpenThreads;

/// A message from somebody else in a chat that is not on the screen: what the
/// in-app banner shows.
class ChatIncoming {
  const ChatIncoming(this.conversation, this.message);

  final ChatConversation conversation;
  final ChatMessage message;
}

/// The chat for the whole app session: ONE live connection and the count of
/// unread messages for the badge on the chat button. The chat window uses the
/// same connection, so opening it costs nothing.
///
/// The count is the server's number ([refresh]); between refreshes it grows by
/// one for every message that arrives from somebody else while the chat window
/// is closed. While the window is open the number follows the server instead
/// (messages are being read there), and incoming messages play a sound.
class ChatHub with WidgetsBindingObserver {
  ChatHub({
    required this.api,
    required this.link,
    this.socket,
    this.sounds,
    this.refreshDelay = const Duration(milliseconds: 700),
  });

  /// The real thing, for a stored login answer / token.
  factory ChatHub.forToken(String jwtToken) {
    final api = ChatApi(jwtToken);
    final socket = ChatSocket(api.token);
    return ChatHub(
      api: api,
      link: socket,
      socket: socket,
      sounds: ChatSounds(
        AudioChatSoundPlayer(),
        settings: ChatNotifySettings.instance..load(),
      ),
    );
  }

  final ChatRest api;
  final ChatLink link;

  /// Set when the hub owns the connection (it starts and disposes it).
  final ChatSocket? socket;

  /// "Message sent" / "message came" sounds; the chat window plays them.
  final ChatSounds? sounds;

  /// Chats whose notifications I switched off: no sound for them.
  final Set<int> mutedConversations = {};

  /// How long to wait before asking the server for the number after a message
  /// came while the chat window is open: the open conversation marks it read
  /// in the meantime.
  final Duration refreshDelay;
  Timer? _refreshTimer;

  /// Unread messages in all chats.
  final ValueNotifier<int> unread = ValueNotifier(0);

  /// Messages for the in-app banner (see [ChatIncoming]).
  final _incoming = StreamController<ChatIncoming>.broadcast();
  Stream<ChatIncoming> get incoming => _incoming.stream;

  /// A tap on a banner asks to open this conversation: the chat window (or the
  /// home screen, when it is closed) opens it.
  final ValueNotifier<ChatPushTarget?> openRequest = ValueNotifier(null);

  void requestOpen(ChatPushTarget target) {
    openRequest.value = null; // so that the same target notifies again
    openRequest.value = target;
  }

  final Map<int, ChatConversation> _known = {};
  Future<void>? _loadingKnown;

  Future<ChatConversation?> _conversationOf(int id) async {
    var c = _known[id];
    if (c != null) return c;
    _loadingKnown ??= () async {
      try {
        for (final x in await api.conversations()) {
          _known[x.id] = x;
        }
      } catch (_) {}
    }().whenComplete(() => _loadingKnown = null);
    await _loadingKnown;
    return _known[id];
  }

  /// Offers a message from somebody else to the banner, unless it should not
  /// be shown: a service line, a muted chat, the chat on the screen.
  Future<void> _announce(Map<String, dynamic> data) async {
    try {
      final m = ChatMessage.fromJson(data);
      if (m.isSystem || m.sender == api.myId) return;
      if (mutedConversations.contains(m.conversation)) return;
      if (ChatOpenThreads.isOpen(m.conversation)) return;
      final c = await _conversationOf(m.conversation);
      if (c == null || c.muted || _disposed) return;
      if (ChatOpenThreads.isOpen(m.conversation)) return;
      _incoming.add(ChatIncoming(c, m));
    } catch (_) {}
  }

  bool _chatOpen = false;

  /// The chat window is on screen.
  bool get isChatOpen => _chatOpen;
  bool _wasConnected = false;
  bool _disposed = false;
  StreamSubscription<ChatEvent>? _sub;

  void start() {
    socket?.start();
    _sub = link.events.listen(_onEvent);
    _wasConnected = link.connected.value;
    link.connected.addListener(_onConnection);
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  /// The chat window opened / closed. While it is open it shows the real
  /// numbers itself; on closing the badge is refreshed from the server.
  set chatOpen(bool open) {
    if (_chatOpen == open) return;
    _chatOpen = open;
    if (!open) refresh();
  }

  /// [refresh] a little later, once (a burst of calls makes one request): the
  /// chat window asks for it after it has marked messages read.
  void requestRefresh({Duration? after}) {
    if (_disposed) return;
    _refreshTimer?.cancel();
    _refreshTimer = Timer(after ?? refreshDelay, refresh);
  }

  /// Asks the server for the number of unread messages.
  Future<void> refresh() async {
    try {
      final n = await api.unread();
      if (!_disposed) unread.value = n;
    } catch (_) {
      // Keeps the last known number.
    }
  }

  void _onEvent(ChatEvent e) {
    if (e.type == 'denied') {
      unread.value = 0;
      return;
    }
    if (e.type != 'message') return;
    final sender = (e.data['sender'] as num?)?.toInt();
    final me = api.myId;
    if (me != null && sender != me) _announce(e.data);
    if (_chatOpen) {
      // Inside the chat window: its screens show the message, a sound tells
      // that it came, and the total follows the server (the open conversation
      // marks the message read first).
      final conv = (e.data['conversation'] as num?)?.toInt();
      if (me != null && sender != me && !mutedConversations.contains(conv)) {
        sounds?.incoming();
      }
      requestRefresh();
      return;
    }
    if (me == null) {
      refresh(); // cannot tell whose message it is: ask the server
    } else if (sender != me) {
      unread.value++;
    }
  }

  /// The socket is back: whatever came meanwhile is only on the server.
  void _onConnection() {
    final now = link.connected.value;
    final returned = now && !_wasConnected;
    _wasConnected = now;
    if (returned) refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the background the socket may be dead without anybody
    // noticing: check it, and take the count again.
    if (state == AppLifecycleState.resumed) {
      socket?.ensureAlive();
      refresh();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _sub?.cancel();
    link.connected.removeListener(_onConnection);
    socket?.dispose();
    unread.dispose();
    openRequest.dispose();
    _incoming.close();
  }
}
