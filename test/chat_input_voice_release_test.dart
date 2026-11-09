import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';
import 'package:uztexpro_payment/features/chat/chat_glass.dart';
import 'package:uztexpro_payment/features/chat/chat_voice.dart';
import 'package:uztexpro_payment/features/chat/chat_voice_widgets.dart';

/// A microphone that takes [startDelay] to open (the real one takes 0.3-0.8 s).
class _Mic extends Fake implements AudioRecorder {
  _Mic(this.startDelay);
  final Duration startDelay;

  @override
  Future<bool> hasPermission({bool request = true}) async => true;
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

/// In Telegram: hold the microphone, let go, and the voice message goes by
/// itself. This runs that through the real input bar.
void main() {
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('voice_input_test');
    PathProviderPlatform.instance = _Paths(tmp.path);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<ChatVoiceRecorder> pumpBar(
    WidgetTester tester,
    List<VoiceClip> sent, {
    required Duration micOpens,
    bool canSend = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final rec = ChatVoiceRecorder(recorder: _Mic(micOpens));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ChatInputBar(
              controller: TextEditingController(),
              hint: 'Сообщение',
              canSend: canSend,
              onSend: () {},
              onVoice: sent.add,
              // The paperclip, as in the real chat: it is hidden while a voice
              // message is recorded, which used to rebuild the microphone.
              onAttach: () {},
              recorder: rec,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return rec;
  }

  /// The finger stays on the microphone for [hold], frames being drawn.
  Future<TestGesture> holdMic(WidgetTester tester, Duration hold) async {
    final g = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.mic_rounded)),
    );
    await tester.pump();
    final steps = hold.inMilliseconds ~/ 50;
    for (var i = 0; i < steps; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    return g;
  }

  Future<void> letGo(WidgetTester tester, TestGesture g) async {
    await g.up();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
  }

  testWidgets('hold the microphone for a second and let go: it is sent', (
    tester,
  ) async {
    final sent = <VoiceClip>[];
    final rec = await pumpBar(
      tester,
      sent,
      micOpens: const Duration(milliseconds: 500),
    );
    // An ordinary hold: about a second. Half of it the microphone was opening.
    final g = await holdMic(tester, const Duration(milliseconds: 1000));
    expect(rec.phase, RecorderPhase.holding); // it was recording meanwhile
    await letGo(tester, g);
    expect(sent, hasLength(1));
    expect(rec.phase, RecorderPhase.idle);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long hold is sent too', (tester) async {
    final sent = <VoiceClip>[];
    await pumpBar(tester, sent, micOpens: const Duration(milliseconds: 100));
    final g = await holdMic(tester, const Duration(milliseconds: 2500));
    await letGo(tester, g);
    expect(sent, hasLength(1));
    expect(sent.single.durationMs, greaterThan(2000));
  });

  testWidgets('a stray tap sends nothing and says how to record', (
    tester,
  ) async {
    final sent = <VoiceClip>[];
    await pumpBar(tester, sent, micOpens: const Duration(milliseconds: 50));
    final g = await holdMic(tester, const Duration(milliseconds: 250));
    await letGo(tester, g);
    expect(sent, isEmpty);
    expect(find.text('Удерживайте, чтобы записать голосовое'), findsOneWidget);
  });

  testWidgets('the microphone button is the same one all through the hold', (
    tester,
  ) async {
    final sent = <VoiceClip>[];
    final rec = await pumpBar(
      tester,
      sent,
      micOpens: const Duration(milliseconds: 100),
    );
    expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
    final before = tester.element(find.byType(VoiceMicButton));

    final g = await holdMic(tester, const Duration(milliseconds: 600));
    expect(rec.phase, RecorderPhase.holding);
    // Recording: the paperclip has gone...
    expect(find.byIcon(Icons.attach_file_rounded), findsNothing);
    // ...and the button under the finger was not thrown away and rebuilt (the
    // new one knew nothing of the press, the old one dropped the recording).
    expect(
      identical(tester.element(find.byType(VoiceMicButton)), before),
      isTrue,
    );
    await letGo(tester, g);
  });
}
