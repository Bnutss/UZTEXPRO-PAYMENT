import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uztexpro_payment/core/localization/locale_notifier.dart';
import 'package:uztexpro_payment/features/chat/chat_api.dart';
import 'package:uztexpro_payment/features/chat/chat_media_preview.dart';

void main() {
  testWidgets('the preview hands back each upload with its own caption', (
    t,
  ) async {
    localeNotifier.value = const Locale('ru');
    List<ChatUpload>? result;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<List<ChatUpload>>(
                MaterialPageRoute(
                  builder: (_) => const MediaPreviewPage(
                    uploads: [
                      ChatUpload(
                        filePath: '/a.mp4',
                        kind: 'video',
                        name: 'a.mp4',
                      ),
                      ChatUpload(
                        filePath: '/b.mp4',
                        kind: 'video',
                        name: 'b.mp4',
                      ),
                    ],
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'first');
    await t.drag(find.byType(PageView), const Offset(-600, 0));
    await t.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'second');
    await t.tap(find.byIcon(Icons.arrow_upward_rounded));
    await t.pumpAndSettle();

    expect(result!.map((u) => u.caption), ['first', 'second']);
    expect(result!.map((u) => u.name), ['a.mp4', 'b.mp4']);
  });

  testWidgets('removing the only item closes the preview with nothing', (
    t,
  ) async {
    localeNotifier.value = const Locale('ru');
    List<ChatUpload>? result = [];
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<List<ChatUpload>>(
                MaterialPageRoute(
                  builder: (_) => const MediaPreviewPage(
                    uploads: [
                      ChatUpload(
                        filePath: '/a.mp4',
                        kind: 'video',
                        name: 'a.mp4',
                      ),
                    ],
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.delete_outline_rounded));
    await t.pumpAndSettle();
    expect(result, isNull);
  });
}
