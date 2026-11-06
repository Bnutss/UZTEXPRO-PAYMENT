import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'chat_api.dart';
import 'chat_socket.dart';
import 'chat_sounds.dart';

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
      sounds: ChatSounds(AudioChatSoundPlayer()),
    );
  }

  final ChatRest api;
  final ChatLink link;

  /// Set when the hub owns the connection (it starts and disposes it).
  final ChatSocket? socket;

  /// "Message sent" / "message came" sounds; the chat window plays them.
  final ChatSounds? sounds;

  /// How long to wait before asking the server for the number after a message
  /// came while the chat window is open: the open conversation marks it read
  /// in the meantime.
  final Duration refreshDelay;
  Timer? _refreshTimer;

  /// Unread messages in all chats.
  final ValueNotifier<int> unread = ValueNotifier(0);

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
    if (_chatOpen) {
      // Inside the chat window: its screens show the message, a sound tells
      // that it came, and the total follows the server (the open conversation
      // marks the message read first).
      if (me != null && sender != me) sounds?.incoming();
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
  }
}
