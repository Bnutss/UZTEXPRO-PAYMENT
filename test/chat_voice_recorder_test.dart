import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';
import 'package:uztexpro_payment/features/chat/chat_voice.dart';
import 'package:uztexpro_payment/features/chat/chat_voice_widgets.dart';

/// A microphone that takes [startDelay] to open (the real one takes 0.3-0.8 s).
class _SlowMic extends Fake implements AudioRecorder {
  _SlowMic(this.startDelay);
  final Duration startDelay;
  final permissionRequests = <bool>[];

  @override
  Future<bool> hasPermission({bool request = true}) async {
    permissionRequests.add(request);
    return true;
  }

  @override
  Future<void> start(RecordConfig config, {required String path}) =>
      Future<void>.delayed(startDelay);

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      const Stream<Amplitude>.empty();

  @override
  Future<String?> stop() async => null;

  @override
  Future<void> dispose() async {}
}

class _Paths extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _Paths(this.dir);
  final String dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

/// Hold the microphone and let go: the voice message must be sent.
void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('voice_rec_test');
    PathProviderPlatform.instance = _Paths(tmp.path);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<VoiceClip?> holdFor(
    Duration hold, {
    required Duration micOpens,
  }) async {
    final rec = ChatVoiceRecorder(recorder: _SlowMic(micOpens));
    final started = rec.start(); // the finger goes down
    await Future<void>.delayed(hold); // ...and stays
    expect(await started, isTrue);
    final clip = await rec.finish(); // ...and lets go
    rec.dispose();
    return clip;
  }

  test(
    'an ordinary one-second hold is sent, although the mic opened slowly',
    () async {
      // The finger is down for 1.1 s; the microphone was open for only 0.5 s of
      // it. Measured from the opening that was "too short" and was thrown away.
      final clip = await holdFor(
        const Duration(milliseconds: 1100),
        micOpens: const Duration(milliseconds: 600),
      );
      expect(clip, isNotNull);
      expect(clip!.durationMs, inInclusiveRange(300, 900)); // the real sound
    },
  );

  test('a stray tap is still thrown away', () async {
    final clip = await holdFor(
      const Duration(milliseconds: 300),
      micOpens: const Duration(milliseconds: 50),
    );
    expect(clip, isNull);
  });

  test('held long enough but nothing was recorded: not sent', () async {
    // The microphone opened only at the very end of the hold.
    final clip = await holdFor(
      const Duration(milliseconds: 900),
      micOpens: const Duration(milliseconds: 880),
    );
    expect(clip, isNull);
  });

  test('warming up does not ask for the permission', () async {
    final mic = _SlowMic(Duration.zero);
    await ChatVoiceRecorder(recorder: mic).warmUp();
    expect(mic.permissionRequests, [false]);
  });

  test('the recording time is shown with hundredths, as in Telegram', () {
    expect(formatVoiceTimeFine(0), '0:00,00');
    expect(formatVoiceTimeFine(7340), '0:07,34');
    expect(formatVoiceTimeFine(7009), '0:07,00');
    expect(formatVoiceTimeFine(59999), '0:59,99');
    expect(formatVoiceTimeFine(60000), '1:00,00');
    expect(formatVoiceTimeFine(723050), '12:03,05');
    expect(formatVoiceTimeFine(-5), '0:00,00');
  });

  testWidgets('the timer of the strip runs in hundredths, frame by frame', (
    tester,
  ) async {
    final rec = ChatVoiceRecorder(
      recorder: _SlowMic(const Duration(milliseconds: 10)),
    );
    await tester.runAsync(() async {
      expect(await rec.start(), isTrue);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VoiceRecordingStrip(recorder: rec, rightPad: 10)),
      ),
    );
    final shape = RegExp(r'^\d+:\d\d,\d\d$');
    String shown() => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere(shape.hasMatch);
    final seen = <String>{};
    for (var i = 0; i < 6; i++) {
      // The recorder's own clock is real time: let some pass between frames.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      seen.add(shown());
    }
    // The time moves, and it moves in hundredths: with the recorder's old
    // 100 ms beat every value would end in 0 ("0:00,10", "0:00,20"...).
    expect(seen.length, greaterThanOrEqualTo(2));
    expect(seen.any((v) => !v.endsWith('0')), isTrue);
    await tester.runAsync(rec.cancel);
    rec.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('locked: a text "Отмена" in the bar cancels the recording', (
    tester,
  ) async {
    final rec = ChatVoiceRecorder(
      recorder: _SlowMic(const Duration(milliseconds: 10)),
    );
    await tester.runAsync(() async {
      expect(await rec.start(), isTrue);
    });
    Future<void> pumpStrip() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VoiceRecordingStrip(recorder: rec, rightPad: 10)),
      ),
    );

    // Held, not locked yet: the hint to slide, no Cancel button.
    await pumpStrip();
    expect(find.text('Отмена'), findsNothing);

    // Slid up: locked. The bar shows Cancel (as in Telegram), no trash icon.
    rec.drag(0, 100);
    expect(rec.locked, isTrue);
    await tester.pump();
    expect(find.text('Отмена'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(rec.phase, RecorderPhase.idle); // thrown away
    rec.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
