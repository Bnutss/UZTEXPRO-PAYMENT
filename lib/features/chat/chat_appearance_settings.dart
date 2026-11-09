import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the chat's wallpaper is: the app's picture, or a plain colour.
enum ChatWallpaperChoice {
  picture(null),
  paper(Color(0xFFFFF1E6)),
  sand(Color(0xFFF2E8D5)),
  mint(Color(0xFFDDEFE0)),
  sky(Color(0xFFDCEAF7)),
  lavender(Color(0xFFE8E0F3)),
  rose(Color(0xFFF7DEE3)),
  gray(Color(0xFFE6E6EA));

  const ChatWallpaperChoice(this.color);

  /// The plain colour, null for the picture.
  final Color? color;

  static ChatWallpaperChoice parse(String? name) {
    for (final c in values) {
      if (c.name == name) return c;
    }
    return picture;
  }
}

/// How the chat looks: the size of the message text and the wallpaper. Kept on
/// the phone, applied to every chat and group.
class ChatAppearanceSettings extends ChangeNotifier {
  ChatAppearanceSettings._();

  static final ChatAppearanceSettings instance = ChatAppearanceSettings._();

  /// For tests: a fresh object that does not touch the shared one.
  @visibleForTesting
  factory ChatAppearanceSettings.forTest() = ChatAppearanceSettings._;

  static const _kSize = 'chat_text_size';
  static const _kWallpaper = 'chat_wallpaper';

  static const double defaultTextSize = 17;
  static const double minTextSize = 13;
  static const double maxTextSize = 26;

  /// The colour of the paper behind the default picture.
  static const Color pictureBase = Color(0xFFFFF1E6);

  double textSize = defaultTextSize;
  ChatWallpaperChoice wallpaper = ChatWallpaperChoice.picture;

  bool _loaded = false;

  /// The colour the screen shows behind (or instead of) the wallpaper.
  Color get wallpaperBase => wallpaper.color ?? pictureBase;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      textSize = (p.getDouble(_kSize) ?? defaultTextSize).clamp(
        minTextSize,
        maxTextSize,
      );
      wallpaper = ChatWallpaperChoice.parse(p.getString(_kWallpaper));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(_kSize, textSize);
      await p.setString(_kWallpaper, wallpaper.name);
    } catch (_) {}
  }

  void update({double? size, ChatWallpaperChoice? wallpaper}) {
    if (size != null) {
      textSize = size.roundToDouble().clamp(minTextSize, maxTextSize);
    }
    this.wallpaper = wallpaper ?? this.wallpaper;
    notifyListeners();
    _save();
  }

  void reset() =>
      update(size: defaultTextSize, wallpaper: ChatWallpaperChoice.picture);
}
