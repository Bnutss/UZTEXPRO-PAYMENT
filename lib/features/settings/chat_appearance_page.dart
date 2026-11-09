import 'package:adaptive_platform_ui/adaptive_platform_ui.dart'
    show AdaptiveSlider;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fading_header_scaffold.dart';
import '../chat/chat_appearance_settings.dart';
import '../chat/chat_group_picker.dart' show pickGalleryPhoto;
import '../chat/chat_widgets.dart' show ChatWallpaper, kChatInk;
import 'settings_rows.dart';

/// "Chat appearance": the size of the message text and the wallpaper, with a
/// little chat above that shows both as they are chosen.
class ChatAppearancePage extends StatefulWidget {
  const ChatAppearancePage({super.key});

  @override
  State<ChatAppearancePage> createState() => _ChatAppearancePageState();
}

class _ChatAppearancePageState extends State<ChatAppearancePage> {
  final _settings = ChatAppearanceSettings.instance;

  @override
  void initState() {
    super.initState();
    _settings.load();
    _settings.addListener(_changed);
    localeNotifier.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _settings.removeListener(_changed);
    localeNotifier.removeListener(_changed);
    super.dispose();
  }

  Widget _caption(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF8A8A8E),
        fontSize: 13,
        letterSpacing: 0.2,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return FadingHeaderScaffold(
      title: s.appearanceTitle,
      background: AppColors.groupedBackground,
      body: (context, topInset) => ListView(
        padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 40),
        children: [
          _Preview(s: s, size: _settings.textSize),
          const SizedBox(height: 24),
          _caption(s.appearanceTextSize),
          _sizeCard(),
          const SizedBox(height: 24),
          _caption(s.appearanceWallpaper),
          _wallpaperCard(s),
          if (_settings.isPicture) ...[
            const SizedBox(height: 12),
            _pictureCard(s),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              s.appearanceHint,
              style: const TextStyle(color: Color(0xFF8A8A8E), fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _settings.reset();
                  },
                  child: Container(
                    alignment: Alignment.center,
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Text(
                      s.appearanceReset,
                      style: const TextStyle(
                        color: Color(0xFFFF3B30),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sizeCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Text(
            'A',
            style: TextStyle(fontSize: 14, color: Color(0xFF8A8A8E)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: AdaptiveSlider(
              min: ChatAppearanceSettings.minTextSize,
              max: ChatAppearanceSettings.maxTextSize,
              divisions:
                  (ChatAppearanceSettings.maxTextSize -
                          ChatAppearanceSettings.minTextSize)
                      .round(),
              value: _settings.textSize,
              activeColor: AppColors.brandOrange,
              onChanged: (v) {
                if (v.roundToDouble() != _settings.textSize) {
                  HapticFeedback.selectionClick();
                }
                _settings.update(size: v);
              },
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'A',
            style: TextStyle(fontSize: 24, color: Color(0xFF1C1C1E)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(
              '${_settings.textSize.round()}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF8A8A8E),
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addPhoto() async {
    HapticFeedback.selectionClick();
    final bytes = await pickGalleryPhoto(context, maxSide: 1600);
    if (bytes == null || !mounted) return;
    await _settings.setCustom(bytes);
  }

  Widget _wallpaperCard(S s) {
    final custom = _settings.customFile;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _AddTile(label: s.appearanceChoosePhoto, onTap: _addPhoto),
          if (custom != null)
            _WallpaperTile(
              choice: ChatWallpaperChoice.custom,
              file: custom,
              selected: _settings.wallpaper == ChatWallpaperChoice.custom,
              onTap: () {
                HapticFeedback.selectionClick();
                _settings.update(wallpaper: ChatWallpaperChoice.custom);
              },
            ),
          for (final c in ChatWallpaperChoice.values)
            if (c != ChatWallpaperChoice.custom)
              _WallpaperTile(
                choice: c,
                selected: _settings.wallpaper == c,
                onTap: () {
                  HapticFeedback.selectionClick();
                  _settings.update(wallpaper: c);
                },
              ),
        ],
      ),
    );
  }

  /// Blur and darkening of a picture wallpaper.
  Widget _pictureCard(S s) {
    Widget slider(
      String label,
      double value,
      double max,
      String text,
      ValueChanged<double> onChanged,
    ) {
      return Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, color: kChatInk),
            ),
          ),
          Expanded(
            child: AdaptiveSlider(
              min: 0,
              max: max,
              value: value.clamp(0, max),
              activeColor: AppColors.brandOrange,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF8A8A8E),
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          slider(
            s.appearanceBlur,
            _settings.blur,
            ChatAppearanceSettings.maxBlur,
            '${_settings.blur.round()}',
            (v) => _settings.update(blur: v),
          ),
          slider(
            s.appearanceDim,
            _settings.dim,
            ChatAppearanceSettings.maxDim,
            '${(_settings.dim * 100).round()}%',
            (v) => _settings.update(dim: v),
          ),
        ],
      ),
    );
  }
}

/// "Choose from the gallery": the first tile of the wallpapers.
class _AddTile extends StatelessWidget {
  const _AddTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _WallpaperTile.size,
        height: _WallpaperTile.size,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_photo_alternate_rounded,
              color: AppColors.brandOrange,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFF8A8A8E)),
            ),
          ],
        ),
      ),
    );
  }
}

class _WallpaperTile extends StatelessWidget {
  const _WallpaperTile({
    required this.choice,
    required this.selected,
    required this.onTap,
    this.file,
  });

  /// The person's own picture (for [ChatWallpaperChoice.custom]).
  final File? file;
  final ChatWallpaperChoice choice;
  final bool selected;
  final VoidCallback onTap;

  static const double size = 64;

  @override
  Widget build(BuildContext context) {
    final color = choice.color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.brandOrange : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (file != null)
                Image.file(
                  file!,
                  key: ValueKey(file!.path),
                  fit: BoxFit.cover,
                  cacheWidth: 200,
                )
              else if (color == null)
                Image.asset(
                  'assets/images/background.jpg',
                  fit: BoxFit.cover,
                  cacheWidth: 200,
                )
              else
                ColoredBox(color: color),
              if (selected)
                const Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.all(3),
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: AppColors.brandOrange,
                      child: Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small chat: the wallpaper and two messages, with the chosen text size.
class _Preview extends StatelessWidget {
  const _Preview({required this.s, required this.size});

  final S s;
  final double size;

  Widget _bubble(String text, {required bool mine}) {
    const big = Radius.circular(20);
    const small = Radius.circular(6);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.fromLTRB(14, 9, 12, 8),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFE1FFC7) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: big,
            topRight: big,
            bottomLeft: mine ? big : small,
            bottomRight: mine ? small : big,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: size, height: 1.28, color: kChatInk),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 190,
        child: Stack(
          children: [
            const Positioned.fill(child: ChatWallpaper()),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _bubble(s.appearancePreviewIn, mine: false),
                  const SizedBox(height: 6),
                  _bubble(s.appearancePreviewOut, mine: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
