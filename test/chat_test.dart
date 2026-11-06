import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uztexpro_payment/core/localization/app_strings.dart';
import 'package:uztexpro_payment/core/localization/locale_notifier.dart';
import 'package:uztexpro_payment/features/chat/chat_api.dart';
import 'package:uztexpro_payment/features/chat/chat_models.dart';
import 'package:uztexpro_payment/features/chat/chat_widgets.dart';

String _jwt(Map<String, dynamic> payload) {
  String enc(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${enc({'alg': 'HS256'})}.${enc(payload)}.sig';
}

void main() {
  group('models', () {
    test('conversation parses the server answer, time to local', () {
      final c = ChatConversation.fromJson({
        'id': 7,
        'peer': {
          'id': 3,
          'name': 'Anna Karimova',
          'position': 'Operator',
          'department': 'Sewing',
          'photo': null,
        },
        'last_message': {
          'id': 11,
          'conversation': 7,
          'sender': 3,
          'text': 'hi',
          'client_id': 'k',
          'created_at': '2026-11-06T15:30:27+05:00',
          'read': false,
        },
        'unread': 2,
        'updated_at': '2026-11-06T15:30:27+05:00',
      });
      expect(c.peer.subtitle, 'Operator · Sewing');
      expect(c.unread, 2);
      expect(
        c.lastMessage!.createdAt.toUtc(),
        DateTime.utc(2026, 11, 6, 10, 30, 27),
      );
      expect(c.lastMessage!.createdAt.isUtc, isFalse);
    });

    test('a chat without messages and a user without position', () {
      final c = ChatConversation.fromJson({
        'id': 1,
        'peer': {'id': 2, 'name': 'X'},
        'last_message': null,
        'unread': 0,
        'updated_at': '2026-11-06T15:30:27+05:00',
      });
      expect(c.lastMessage, isNull);
      expect(c.peer.subtitle, '');
    });
  });

  group('time label', () {
    setUp(() => localeNotifier.value = const Locale('ru'));
    final s = S.of(null);
    final now = DateTime(2026, 11, 6, 15, 0);

    test('today shows the clock', () {
      expect(chatTimeLabel(DateTime(2026, 11, 6, 9, 5), s, now: now), '09:05');
    });
    test('yesterday is a word, older is a date', () {
      expect(
        chatTimeLabel(DateTime(2026, 11, 5, 23, 59), s, now: now),
        'Вчера',
      );
      expect(
        chatTimeLabel(DateTime(2026, 10, 30, 8, 0), s, now: now),
        '30.10.26',
      );
    });
    test(
      'just after midnight: 00:10 today, 23:50 the day before is yesterday',
      () {
        final n = DateTime(2026, 11, 6, 0, 20);
        expect(chatTimeLabel(DateTime(2026, 11, 6, 0, 10), s, now: n), '00:10');
        expect(
          chatTimeLabel(DateTime(2026, 11, 5, 23, 50), s, now: n),
          'Вчера',
        );
      },
    );
  });

  group('api token', () {
    test('reads the token out of the stored login answer', () {
      final tok = _jwt({'user_id': 42});
      expect(ChatApi(jsonEncode({'token': tok})).token, tok);
      expect(ChatApi(tok).token, tok); // bare token too
    });
    test('user id comes from the JWT; garbage gives null, not a crash', () {
      expect(ChatApi(_jwt({'user_id': 42})).myId, 42);
      expect(ChatApi('not-a-jwt').myId, isNull);
      expect(ChatApi(_jwt({'no': 'id'})).myId, isNull);
    });
    test('sends the bearer header', () {
      expect(ChatApi('abc').headers, {'Authorization': 'Bearer abc'});
    });
  });
}
