import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uztexpro_payment/features/chat/chat_models.dart';
import 'package:uztexpro_payment/features/chat/chat_widgets.dart';

Widget host(bool plain) => MaterialApp(
  home: Scaffold(
    backgroundColor: const Color(0xFFF2F2F7),
    body: ChatListCard(
      plain: plain,
      children: [
        for (final n in ['Anna', 'Bob', 'Carl'])
          ChatRow(
            user: ChatUser(id: n.length, name: n, position: 'Operator'),
            subtitle: 'Operator',
            onTap: () {},
          ),
      ],
    ),
  ),
);

bool hasWhiteRoundedCard(WidgetTester t) =>
    t.widgetList<Container>(find.byType(Container)).any((c) {
      final d = c.decoration;
      return d is BoxDecoration &&
          d.color == Colors.white &&
          d.borderRadius != null;
    });

void main() {
  testWidgets(
    'plain: the rows sit on the page, no white card, hairlines between them',
    (t) async {
      await t.pumpWidget(host(true));
      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Carl'), findsOneWidget);
      expect(hasWhiteRoundedCard(t), isFalse);
      expect(find.byType(Divider), findsNWidgets(2)); // between three rows
    },
  );

  testWidgets('default: the rows are on a rounded white card', (t) async {
    await t.pumpWidget(host(false));
    expect(hasWhiteRoundedCard(t), isTrue);
    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('plain rows span the width, the line starts at the text', (
    t,
  ) async {
    await t.pumpWidget(host(true));
    final screen = t.getSize(find.byType(MaterialApp));
    final row = t.getSize(find.byType(ChatRow).first);
    expect(row.width, screen.width);
    final divider = t.widget<Divider>(find.byType(Divider).first);
    expect(divider.indent, kChatTextIndent);
  });
}
