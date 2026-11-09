import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uztexpro_payment/features/chat/chat_api.dart';
import 'package:uztexpro_payment/features/chat/chat_models.dart';
import 'package:uztexpro_payment/features/chat/chat_thread_controller.dart';
import 'package:uztexpro_payment/features/chat/chat_voice.dart';

import 'chat_fakes.dart';

void main() {
  test('downsampleWave: always [bars] values in 1..31, keeps the peaks', () {
    final wave = downsampleWave([0, 0, 1, 0, 0.5, 0], bars: 3);
    expect(wave.length, 3);
    expect(wave.every((v) => v >= 1 && v <= 31), isTrue);
    expect(wave, [1, 31, 16]); // the peak of each slice, never below 1
    expect(downsampleWave(const []).length, kWaveBars);
  });

  test('formatVoiceTime', () {
    expect(formatVoiceTime(7000), '0:07');
    expect(formatVoiceTime(723000), '12:03');
  });

  test('ChatMessage.fromJson reads a voice message and a voice quote', () {
    final m = ChatMessage.fromJson({
      'id': 5,
      'conversation': 1,
      'sender': 2,
      'text': 'Голосовое сообщение',
      'client_id': 'c',
      'created_at': '2026-01-01T10:00:00Z',
      'kind': 'voice',
      'audio': 'https://x/a.m4a',
      'duration_ms': 4200,
      'waveform': [1, 5, 31],
      'reply': {'id': 3, 'sender': 2, 'text': 'x', 'kind': 'voice'},
    });
    expect(m.isVoice, isTrue);
    expect(m.audioUrl, 'https://x/a.m4a');
    expect(m.durationMs, 4200);
    expect(m.waveform, [1, 5, 31]);
    expect(m.reply!.isVoice, isTrue);
  });

  test(
    'sendVoice shows a local copy at once and the upload replaces it',
    () async {
      final rest = FakeRest();
      final c = ChatThreadController(
        rest: rest,
        link: FakeLink(),
        peer: const ChatUser(id: 2, name: 'Peer'),
        conversationId: 9,
      );
      addTearDown(c.dispose);
      c.sendVoice('/tmp/a.m4a', 3000, const [1, 2, 3]);
      expect(c.messages.single.isVoice, isTrue);
      expect(c.messages.single.isLocal, isTrue);
      expect(c.messages.single.state, ChatSendState.sending);
      expect(c.messages.single.localAudioPath, '/tmp/a.m4a');

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(rest.groupCalls.single, startsWith('voice:9:'));
      final saved = c.messages.single;
      expect(saved.isLocal, isFalse);
      expect(saved.id, 777);
      expect(saved.state, ChatSendState.sent);
      // the file on the phone is kept: it plays without a download
      expect(saved.localAudioPath, '/tmp/a.m4a');
    },
  );

  test('ChatMessage.fromJson reads a photo with its media', () {
    final m = ChatMessage.fromJson({
      'id': 6,
      'conversation': 1,
      'sender': 2,
      'text': 'look',
      'client_id': 'c2',
      'created_at': '2026-01-01T10:00:00Z',
      'kind': 'image',
      'media': {
        'name': 'IMG.jpg',
        'size': 2048,
        'width': 800,
        'height': 600,
        'thumb': 'https://x/t.jpg',
        'available': false,
      },
    });
    expect(m.isImage, isTrue);
    expect(m.isMedia, isTrue);
    expect(m.media!.aspect, closeTo(4 / 3, 0.001));
    expect(m.media!.available, isFalse);
    expect(m.media!.thumbUrl, 'https://x/t.jpg');
    // an old message without media is not a media message
    expect(
      ChatMessage.fromJson({
        'id': 7,
        'conversation': 1,
        'sender': 2,
        'text': 't',
        'client_id': '',
        'created_at': '2026-01-01T10:00:00Z',
        'kind': 'image',
      }).isMedia,
      isFalse,
    );
  });

  test(
    'sendMedia shows the photo at once and the upload replaces it',
    () async {
      final rest = FakeRest();
      final c = ChatThreadController(
        rest: rest,
        link: FakeLink(),
        peer: const ChatUser(id: 2, name: 'Peer'),
        conversationId: 9,
      );
      addTearDown(c.dispose);
      final file = File('${Directory.systemTemp.path}/chat_media_test.jpg')
        ..writeAsBytesSync([1, 2, 3, 4]);
      addTearDown(() => file.deleteSync());

      await c.sendMedia(
        ChatUpload(
          filePath: file.path,
          kind: 'image',
          name: 'IMG.jpg',
          width: 640,
          height: 480,
          caption: 'hi',
        ),
      );
      expect(c.messages.single.isImage, isTrue);
      expect(c.messages.single.text, 'hi');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(rest.mediaCalls.single, startsWith('send:9:image:'));
      expect(c.messages.single.id, 888);
      expect(c.messages.single.state, ChatSendState.sent);
    },
  );

  test('cancelling an upload stops it and removes the message', () async {
    final rest = _HangingRest();
    final c = ChatThreadController(
      rest: rest,
      link: FakeLink(),
      peer: const ChatUser(id: 2, name: 'Peer'),
      conversationId: 9,
    );
    addTearDown(c.dispose);
    final file = File('${Directory.systemTemp.path}/chat_cancel_test.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    addTearDown(() => file.deleteSync());

    await c.sendMedia(
      ChatUpload(filePath: file.path, kind: 'image', name: 'IMG.jpg'),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.messages.single.state, ChatSendState.sending);
    expect(rest.token, isNotNull);

    c.cancelUpload(c.messages.single);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(rest.token!.isCancelled, isTrue);
    expect(c.messages, isEmpty); // gone, not "failed"
  });

  test('a failed message can be thrown away', () async {
    final rest = _FailingRest();
    final c = ChatThreadController(
      rest: rest,
      link: FakeLink(),
      peer: const ChatUser(id: 2, name: 'Peer'),
      conversationId: 9,
    );
    addTearDown(c.dispose);
    final file = File('${Directory.systemTemp.path}/chat_discard_test.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    addTearDown(() => file.deleteSync());
    await c.sendMedia(
      ChatUpload(filePath: file.path, kind: 'image', name: 'IMG.jpg'),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.messages.single.state, ChatSendState.failed);
    c.discardLocal(c.messages.single);
    expect(c.messages, isEmpty);
  });
}

/// An upload that never finishes by itself: only a cancel ends it.
class _HangingRest extends FakeRest {
  ChatCancelToken? token;

  @override
  Future<ChatMessage> sendMedia(
    int conversationId,
    ChatUpload upload,
    String clientId, {
    int? replyTo,
    int? forwardOf,
    void Function(double progress)? onProgress,
    ChatCancelToken? cancel,
  }) {
    token = cancel;
    final done = Completer<ChatMessage>();
    cancel!.onCancel(() => done.completeError(const ChatCancelled()));
    return done.future;
  }
}

class _FailingRest extends FakeRest {
  @override
  Future<ChatMessage> sendMedia(
    int conversationId,
    ChatUpload upload,
    String clientId, {
    int? replyTo,
    int? forwardOf,
    void Function(double progress)? onProgress,
    ChatCancelToken? cancel,
  }) async => throw const ChatApiException(null);
}
