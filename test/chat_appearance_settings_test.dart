import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uztexpro_payment/features/chat/chat_appearance_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('blur and dimming are kept within their limits', () {
    final s = ChatAppearanceSettings.forTest();
    s.update(blur: 99, dim: 5);
    expect(s.blur, ChatAppearanceSettings.maxBlur);
    expect(s.dim, ChatAppearanceSettings.maxDim);
    s.update(blur: -3, dim: -1);
    expect(s.blur, 0);
    expect(s.dim, 0);
  });

  test('an own wallpaper that is gone falls back to the app picture', () {
    final s = ChatAppearanceSettings.forTest();
    s.update(wallpaper: ChatWallpaperChoice.custom);
    expect(s.hasCustom, isFalse);
    expect(s.effectiveWallpaper, ChatWallpaperChoice.picture);
    expect(s.isPicture, isTrue);
    expect(s.wallpaperBase, ChatAppearanceSettings.pictureBase);
  });

  test('a plain colour is not a picture; reset restores the defaults', () {
    final s = ChatAppearanceSettings.forTest();
    s.update(wallpaper: ChatWallpaperChoice.mint, blur: 10, dim: 0.3);
    expect(s.isPicture, isFalse);
    s.reset();
    expect(s.wallpaper, ChatWallpaperChoice.picture);
    expect(s.blur, ChatAppearanceSettings.defaultBlur);
    expect(s.dim, ChatAppearanceSettings.defaultDim);
  });
}
