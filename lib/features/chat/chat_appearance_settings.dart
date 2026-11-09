import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the chat's wallpaper is: the app's picture, the person's own photo, or
/// a plain colour.
enum ChatWallpaperChoice {
  picture(null),

  /// A photo the person picked from the gallery.
  custom(null),
  paper(Color(0xFFFFF1E6)),
  sand(Color(0xFFF2E8D5)),
  mint(Color(0xFFDDEFE0)),
  sky(Color(0xFFDCEAF7)),
  lavender(Color(0xFFE8E0F3)),
  rose(Color(0xFFF7DEE3)),
  gray(Color(0xFFE6E6EA));

  const ChatWallpaperChoice(this.color);

  /// The plain colour, null for a picture (the app's or the person's own).
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
  static const _kBlur = 'chat_wallpaper_blur';
  static const _kDim = 'chat_wallpaper_dim';
  static const _kCustomFile = 'chat_wallpaper_file';
  static const _kCustomBase = 'chat_wallpaper_base';

  static const double defaultTextSize = 17;
  static const double minTextSize = 13;
  static const double maxTextSize = 26;

  /// The colour of the paper behind the default picture.
  static const Color pictureBase = Color(0xFFFFF1E6);

  /// How soft a picture wallpaper is (blur radius in logical pixels) and how
  /// much it is darkened (0 to 1). The defaults are what the app's own picture
  /// always looked like.
  static const double defaultBlur = 3;
  static const double maxBlur = 24;
  static const double defaultDim = 0;
  static const double maxDim = 0.6;

  double textSize = defaultTextSize;
  ChatWallpaperChoice wallpaper = ChatWallpaperChoice.picture;
  double blur = defaultBlur;
  double dim = defaultDim;

  /// The person's own wallpaper: the file name in the documents folder (a new
  /// name for each picture, so a changed picture is never served from the
  /// image cache) and its average colour.
  String? _customName;
  Color? _customBase;
  Directory? _dir;

  bool _loaded = false;

  /// The person's wallpaper file, null when there is none (or it is gone).
  File? get customFile {
    final name = _customName;
    final dir = _dir;
    if (name == null || dir == null) return null;
    final f = File('${dir.path}/$name');
    return f.existsSync() ? f : null;
  }

  bool get hasCustom => customFile != null;

  /// What is really drawn: a missing own file falls back to the app's picture.
  ChatWallpaperChoice get effectiveWallpaper =>
      wallpaper == ChatWallpaperChoice.custom && !hasCustom
      ? ChatWallpaperChoice.picture
      : wallpaper;

  /// Whether the wallpaper is a picture (so blur and darkening apply).
  bool get isPicture => effectiveWallpaper.color == null;

  /// The colour the screen shows behind (or instead of) the wallpaper.
  Color get wallpaperBase => effectiveWallpaper == ChatWallpaperChoice.custom
      ? (_customBase ?? pictureBase)
      : (wallpaper.color ?? pictureBase);

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
      blur = (p.getDouble(_kBlur) ?? defaultBlur).clamp(0, maxBlur);
      dim = (p.getDouble(_kDim) ?? defaultDim).clamp(0, maxDim);
      _customName = p.getString(_kCustomFile);
      final base = p.getInt(_kCustomBase);
      _customBase = base == null ? null : Color(base);
      try {
        _dir = await getApplicationDocumentsDirectory();
      } catch (_) {}
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(_kSize, textSize);
      await p.setString(_kWallpaper, wallpaper.name);
      await p.setDouble(_kBlur, blur);
      await p.setDouble(_kDim, dim);
      final name = _customName;
      if (name == null) {
        await p.remove(_kCustomFile);
        await p.remove(_kCustomBase);
      } else {
        await p.setString(_kCustomFile, name);
        final base = _customBase;
        if (base != null) await p.setInt(_kCustomBase, base.toARGB32());
      }
    } catch (_) {}
  }

  void update({
    double? size,
    ChatWallpaperChoice? wallpaper,
    double? blur,
    double? dim,
  }) {
    if (size != null) {
      textSize = size.roundToDouble().clamp(minTextSize, maxTextSize);
    }
    this.wallpaper = wallpaper ?? this.wallpaper;
    if (blur != null) this.blur = blur.clamp(0, maxBlur);
    if (dim != null) this.dim = dim.clamp(0, maxDim);
    notifyListeners();
    _save();
  }

  /// Makes a photo from the gallery (JPEG bytes) the wallpaper.
  Future<void> setCustom(Uint8List bytes) async {
    try {
      _dir ??= await getApplicationDocumentsDirectory();
      final name =
          'chat_wallpaper_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File('${_dir!.path}/$name').writeAsBytes(bytes, flush: true);
      final old = customFile;
      _customName = name;
      _customBase = await _averageColour(bytes);
      if (old != null) {
        try {
          await old.delete();
        } catch (_) {}
      }
      wallpaper = ChatWallpaperChoice.custom;
      notifyListeners();
      _save();
    } catch (_) {}
  }

  /// The photo shrunk to one pixel: its average colour, which the screen shows
  /// behind the wallpaper.
  static Future<Color?> _averageColour(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 1,
        targetHeight: 1,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData();
      if (data == null) return null;
      return Color.fromARGB(
        255,
        data.getUint8(0),
        data.getUint8(1),
        data.getUint8(2),
      );
    } catch (_) {
      return null;
    }
  }

  void reset() {
    final old = customFile;
    _customName = null;
    _customBase = null;
    if (old != null) {
      try {
        old.deleteSync();
      } catch (_) {}
    }
    update(
      size: defaultTextSize,
      wallpaper: ChatWallpaperChoice.picture,
      blur: defaultBlur,
      dim: defaultDim,
    );
  }
}
