import 'package:flutter_test/flutter_test.dart';
import 'package:uztexpro_payment/features/chat/chat_sounds.dart';

class _Player implements ChatSoundPlayer {
  final played = <String>[];
  bool fail = false;

  @override
  Future<void> play(String asset) async {
    played.add(asset);
    if (fail) throw StateError('no audio device');
  }
}

void main() {
  late _Player player;
  late DateTime now;
  late ChatSounds sounds;

  setUp(() {
    player = _Player();
    now = DateTime(2026, 11, 6, 12);
    sounds = ChatSounds(player, clock: () => now);
  });

  test('the sound files are the ones in assets/sound', () {
    expect(kSendSound, 'sound/dice.mp3');
    expect(kIncomingSound, 'sound/sound_17216.mp3');
  });

  test(
    'sending plays the send sound, an incoming message plays the other one',
    () {
      sounds.sent();
      sounds.incoming();
      expect(player.played, [kSendSound, kIncomingSound]);
    },
  );

  test(
    'a burst of incoming messages makes one sound, the next one after the pause plays again',
    () {
      sounds.incoming();
      now = now.add(const Duration(milliseconds: 200));
      sounds.incoming();
      sounds.incoming();
      expect(player.played, [kIncomingSound]);
      now = now.add(
        const Duration(milliseconds: 600),
      ); // 800 ms since the first
      sounds.incoming();
      expect(player.played, [kIncomingSound, kIncomingSound]);
    },
  );

  test('the two sounds do not hold each other back', () {
    sounds.incoming();
    sounds.sent(); // same instant, other sound
    expect(player.played, [kIncomingSound, kSendSound]);
  });

  test(
    'quick sends are all heard, only a double tap within 150 ms is merged',
    () {
      sounds.sent();
      now = now.add(const Duration(milliseconds: 100));
      sounds.sent();
      now = now.add(
        const Duration(milliseconds: 100),
      ); // 200 ms after the first one
      sounds.sent();
      expect(player.played, [kSendSound, kSendSound]);
    },
  );

  test('turned off: silent', () {
    sounds.enabled = false;
    sounds.sent();
    sounds.incoming();
    expect(player.played, isEmpty);
  });

  test('a failing player never throws into the chat', () async {
    player.fail = true;
    expect(() => sounds.sent(), returnsNormally);
    expect(() => sounds.incoming(), returnsNormally);
    await Future<void>.delayed(
      Duration.zero,
    ); // the async error is swallowed too
    expect(player.played, [kSendSound, kIncomingSound]);
  });
}
