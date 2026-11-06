import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uztexpro_payment/features/chat/chat_list_actions.dart';

void main() {
  late ValueNotifier<int?> open;
  late List<String> calls;

  Widget host(List<Widget> rows) => MaterialApp(
    home: Scaffold(body: Column(children: rows)),
  );

  Widget row(int id) => ChatSwipeRow(
    id: id,
    open: open,
    background: Colors.white,
    actions: [
      ChatListAction(
        icon: Icons.notifications_off_rounded,
        label: 'Mute',
        shortLabel: 'Mute$id',
        onTap: () => calls.add('mute$id'),
      ),
      ChatListAction(
        icon: Icons.delete_rounded,
        label: 'Delete',
        shortLabel: 'Delete$id',
        destructive: true,
        onTap: () => calls.add('delete$id'),
      ),
    ],
    child: SizedBox(height: 70, child: Center(child: Text('chat $id'))),
  );

  setUp(() {
    open = ValueNotifier<int?>(null);
    calls = [];
  });

  testWidgets('a short drag opens the panel; a tap on a button runs it', (
    tester,
  ) async {
    await tester.pumpWidget(host([row(1)]));
    await tester.drag(find.text('chat 1'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(open.value, 1);
    await tester.tap(find.text('Mute1'));
    await tester.pumpAndSettle();
    expect(calls, ['mute1']);
    expect(open.value, isNull); // it closes after the action
  });

  testWidgets('a tap on an open row only closes it', (tester) async {
    await tester.pumpWidget(host([row(1)]));
    await tester.drag(find.text('chat 1'), const Offset(-140, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('chat 1'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(open.value, isNull);
    expect(calls, isEmpty);
  });

  testWidgets('opening another row closes the first', (tester) async {
    await tester.pumpWidget(host([row(1), row(2)]));
    await tester.drag(find.text('chat 1'), const Offset(-140, 0));
    await tester.pumpAndSettle();
    expect(open.value, 1);
    await tester.drag(find.text('chat 2'), const Offset(-140, 0));
    await tester.pumpAndSettle();
    expect(open.value, 2);
    // the first slid back: its text is at its place again
    final first = tester.getTopLeft(find.text('chat 1')).dx;
    final second = tester.getTopLeft(find.text('chat 2')).dx;
    expect(first, greaterThan(second));
  });

  testWidgets('a full swipe runs the last action', (tester) async {
    await tester.pumpWidget(host([row(1)]));
    await tester.fling(find.text('chat 1'), const Offset(-700, 0), 300);
    await tester.pumpAndSettle();
    expect(calls, ['delete1']);
    expect(open.value, isNull);
  });

  testWidgets('a tiny drag does not open', (tester) async {
    await tester.pumpWidget(host([row(1)]));
    await tester.drag(find.text('chat 1'), const Offset(-20, 0));
    await tester.pumpAndSettle();
    expect(open.value, isNull);
    expect(calls, isEmpty);
  });
}
