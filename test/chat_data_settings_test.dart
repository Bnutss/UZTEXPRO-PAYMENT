import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uztexpro_payment/features/chat/chat_data_settings.dart';
import 'package:uztexpro_payment/features/chat/chat_media.dart';

class _Paths extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _Paths(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults keep the old behaviour: photos by themselves, the rest on a tap',
      () async {
    final s = ChatDataSettings.forTest(wifiProbe: () async => true);
    await s.load();
    expect(s.shouldAutoDownload('image'), isTrue);
    expect(s.shouldAutoDownload('video'), isFalse);
    expect(s.shouldAutoDownload('file'), isFalse);
  });

  test('the Wi-Fi and the mobile tables are separate', () async {
    var wifi = true;
    final s = ChatDataSettings.forTest(wifiProbe: () async => wifi);
    await s.load();
    s.setAuto(onWifi: true, kind: 'video', on: true);
    expect(s.shouldAutoDownload('video'), isTrue); // on Wi-Fi

    final onMobile = ChatDataSettings.forTest(wifiProbe: () async => false);
    await onMobile.load(); // reads what was saved
    expect(onMobile.shouldAutoDownload('video'), isFalse); // mobile: still off
    onMobile.setAuto(onWifi: false, kind: 'image', on: false);
    expect(onMobile.shouldAutoDownload('image'), isFalse);
    expect(wifi, isTrue);
  });

  test('an unknown network counts as mobile (the cautious side)', () async {
    final s = ChatDataSettings.forTest(wifiProbe: () async => null);
    await s.load();
    s.setAuto(onWifi: true, kind: 'file', on: true);
    expect(s.shouldAutoDownload('file'), isFalse);
  });

  test('settings are saved and read back', () async {
    final a = ChatDataSettings.forTest(wifiProbe: () async => true);
    await a.load();
    a.setAuto(onWifi: true, kind: 'video', on: true);
    a.setKeep(ChatKeepMedia.week);
    await Future<void>.delayed(Duration.zero);

    final b = ChatDataSettings.forTest(wifiProbe: () async => true);
    await b.load();
    expect(b.wifi['video'], isTrue);
    expect(b.keep, ChatKeepMedia.week);
  });

  test('"keep" ages are what the names say', () {
    expect(ChatKeepMedia.forever.age, isNull);
    expect(ChatKeepMedia.days3.age, const Duration(days: 3));
    expect(ChatKeepMedia.week.age, const Duration(days: 7));
    expect(ChatKeepMedia.month.age, const Duration(days: 30));
  });

  test('only files older than the chosen time are deleted', () async {
    final root = await Directory.systemTemp.createTemp('chat_media_test');
    PathProviderPlatform.instance = _Paths(root.path);
    await ChatMediaStore.init();
    final dir = Directory('${root.path}/chat_media');
    final old = File('${dir.path}/old.jpg')..writeAsStringSync('x');
    final fresh = File('${dir.path}/fresh.jpg')..writeAsStringSync('x');
    old.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 10)));

    final removed = await ChatMediaStore.deleteOlderThan(
      const Duration(days: 7),
    );
    expect(removed, 1);
    expect(old.existsSync(), isFalse);
    expect(fresh.existsSync(), isTrue);

    expect(await ChatMediaStore.deleteOlderThan(const Duration(days: 7)), 0);
    await root.delete(recursive: true);
  });
}
