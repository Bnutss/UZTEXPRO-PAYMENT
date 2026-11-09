import 'package:flutter_test/flutter_test.dart';
import 'package:uztexpro_payment/features/chat/chat_device_model.dart';
import 'package:uztexpro_payment/features/chat/chat_models.dart';
import 'package:uztexpro_payment/features/chat/chat_session.dart';

void main() {
  group('phone model names', () {
    test('Apple codes become the name on the box', () {
      expect(iosModelName('iPhone18,2'), 'iPhone 17 Pro Max');
      expect(iosModelName('iPhone17,3'), 'iPhone 16');
      expect(iosModelName('iPhone14,6'), 'iPhone SE (3rd generation)');
    });

    test('a code that is not known falls back, an iPad is an iPad', () {
      expect(iosModelName('iPhone99,1'), 'iPhone');
      expect(iosModelName('iPhone99,1', fallback: 'iPhone X'), 'iPhone X');
      expect(iosModelName('iPad14,3'), 'iPad');
      expect(iosModelName('arm64', fallback: 'iPhone'), 'iPhone'); // simulator
    });

    test('Android: the maker once, capitalised', () {
      expect(androidModelName('samsung', 'SM-S918B'), 'Samsung SM-S918B');
      expect(androidModelName('Google', 'Pixel 8'), 'Google Pixel 8');
      expect(androidModelName('HUAWEI', 'HUAWEI P30'), 'HUAWEI P30');
      expect(androidModelName('', 'X1'), 'X1');
    });
  });

  group('what the Devices screen calls a phone', () {
    ChatDeviceInfo info({
      String model = '',
      String name = '',
      String platform = 'ios',
      String os = '',
      String app = '',
    }) => ChatDeviceInfo(
      id: 1,
      platform: platform,
      name: name,
      model: model,
      osVersion: os,
      appVersion: app,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      current: false,
    );

    test('the model first, then the old name, then the platform', () {
      expect(info(model: 'iPhone 17 Pro Max', name: 'old').title, 'iPhone 17 Pro Max');
      expect(info(name: 'iOS 26.5').title, 'iOS 26.5');
      expect(info().title, 'iPhone');
      expect(info(platform: 'android').title, 'Android');
    });

    test('the software line has what is known', () {
      expect(info(os: 'iOS 26.5', app: '1.2.9').software, 'UztexPro 1.2.9 · iOS 26.5');
      expect(info(os: 'iOS 26.5').software, 'iOS 26.5');
      expect(info().software, '');
    });

    test('it reads the new fields from the server', () {
      final d = ChatDeviceInfo.fromJson({
        'id': 3,
        'platform': 'android',
        'name': '',
        'model': 'Samsung SM-S918B',
        'os_version': 'Android 14',
        'app_version': '1.2.9',
        'ip': '84.54.1.2',
        'created_at': '2026-11-01T09:00:00+05:00',
        'updated_at': '2026-11-09T12:30:00+05:00',
        'current': true,
      });
      expect(d.model, 'Samsung SM-S918B');
      expect(d.ip, '84.54.1.2');
      expect(d.current, isTrue);
    });
  });

  group('a terminated session', () {
    tearDown(() {
      ChatSession.onTerminated = null;
      ChatSession.reset();
      ChatSession.clear();
    });

    test('signs out once, however many requests are turned away', () {
      var n = 0;
      ChatSession.onTerminated = () => n++;
      ChatSession.reset();
      ChatSession.terminated();
      ChatSession.terminated();
      ChatSession.terminated();
      expect(n, 1);
    });

    test('a new sign-in counts again', () {
      var n = 0;
      ChatSession.onTerminated = () => n++;
      ChatSession.reset();
      ChatSession.terminated();
      ChatSession.reset();
      ChatSession.terminated();
      expect(n, 2);
    });

    test('signing out forgets the phone', () {
      ChatSession.deviceToken = 'abc';
      ChatSession.deviceId = 4;
      ChatSession.clear();
      expect(ChatSession.deviceToken, isNull);
      expect(ChatSession.deviceId, isNull);
    });
  });
}
