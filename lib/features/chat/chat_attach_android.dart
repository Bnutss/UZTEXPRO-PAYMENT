import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/localization/app_strings.dart';
import 'chat_widgets.dart';

/// What the person chose in the Android attach sheet.
enum AttachAction { gallery, camera, video, file }

class AttachChoice {
  const AttachChoice.action(AttachAction this.action) : paths = const [];
  const AttachChoice.media(this.paths) : action = null;

  final AttachAction? action;

  /// Photos / videos ticked in the grid of recents.
  final List<String> paths;
}

const _kAccent = Color(0xFF3390EC);
const _kMax = 10;

/// The attach sheet of Telegram for Android: a grid of the latest photos and
/// videos (tick several, with numbers), a camera tile first, and a row of
/// sources below (Gallery, Camera, Video, File).
Future<AttachChoice?> showAttachSheetAndroid(BuildContext context) {
  return showModalBottomSheet<AttachChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AttachSheet(),
  );
}

class _AttachSheet extends StatefulWidget {
  const _AttachSheet();

  @override
  State<_AttachSheet> createState() => _AttachSheetState();
}

class _AttachSheetState extends State<_AttachSheet> {
  List<AssetEntity> _assets = [];
  final List<AssetEntity> _picked = [];
  bool _loading = true;
  bool _denied = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final perm = await PhotoManager.requestPermissionExtend();
      if (!perm.hasAccess) {
        if (mounted) {
          setState(() {
            _loading = false;
            _denied = true;
          });
        }
        return;
      }
      final albums = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: RequestType.common,
      );
      final list = albums.isEmpty
          ? <AssetEntity>[]
          : await albums.first.getAssetListRange(start: 0, end: 90);
      if (!mounted) return;
      setState(() {
        _assets = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
          setState(() {
            _loading = false;
            _denied = true;
          });
        }
    }
  }

  void _toggle(AssetEntity a) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_picked.remove(a)) {
        if (_picked.length >= _kMax) return;
        _picked.add(a);
      }
    });
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    final paths = <String>[];
    for (final a in _picked) {
      final f = await a.originFile;
      if (f != null) paths.add(f.path);
    }
    if (mounted) Navigator.pop(context, AttachChoice.media(paths));
  }

  void _action(AttachAction a) {
    HapticFeedback.selectionClick();
    Navigator.pop(context, AttachChoice.action(a));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _picked.isEmpty ? s.chatRecents : '${_picked.length}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: kChatInk,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: _grid(s, scroll)),
            _bottomBar(s, bottom),
          ],
        ),
      ),
    );
  }

  Widget _grid(S s, ScrollController scroll) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_denied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.chatPhotosDenied,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: kChatMuted),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: PhotoManager.openSetting,
                child: Text(
                  s.chatOpenSettings,
                  style: const TextStyle(color: _kAccent, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: _assets.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _cameraTile(s);
        return _tile(_assets[i - 1]);
      },
    );
  }

  Widget _cameraTile(S s) => GestureDetector(
    onTap: () => _action(AttachAction.camera),
    child: Container(
      color: const Color(0xFF2C2C2E),
      alignment: Alignment.center,
      child: const Icon(
        Icons.photo_camera_rounded,
        size: 34,
        color: Colors.white,
      ),
    ),
  );

  Widget _tile(AssetEntity a) {
    final index = _picked.indexOf(a);
    final on = index >= 0;
    return GestureDetector(
      onTap: () => _toggle(a),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedPadding(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.all(on ? 8 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(on ? 6 : 0),
              child: _Thumb(a),
            ),
          ),
          if (a.type == AssetType.video)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _duration(a.duration),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? _kAccent : Colors.black26,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: on
                  ? Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  static String _duration(int sec) {
    final m = sec ~/ 60, r = sec % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  Widget _bottomBar(S s, double bottom) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0x14000000))),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        child: _picked.isNotEmpty
            ? SizedBox(
                key: const ValueKey('send'),
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _sending ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          '${s.chatSendMedia} (${_picked.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              )
            : Row(
                key: const ValueKey('sources'),
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _source(
                    Icons.photo_library_rounded,
                    s.chatGalleryTab,
                    const Color(0xFF3390EC),
                    AttachAction.gallery,
                  ),
                  _source(
                    Icons.videocam_rounded,
                    s.chatAttachVideoCamera,
                    const Color(0xFFE5524F),
                    AttachAction.video,
                  ),
                  _source(
                    Icons.insert_drive_file_rounded,
                    s.chatAttachFile,
                    const Color(0xFFF59E0B),
                    AttachAction.file,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _source(IconData icon, String label, Color color, AttachAction a) {
    return InkWell(
      onTap: () => _action(a),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: kChatInk),
            ),
          ],
        ),
      ),
    );
  }
}

/// One thumbnail of the grid, loaded once.
class _Thumb extends StatefulWidget {
  const _Thumb(this.asset);

  final AssetEntity asset;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  late final Future<Uint8List?> _data = widget.asset.thumbnailDataWithSize(
    const ThumbnailSize.square(300),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _data,
      builder: (_, snap) {
        final bytes = snap.data;
        if (bytes == null) return Container(color: const Color(0xFFE5E5EA));
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          width: double.infinity,
          height: double.infinity,
        );
      },
    );
  }
}
