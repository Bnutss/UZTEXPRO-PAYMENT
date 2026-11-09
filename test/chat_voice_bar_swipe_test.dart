import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uztexpro_payment/features/chat/chat_models.dart';
import 'package:uztexpro_payment/features/chat/chat_voice.dart';
import 'package:uztexpro_payment/features/chat/chat_voice_widgets.dart';

/// The native player bar of a playing voice message (a UIKit view over the whole
/// window) must not hang in place while the page is dragged back.
void main() {
  const channel = MethodChannel('uztexpro/native_sheet');

  testWidgets('the native bar hides while the page is swiped back', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      return null;
    });
    final player = ChatVoicePlayer.instance;
    final voice = ChatMessage(
      id: 1,
      conversation: 1,
      sender: 2,
      text: 'Голосовое сообщение',
      clientId: 'c',
      createdAt: DateTime(2026, 11, 9, 12),
      read: false,
      kind: 'voice',
      durationMs: 4200,
    );
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [VoiceTopBarHost(top: 60, authorOf: (_) => 'Anna')],
            ),
          ),
        ),
      );
      // A voice message is playing: the bar is up.
      player.current = voice;
      player.currentKey = ChatVoicePlayer.keyOf(voice);
      await player.cycleSpeed(); // tells the listeners
      await tester.pump();
      expect(calls, contains('voiceBarShow'));

      // The swipe from the left edge starts: the bar goes away at once.
      calls.clear();
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.didStartUserGesture();
      await tester.pump();
      expect(calls, ['voiceBarHide']);

      // It is not sent again while the finger moves (the player ticks).
      calls.clear();
      await player.cycleSpeed();
      await tester.pump();
      expect(calls, isEmpty);

      // The swipe is cancelled (the chat stays): the bar comes back.
      navigator.didStopUserGesture();
      await tester.pump();
      expect(calls, ['voiceBarShow']);
    } finally {
      player.current = null;
      player.currentKey = null;
      player.speed = 1.0;
      debugDefaultTargetPlatformOverride = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    }
  });

  testWidgets('without a swipe the bar stays up', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      return null;
    });
    final player = ChatVoicePlayer.instance;
    final voice = ChatMessage(
      id: 2,
      conversation: 1,
      sender: 2,
      text: 'Голосовое сообщение',
      clientId: 'd',
      createdAt: DateTime(2026, 11, 9, 12),
      read: false,
      kind: 'voice',
      durationMs: 4200,
    );
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [VoiceTopBarHost(top: 60, authorOf: (_) => 'Anna')],
            ),
          ),
        ),
      );
      player.current = voice;
      player.currentKey = ChatVoicePlayer.keyOf(voice);
      await player.cycleSpeed();
      await tester.pump();
      expect(calls.where((c) => c == 'voiceBarHide'), isEmpty);
    } finally {
      player.current = null;
      player.currentKey = null;
      player.speed = 1.0;
      debugDefaultTargetPlatformOverride = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    }
  });

  /// A playing voice message, the mock of the native channel, the "iOS" switch.
  Future<List<String>> setUpBar(WidgetTester tester, Widget home) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      return null;
    });
    await tester.pumpWidget(MaterialApp(home: home));
    return calls;
  }

  Future<void> startPlaying(WidgetTester tester) async {
    final player = ChatVoicePlayer.instance;
    final voice = ChatMessage(
      id: 3,
      conversation: 1,
      sender: 2,
      text: 'Голосовое сообщение',
      clientId: 'e',
      createdAt: DateTime(2026, 11, 9, 12),
      read: false,
      kind: 'voice',
      durationMs: 4200,
    );
    player.current = voice;
    player.currentKey = ChatVoicePlayer.keyOf(voice);
    await player.cycleSpeed();
    await tester.pump();
  }

  void tearDownBar(WidgetTester tester) {
    final player = ChatVoicePlayer.instance;
    player.current = null;
    player.currentKey = null;
    player.speed = 1.0;
    debugDefaultTargetPlatformOverride = null;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  }

  testWidgets('the bar does not jump up over a profile that is sliding away', (
    tester,
  ) async {
    final calls = await setUpBar(
      tester,
      Scaffold(
        body: Stack(
          children: [VoiceTopBarHost(top: 60, authorOf: (_) => 'Anna')],
        ),
      ),
    );
    try {
      await startPlaying(tester);
      expect(calls, contains('voiceBarShow'));

      // The profile opens over the chat: the bar goes away at once.
      calls.clear();
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('profile')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(calls, contains('voiceBarHide'));
      await tester.pumpAndSettle();

      // The profile closes: while it is still sliding off, the bar stays down...
      calls.clear();
      nav.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('profile'), findsOneWidget); // still on the screen
      expect(calls.where((c) => c == 'voiceBarShow'), isEmpty);

      // ...and comes back only when the chat is fully uncovered.
      await tester.pumpAndSettle();
      expect(find.text('profile'), findsNothing);
      expect(calls, contains('voiceBarShow'));
    } finally {
      tearDownBar(tester);
    }
  });

  testWidgets('the bar goes down at the start of the chat closing', (
    tester,
  ) async {
    final calls = await setUpBar(tester, const Scaffold(body: Text('list')));
    try {
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: Stack(
              children: [VoiceTopBarHost(top: 60, authorOf: (_) => 'Anna')],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await startPlaying(tester);
      expect(calls, contains('voiceBarShow'));

      // The chat is closed by the "back" button: during its closing animation
      // the bar must not hang over the list.
      calls.clear();
      nav.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byType(VoiceTopBarHost), findsOneWidget); // still closing
      expect(calls, contains('voiceBarHide'));
      await tester.pumpAndSettle();
    } finally {
      tearDownBar(tester);
    }
  });
}
