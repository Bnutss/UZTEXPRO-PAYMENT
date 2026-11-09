import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uztexpro_payment/core/widgets/native_glass_gate.dart';

/// A native glass control must give way to its Flutter stand-in whenever a
/// screen is on its way over it or away from it, and while a Flutter overlay
/// blurs the screen.
void main() {
  const nativeKey = ValueKey('native');
  const standKey = ValueKey('standIn');

  Widget header() => const SizedBox(
    width: 46,
    height: 46,
    child: NativeGlassSwap(
      native: SizedBox(key: nativeKey, width: 46, height: 46),
      standIn: SizedBox(key: standKey, width: 46, height: 46),
    ),
  );

  bool nativePainted(WidgetTester tester) => !tester
      .widget<Offstage>(
        find
            .ancestor(
              of: find.byKey(nativeKey, skipOffstage: false),
              matching: find.byType(Offstage),
            )
            .first,
      )
      .offstage;

  double standInOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.byKey(standKey, skipOffstage: false),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      )
      .opacity;

  testWidgets('native glass at rest', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: header())));
    expect(nativePainted(tester), isTrue);
    expect(standInOpacity(tester), 0);
  });

  testWidgets(
    'a screen over it: stand-in all the way, native back at the end',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: header())));
      final nav = tester.state<NavigatorState>(find.byType(Navigator));

      // A screen (a profile, a photo) opens over it.
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('photo')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(nativePainted(tester), isFalse);
      expect(standInOpacity(tester), 1);
      await tester.pumpAndSettle();

      // It closes: the stand-in stays while the page is still sliding off...
      nav.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('photo'), findsOneWidget);
      expect(nativePainted(tester), isFalse);
      expect(standInOpacity(tester), 1);

      // ...and the native glass returns only when the screen has gone.
      await tester.pumpAndSettle();
      expect(find.text('photo'), findsNothing);
      expect(nativePainted(tester), isTrue);
      expect(standInOpacity(tester), 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the blur overlay still swaps it', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: header())));
    nativeGlassHidden.value = true;
    await tester.pump();
    expect(nativePainted(tester), isFalse);
    expect(standInOpacity(tester), 1);
    nativeGlassHidden.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(nativePainted(tester), isTrue);
    expect(standInOpacity(tester), 0);
  });
}
