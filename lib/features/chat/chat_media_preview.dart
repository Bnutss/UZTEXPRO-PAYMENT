import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'chat_api.dart';
import 'chat_widgets.dart' show kChatDeleteIcon;

/// The preview before sending where there is no native sheet (Android): the
/// picked photos / videos full screen with a caption for each, as in Telegram.
/// Pops with the uploads to send (with their captions), or null.
class MediaPreviewPage extends StatefulWidget {
  const MediaPreviewPage({super.key, required this.uploads});

  final List<ChatUpload> uploads;

  @override
  State<MediaPreviewPage> createState() => _MediaPreviewPageState();
}

class _MediaPreviewPageState extends State<MediaPreviewPage> {
  late final List<ChatUpload> _items = [...widget.uploads];
  late final List<TextEditingController> _captions = [
    for (final u in widget.uploads) TextEditingController(text: u.caption),
  ];
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    for (final c in _captions) {
      c.dispose();
    }
    super.dispose();
  }

  void _removeCurrent() {
    if (_items.length <= 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _items.removeAt(_index);
      _captions.removeAt(_index).dispose();
      _index = _index.clamp(0, _items.length - 1);
    });
  }

  void _send() {
    Navigator.of(context).pop([
      for (var i = 0; i < _items.length; i++)
        _items[i].withCaption(_captions[i].text.trim()),
    ]);
  }

  ImageProvider? _image(ChatUpload u) {
    final path = u.kind == 'image' ? u.filePath : u.thumbPath;
    return path == null ? null : FileImage(File(path));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: _items.length > 1
            ? Text('${_index + 1} / ${_items.length}')
            : null,
        actions: [
          IconButton(
            icon: Icon(kChatDeleteIcon),
            onPressed: _removeCurrent,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: _items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final img = _image(_items[i]);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (img != null)
                      Image(image: img, fit: BoxFit.contain)
                    else
                      const Icon(
                        Icons.videocam_rounded,
                        color: Colors.white54,
                        size: 64,
                      ),
                    if (_items[i].kind == 'video')
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white70,
                        size: 64,
                      ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: ValueKey(_index),
                      controller: _captions[_index],
                      style: const TextStyle(color: Colors.white),
                      cursorColor: AppColors.brandOrange,
                      maxLength: 1000,
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: s.chatCaptionHint,
                        hintStyle: const TextStyle(color: Colors.white54),
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.16),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.brandOrange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
