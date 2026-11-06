import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uztexpro_payment/core/localization/locale_notifier.dart';
import 'package:uztexpro_payment/features/chat/chat_sounds.dart';
import 'package:uztexpro_payment/features/chat/chat_thread_page.dart';
import 'package:uztexpro_payment/features/chat/chat_widgets.dart'
    show ChatWallpaper;

import 'chat_fakes.dart';

Future<void> settle(WidgetTester t) async {
  // Not pumpAndSettle: the loader animates forever.
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

class _Player implements ChatSoundPlayer {
  final played = <String>[];
  @override
  Future<void> play(String asset) async => played.add(asset);
}

Future<void> open(
  WidgetTester t,
  FakeRest rest,
  FakeLink link, {
  int? conv = convId,
  ChatSounds? sounds,
}) async {
  localeNotifier.value = const Locale('ru');
  await t.pumpWidget(
    MaterialApp(
      home: ChatThreadPage(
        api: rest,
        link: link,
        peer: peer,
        sounds: sounds,
        conversationId: conv,
      ),
    ),
  );
  await settle(t);
}

void main() {
  testWidgets(
    'shows the history with both senders, a day chip and the peer in the header',
    (t) async {
      final now = DateTime.now();
      final rest = FakeRest()
        ..store.addAll([
          ChatMessageX.at(
            1,
            peerId,
            'Hello there',
            now.subtract(const Duration(days: 3)),
          ),
          ChatMessageX.at(
            2,
            meId,
            'Hi Anna',
            now.subtract(const Duration(minutes: 5)),
          ),
          ChatMessageX.at(
            3,
            peerId,
            'How are you?',
            now.subtract(const Duration(minutes: 1)),
          ),
        ]);
      final link = FakeLink();
      await open(t, rest, link);

      expect(find.text('Anna'), findsOneWidget); // header
      expect(find.text('Hello there'), findsOneWidget);
      expect(find.text('Hi Anna'), findsOneWidget);
      expect(find.text('How are you?'), findsOneWidget);
      expect(find.text('Сегодня'), findsOneWidget); // chip for today's messages
      expect(
        find.byIcon(Icons.done_rounded),
        findsOneWidget,
      ); // my message: sent, not read
      expect(link.readCalls.single, [
        convId,
        3,
      ]); // the peer's last one was marked read
    },
  );

  testWidgets('an empty chat invites to write first', (t) async {
    await open(t, FakeRest(), FakeLink());
    expect(find.textContaining('Напишите первым'), findsOneWidget);
  });

  testWidgets(
    'an empty chat: our chats icon and the text are centred in the free area',
    (t) async {
      await open(t, FakeRest(), FakeLink());
      final screen = t.getSize(find.byType(MaterialApp));
      final icon = t.getCenter(find.byType(SvgPicture));
      final text = t.getCenter(find.textContaining('Напишите первым'));
      expect(icon.dx, closeTo(screen.width / 2, 1));
      expect(text.dx, closeTo(screen.width / 2, 1));
      // The icon sits above the text, and the pair is in the middle band of the
      // screen (between the header and the input), not pushed to the top.
      expect(icon.dy, lessThan(text.dy));
      final mid = (icon.dy + text.dy) / 2;
      expect(mid, greaterThan(screen.height * 0.3));
      expect(mid, lessThan(screen.height * 0.6));
    },
  );

  testWidgets(
    'the messages run down to the screen edge, under the input bar (no block below them)',
    (t) async {
      final now = DateTime.now();
      final rest = FakeRest()
        ..store.addAll([
          for (var i = 1; i <= 30; i++)
            ChatMessageX.at(
              i,
              i.isEven ? meId : peerId,
              'message number $i',
              now.subtract(Duration(minutes: 40 - i)),
            ),
        ]);
      await open(t, rest, FakeLink());
      final screen = t.getSize(find.byType(MaterialApp));
      final list = t.getRect(find.byType(ListView));
      final inputTop = t.getTopLeft(find.byType(TextField)).dy;

      expect(
        list.bottom,
        screen.height,
      ); // fills the whole area, to the very bottom
      expect(list.bottom, greaterThan(inputTop)); // it runs UNDER the input bar
      // ... while the newest message rests above the input, not hidden behind it.
      final newest = t.getBottomLeft(find.text('message number 30')).dy;
      expect(newest, lessThanOrEqualTo(inputTop));
    },
  );

  testWidgets('a taller input (several lines) lifts the messages with it', (
    t,
  ) async {
    final now = DateTime.now();
    final rest = FakeRest()
      ..store.addAll([
        ChatMessageX.at(
          1,
          peerId,
          'last one',
          now.subtract(const Duration(minutes: 1)),
        ),
      ]);
    await open(t, rest, FakeLink());
    final before = t.getBottomLeft(find.text('last one')).dy;

    await t.enterText(
      find.byType(TextField),
      'line one\nline two\nline three\nline four',
    );
    await settle(t);
    final after = t.getBottomLeft(find.text('last one')).dy;
    expect(
      after,
      lessThan(before),
    ); // moved up: the list keeps clear of the taller bar
  });

  testWidgets(
    'the wallpaper is behind the chat, blurred, and does not move with the content',
    (t) async {
      await open(t, FakeRest(), FakeLink());
      expect(find.byType(ChatWallpaper), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ChatWallpaper),
          matching: find.byType(ImageFiltered),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ChatWallpaper),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      // It fills the whole screen, under the header too.
      expect(
        t.getSize(find.byType(ChatWallpaper)),
        t.getSize(find.byType(MaterialApp)),
      );
    },
  );

  testWidgets(
    'send: shows at once with a clock, becomes a tick on the echo, input cleared',
    (t) async {
      final rest = FakeRest();
      final link = FakeLink();
      await open(t, rest, link);

      await t.enterText(find.byType(TextField), 'Hello Anna');
      await t.pump();
      await t.tap(find.byIcon(Icons.arrow_upward_rounded));
      await settle(t);

      expect(find.text('Hello Anna'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget); // sending
      expect(
        (t.widget(find.byType(TextField)) as TextField).controller!.text,
        isEmpty,
      );

      final cid = link.sent.single['client_id'] as String;
      link.emit('message', json(msg(77, meId, 'Hello Anna', cid: cid)));
      await settle(t);
      expect(find.text('Hello Anna'), findsOneWidget); // still one bubble
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
      expect(find.byIcon(Icons.done_rounded), findsOneWidget);

      link.emit('read', {
        'conversation': convId,
        'reader': peerId,
        'up_to': 77,
      });
      await settle(t);
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget); // read
    },
  );

  testWidgets(
    'sending plays the "sent" sound once; blank input plays nothing',
    (t) async {
      final player = _Player();
      final link = FakeLink();
      await open(t, FakeRest(), link, sounds: ChatSounds(player));

      await t.enterText(find.byType(TextField), '   ');
      await t.pump();
      await t.tap(find.byIcon(Icons.arrow_upward_rounded));
      await settle(t);
      expect(player.played, isEmpty);

      await t.enterText(find.byType(TextField), 'Hello');
      await t.pump();
      await t.tap(find.byIcon(Icons.arrow_upward_rounded));
      await settle(t);
      expect(player.played, [kSendSound]);
      expect(link.sent.single['text'], 'Hello');
    },
  );

  testWidgets('the send button does nothing for blank input', (t) async {
    final link = FakeLink();
    await open(t, FakeRest(), link);
    await t.enterText(find.byType(TextField), '   ');
    await t.pump();
    await t.tap(find.byIcon(Icons.arrow_upward_rounded));
    await settle(t);
    expect(link.sent, isEmpty);
  });

  testWidgets(
    'a live message from the peer appears; "typing…" and "Connecting…" show in the header',
    (t) async {
      final link = FakeLink();
      await open(t, FakeRest(), link);

      link.emit('message', json(msg(90, peerId, 'Live hello')));
      await settle(t);
      expect(find.text('Live hello'), findsOneWidget);

      link.emit('typing', {'conversation': convId, 'user': peerId});
      await settle(t);
      expect(find.text('печатает…'), findsOneWidget);

      link.online = false;
      await settle(t);
      expect(find.text('Подключение…'), findsOneWidget);
    },
  );

  testWidgets(
    'a message that could not be sent is marked and a tap retries it',
    (t) async {
      final rest = FakeRest()..failSend = true;
      final link = FakeLink()..online = false;
      await open(t, rest, link);

      await t.enterText(find.byType(TextField), 'Will fail');
      await t.pump();
      await t.tap(find.byIcon(Icons.arrow_upward_rounded));
      await settle(t);
      expect(
        find.text('Не отправлено. Нажмите, чтобы повторить'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);

      rest.failSend = false;
      await t.tap(find.text('Will fail'));
      await settle(t);
      expect(
        find.text('Не отправлено. Нажмите, чтобы повторить'),
        findsNothing,
      );
      expect(find.byIcon(Icons.done_rounded), findsOneWidget);
      expect(rest.store.single.text, 'Will fail');
    },
  );

  testWidgets(
    'opened from a contact (no chat id): the screen is there at once and a message goes out "to" the user',
    (t) async {
      final rest = FakeRest();
      final link = FakeLink();
      await open(t, rest, link, conv: null);
      expect(find.text('Anna'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'Hi');
      await t.pump();
      await t.tap(find.byIcon(Icons.arrow_upward_rounded));
      await settle(t);
      expect(find.text('Hi'), findsOneWidget);
      expect(
        link.sent.single['to'] == peerId ||
            link.sent.single['conversation'] == convId,
        isTrue,
      );
    },
  );
}
