import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uztexpro_payment/features/chat/chat_models.dart';
import 'package:uztexpro_payment/features/chat/chat_thread_page.dart';
import 'package:uztexpro_payment/features/chat/chat_voice.dart';
import 'package:uztexpro_payment/features/chat/chat_voice_widgets.dart';

/// Swipe a message to the left to answer it.
void main() {
  const screen = Size(390, 844);

  Future<int> pumpRow(
    WidgetTester tester, {
    required Widget bubble,
    bool mine = true,
  }) async {
    tester.view.physicalSize = screen * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var replies = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                debugSwipeToReply(
                  mine: mine,
                  onReply: () => replies++,
                  child: bubble,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // `replies` is read through the closure: the caller asks for it later.
    _replies = () => replies;
    return replies;
  }

  Widget textBubble() => Container(
    key: const ValueKey('bubble'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFD8F8C8),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text('сообщение'),
  );

  testWidgets('a swipe past the trigger answers', (tester) async {
    await pumpRow(tester, bubble: textBubble());
    await tester.drag(
      find.byKey(const ValueKey('bubble')),
      const Offset(-90, 0),
    );
    await tester.pumpAndSettle();
    expect(_replies(), 1);
    // The bubble is back in its place.
    expect(
      tester.getRect(find.byKey(const ValueKey('bubble'))).right,
      closeTo(screen.width - 10, 1),
    );
  });

  testWidgets('a short swipe does not answer', (tester) async {
    await pumpRow(tester, bubble: textBubble());
    await tester.drag(
      find.byKey(const ValueKey('bubble')),
      const Offset(-30, 0),
    );
    await tester.pumpAndSettle();
    expect(_replies(), 0);
  });

  testWidgets('a swipe to the right does nothing', (tester) async {
    await pumpRow(tester, bubble: textBubble());
    final before = tester.getRect(find.byKey(const ValueKey('bubble')));
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('bubble'))),
    );
    await g.moveBy(const Offset(80, 0));
    await tester.pump();
    expect(tester.getRect(find.byKey(const ValueKey('bubble'))), before);
    await g.up();
    await tester.pumpAndSettle();
    expect(_replies(), 0);
  });

  testWidgets('a quick fling answers even if it is short', (tester) async {
    await pumpRow(tester, bubble: textBubble());
    await tester.timedDrag(
      find.byKey(const ValueKey('bubble')),
      const Offset(-40, 0),
      const Duration(milliseconds: 30),
      frequency: 240,
    );
    await tester.pumpAndSettle();
    expect(_replies(), 1);
  });

  testWidgets('the arrow shows at the screen edge, level with the bubble', (
    tester,
  ) async {
    await pumpRow(tester, bubble: textBubble());
    final bubble = tester.getRect(find.byKey(const ValueKey('bubble')));
    final g = await tester.startGesture(bubble.center);
    await g.moveBy(const Offset(-60, 0));
    await tester.pump();
    final arrow = tester.getRect(find.byIcon(Icons.reply_rounded));
    // On the screen (it used to be 34 px behind the bubble: off the screen
    // for a message at the right edge), at the right edge, level with the bubble.
    expect(arrow.right, lessThanOrEqualTo(screen.width));
    expect(arrow.left, greaterThan(screen.width - 60));
    expect((arrow.center.dy - bubble.center.dy).abs(), lessThan(1));
    // The bubble followed the finger, but not past the maximum.
    expect(
      tester.getRect(find.byKey(const ValueKey('bubble'))).left,
      lessThan(bubble.left),
    );
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('it also works on the free space next to a short bubble', (
    tester,
  ) async {
    await pumpRow(tester, bubble: textBubble(), mine: false);
    // The bubble is at the left; the swipe starts on the empty right part.
    await tester.dragFrom(const Offset(300, 422), const Offset(-90, 0));
    await tester.pumpAndSettle();
    expect(_replies(), 1);
  });

  testWidgets(
    'a swipe over the wave of a voice message answers and does not play it',
    (tester) async {
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
        waveform: [for (var i = 0; i < 40; i++) (i * 7) % 31],
      );
      final player = ChatVoicePlayer.instance;
      await pumpRow(
        tester,
        bubble: SizedBox(
          width: kVoiceBodyWidth + 28,
          height: kVoiceBodyHeight + 16,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: VoiceBubbleBody(
              message: voice,
              accent: Colors.orange,
              meta: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      // Start the swipe ON the wave (to the right of the play button).
      final start =
          tester.getTopLeft(find.byType(VoiceBubbleBody)) +
          const Offset(150, 20);
      await tester.dragFrom(start, const Offset(-90, 0));
      await tester.pumpAndSettle();

      expect(_replies(), 1);
      expect(player.currentKey, isNull);
      expect(player.playing, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

/// Reads the number of answers of the row pumped last.
int Function() _replies = () => 0;
