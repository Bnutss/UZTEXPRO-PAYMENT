import 'package:flutter_test/flutter_test.dart';
import 'package:uztexpro_payment/features/chat/chat_models.dart';

void main() {
  test('missing or odd values mean "on" (a new account has everything on)', () {
    final n = ChatServerNotify.fromJson({});
    expect(n.toJson().values.every((v) => v), isTrue);
    expect(ChatServerNotify.fromJson({'group_sound': false}).groupSound, isFalse);
  });

  test('a change touches only the chosen kind of chat', () {
    const n = ChatServerNotify();
    final off = n.with_(group: true, enabled: false);
    expect(off.groupEnabled, isFalse);
    expect(off.privateEnabled, isTrue);
    final quiet = n.with_(group: false, sound: false, preview: false);
    expect(quiet.privateSound, isFalse);
    expect(quiet.privatePreview, isFalse);
    expect(quiet.groupSound, isTrue);
    expect(quiet.groupPreview, isTrue);
  });

  test('it is sent as the server expects it', () {
    final json = const ChatServerNotify(groupPreview: false).toJson();
    expect(json.keys, containsAll([
      'private_enabled', 'private_preview', 'private_sound',
      'group_enabled', 'group_preview', 'group_sound',
    ]));
    expect(json['group_preview'], isFalse);
  });
}
