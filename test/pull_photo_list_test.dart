import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uztexpro_payment/core/widgets/pull_photo_list.dart';
import 'package:uztexpro_payment/core/widgets/ui_blocks.dart';

/// Pulling the profile page down opens the photo: one short swipe is enough, it
/// follows the finger for the first stretch and then opens by itself, smoothly.
/// Leaving the page takes the island avatar off at once.
void main() {
  const screen = Size(390, 844);

  /// How tall the photo is now: the `OverflowBox` that holds it.
  double photoHeight(WidgetTester tester) =>
      tester.getSize(find.byType(OverflowBox).first).height;

  /// The opening, 0 (round) to 1 (open), read from the photo's height.
  double openness(WidgetTester tester) {
    const round = 84.0; // IslandPullAvatar.avatarSize
    final full = screen.width * PullPhotoList.openRatio;
    return ((photoHeight(tester) - round) / (full - round)).clamp(0.0, 1.0);
  }

  Widget profile() => PullPhotoList(
    top: 60,
    name: 'Иванов Иван',
    sources: const [PhotoSource('http://localhost/none.jpg')],
    blockHeight: 90,
    blockBuilder: (context, t) => const SizedBox.expand(),
    children: [for (var i = 0; i < 12; i++) ListTile(title: Text('$i'))],
  );

  Future<void> pumpProfile(WidgetTester tester) async {
    tester.view.physicalSize = screen * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: profile())));
    await tester.pump();
  }

  testWidgets('a short pull follows the finger a little and goes back', (
    tester,
  ) async {
    await pumpProfile(tester);
    expect(openness(tester), 0);
    final g = await tester.startGesture(const Offset(200, 300));
    // Slowly, in small steps (a quick flick would open it).
    for (var i = 0; i < 5; i++) {
      await g.moveBy(const Offset(0, 4));
      await tester.pump();
    }
    expect(openness(tester), inExclusiveRange(0.1, 0.3)); // follows the finger
    await g.up();
    await tester.pumpAndSettle();
    expect(openness(tester), 0); // stopped short: back to round
  });

  testWidgets('past a third of the way it opens the rest by itself, softly', (
    tester,
  ) async {
    await pumpProfile(tester);
    final g = await tester.startGesture(const Offset(200, 300));
    // ONE short swipe; the finger does not move any more after this.
    await g.moveBy(const Offset(0, 40));
    await tester.pump(); // the glide starts
    final first = openness(tester);
    expect(first, greaterThan(0.3));
    // Not a jump: a few frames later it is on its way, not yet there...
    await tester.pump(const Duration(milliseconds: 60));
    final soon = openness(tester);
    expect(soon, greaterThan(first));
    expect(soon, lessThan(1));
    // ...and it arrives, with the finger still down.
    await tester.pumpAndSettle();
    expect(openness(tester), 1);
    await g.up();
    await tester.pumpAndSettle();
    expect(openness(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a quick flick opens it even from a short pull', (tester) async {
    await pumpProfile(tester);
    final g = await tester.startGesture(const Offset(200, 300));
    await g.moveBy(const Offset(0, 8));
    await g.moveBy(const Offset(0, 8)); // 16 px: short of the third
    await tester.pump();
    expect(openness(tester), lessThan(0.3));
    await g.up();
    await tester.pumpAndSettle();
    expect(openness(tester), 1);
  });

  testWidgets('open: a short pull up closes the rest by itself', (
    tester,
  ) async {
    await pumpProfile(tester);
    final open = await tester.startGesture(const Offset(200, 300));
    await open.moveBy(const Offset(0, 40));
    await tester.pumpAndSettle();
    await open.up();
    await tester.pumpAndSettle();
    expect(openness(tester), 1);

    final g = await tester.startGesture(const Offset(200, 500));
    await g.moveBy(const Offset(0, -20));
    await tester.pump();
    expect(openness(tester), inExclusiveRange(0.7, 1)); // follows the finger up
    await g.moveBy(const Offset(0, -20));
    await tester.pumpAndSettle();
    expect(openness(tester), 0);
    await g.up();
  });

  testWidgets('on an island iPhone the page draws its own photo only while '
      'it is leaving', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      tester.view.physicalSize = screen * 3;
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 59 * 3);
      tester.view.viewPadding = const FakeViewPadding(top: 59 * 3);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) => Center(
                child: TextButton(
                  onPressed: () => Navigator.of(c).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(body: profile()),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // At rest the round photo is the island's own (drawn over the page), so
      // the page draws none.
      expect(find.byType(OverflowBox), findsNothing);

      // The page leaves (the "back" button): the island's avatar goes at once
      // and the page's own round photo is there, to slide away with it.
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byType(PullPhotoList), findsOneWidget); // still on its way
      expect(find.byType(OverflowBox), findsWidgets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
