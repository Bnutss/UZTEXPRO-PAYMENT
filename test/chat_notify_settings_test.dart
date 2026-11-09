import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uztexpro_payment/features/chat/chat_notify_settings.dart';
import 'package:uztexpro_payment/features/chat/chat_sounds.dart';

class _Player implements ChatSoundPlayer {
  final played = <String>[];

  @override
  Future<void> play(String asset) async => played.add(asset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Player player;
  late ChatNotifySettings settings;
  late ChatSounds sounds;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    player = _Player();
    settings = ChatNotifySettings.forTest();
    sounds = ChatSounds(
      player,
      settings: settings,
      sentGap: Duration.zero,
      incomingGap: Duration.zero,
    );
  });

  test('defaults: the usual sounds', () {
    sounds.sent();
    sounds.incoming();
    expect(player.played, ['sound/dice.mp3', 'sound/sound_17216.mp3']);
  });

  test('in-app sounds off: nothing plays', () {
    settings.update(sounds: false);
    sounds.sent();
    sounds.incoming();
    expect(player.played, isEmpty);
  });

  test('a chosen sound is the one that plays, for each direction', () {
    settings.update(
      incoming: ChatSoundChoice.telegram,
      sent: ChatSoundChoice.standard,
    );
    sounds.incoming();
    sounds.sent();
    expect(player.played, [
      'sound/telegram_soundin.mp3',
      'sound/sound_17216.mp3',
    ]);
  });

  test('"none" is silent for that direction only', () {
    settings.update(incoming: ChatSoundChoice.none);
    sounds.incoming();
    sounds.sent();
    expect(player.played, ['sound/dice.mp3']);
  });

  test('preview plays even with in-app sounds off', () {
    settings.update(sounds: false);
    sounds.preview(ChatSoundChoice.telegram);
    expect(player.played, ['sound/telegram_soundin.mp3']);
  });

  test('settings are saved and read back; reset restores the defaults', () async {
    settings.update(
      sounds: false,
      vibrate: false,
      preview: false,
      incoming: ChatSoundChoice.dice,
      sent: ChatSoundChoice.none,
    );
    await Future<void>.delayed(Duration.zero);

    final again = ChatNotifySettings.forTest();
    await again.load();
    expect(again.inAppSounds, isFalse);
    expect(again.inAppVibrate, isFalse);
    expect(again.inAppPreview, isFalse);
    expect(again.incomingSound, ChatSoundChoice.dice);
    expect(again.sentSound, ChatSoundChoice.none);

    again.reset();
    expect(again.inAppSounds, isTrue);
    expect(again.incomingSound, ChatNotifySettings.defaultIncoming);
    expect(again.sentSound, ChatNotifySettings.defaultSent);
  });

  test('an unknown saved sound falls back to the default', () async {
    SharedPreferences.setMockInitialValues({'chat_notify_incoming': 'gone'});
    final s = ChatNotifySettings.forTest();
    await s.load();
    expect(s.incomingSound, ChatNotifySettings.defaultIncoming);
  });
}
