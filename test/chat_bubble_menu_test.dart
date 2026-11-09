import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uztexpro_payment/features/chat/chat_thread_page.dart';

/// The long-press menu of a message: the screen blurs, the message lifts and
/// the panel opens UNDER it (the message moves up when there is no room below).
void main() {
  const labels = [
    'Ответить',
    'Переслать',
    'Скопировать',
    'Изменить',
    'Удалить',
  ];

  Widget bubble(
    String text, {
    required bool mine,
    double? bottom,
    double? top,
  }) {
    return Positioned(
      right: mine ? 10 : null,
      left: mine ? null : 10,
      bottom: bottom,
      top: top,
      child: debugBubbleMenu(
        labels: labels,
        onChoice: (_) {},
        mine: mine,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: mine ? const Color(0xFFD8F8C8) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(text, style: const TextStyle(fontSize: 17)),
        ),
      ),
    );
  }

  Future<void> pumpChat(WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFFFF1E6),
          body: Stack(
            children: [
              for (var i = 0; i < 9; i++)
                Positioned(
                  left: 20,
                  top: 80.0 + i * 85,
                  child: Container(
                    width: 220 + (i % 3) * 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              bubble('низкое сообщение', mine: true, bottom: 90),
              bubble('среднее сообщение', mine: true, top: 380),
              bubble('верхнее сообщение', mine: false, top: 110),
            ],
          ),
        ),
      ),
    );
  }

  /// Holds a finger on [text] until the menu opens (the picture of the bubble
  /// is made with real async), then lets the opening animation finish.
  Future<void> openMenu(WidgetTester tester, String text) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.text(text)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Rect liftedRect(WidgetTester tester) => tester.getRect(find.byType(RawImage));

  /// A test on "iOS": the platform override is put back before the test ends
  /// (the framework checks that no debug variable is left changed).
  void iosTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  iosTest('a low message lifts and the menu opens under it', (tester) async {
    await pumpChat(tester);
    final before = tester.getRect(find.text('низкое сообщение'));
    await openMenu(tester, 'низкое сообщение');

    expect(find.text('Ответить'), findsOneWidget);
    expect(find.text('Удалить'), findsOneWidget);
    final lifted = liftedRect(tester);
    final firstRow = tester.getRect(find.text('Ответить'));
    // The message moved UP to make room, and the menu starts under it.
    expect(lifted.bottom, lessThan(before.bottom - 20));
    expect(firstRow.top, greaterThan(lifted.bottom - 1));
    // Everything is on the screen.
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(
      tester.getRect(find.text('Удалить')).bottom,
      lessThan(screen.height),
    );

    // Closing (tap outside) draws the picture while it fades: no exceptions.
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('Ответить'), findsNothing);
  });

  iosTest('a middle message stays where it is, the menu is under it', (
    tester,
  ) async {
    await pumpChat(tester);
    final before = tester.getRect(find.text('среднее сообщение'));
    await openMenu(tester, 'среднее сообщение');

    final lifted = liftedRect(tester);
    expect((lifted.center.dy - before.center.dy).abs(), lessThan(4));
    expect(
      tester.getRect(find.text('Ответить')).top,
      greaterThan(lifted.bottom - 1),
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });

  iosTest('a plain tap does not open the menu', (tester) async {
    await pumpChat(tester);
    await tester.tap(find.text('верхнее сообщение'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Ответить'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  const both = 'Удалить у меня и у Иванов Иван';
  const onlyMe = 'Удалить у меня';

  Future<List<String>> pumpDeletable(WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final chosen = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                right: 10,
                top: 300,
                child: debugBubbleMenu(
                  labels: labels,
                  choices: const [both, onlyMe],
                  onChoice: chosen.add,
                  mine: true,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('сообщение'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await openMenu(tester, 'сообщение');
    return chosen;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  iosTest('Delete shows its choices IN THE SAME panel (no sheet)', (
    tester,
  ) async {
    final chosen = await pumpDeletable(tester);
    final firstLineBefore = tester.getRect(find.text('Ответить')).center.dy;
    final liftedBefore = liftedRect(tester);

    await tester.tap(find.text('Удалить'));
    await settle(tester);

    // The lines of the panel were replaced by the two choices...
    expect(find.text(both), findsOneWidget);
    expect(find.text(onlyMe), findsOneWidget);
    expect(find.text('Ответить'), findsNothing);
    // ...in the same place, under the same lifted message, nothing closed.
    expect(find.byType(RawImage), findsOneWidget);
    expect(liftedRect(tester), liftedBefore);
    expect(
      (tester.getRect(find.text(both)).center.dy - firstLineBefore).abs(),
      lessThan(4),
    );
    expect(chosen, isEmpty);
    // The panel is exactly two lines high now (not five, with a hole below).
    expect(tester.getSize(find.byKey(const ValueKey('menu-panel'))).height, 84);
    // The first choice (for me AND the other person) is above "only me".
    expect(
      tester.getRect(find.text(both)).top,
      lessThan(tester.getRect(find.text(onlyMe)).top),
    );
    expect(tester.takeException(), isNull);
  });

  iosTest('"Delete for me and <name>" reports deleteForAll', (tester) async {
    final chosen = await pumpDeletable(tester);
    await tester.tap(find.text('Удалить'));
    await settle(tester);
    await tester.tap(find.text(both));
    await settle(tester);
    expect(chosen, ['all']);
    expect(find.text(both), findsNothing);
    expect(tester.takeException(), isNull);
  });

  iosTest('"Delete for me" reports deleteForMe', (tester) async {
    final chosen = await pumpDeletable(tester);
    await tester.tap(find.text('Удалить'));
    await settle(tester);
    await tester.tap(find.text(onlyMe));
    await settle(tester);
    expect(chosen, ['me']);
    expect(tester.takeException(), isNull);
  });

  iosTest('Tapping outside the choices deletes nothing', (tester) async {
    final chosen = await pumpDeletable(tester);
    await tester.tap(find.text('Удалить'));
    await settle(tester);
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);
    expect(chosen, isEmpty);
    expect(find.text(both), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
