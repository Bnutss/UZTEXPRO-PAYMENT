import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'chat_voice.dart';

/// A full-screen photo (zoom with two fingers) for platforms without the
/// native iOS viewer.
class PhotoViewerPage extends StatelessWidget {
  const PhotoViewerPage({super.key, required this.file});

  final File file;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    body: Center(
      child: InteractiveViewer(
        maxScale: 5,
        child: Image.file(file, fit: BoxFit.contain),
      ),
    ),
  );
}

/// A full-screen video, played from the file on this phone.
class VideoViewerPage extends StatefulWidget {
  const VideoViewerPage({super.key, required this.file});

  final File file;

  @override
  State<VideoViewerPage> createState() => _VideoViewerPageState();
}

class _VideoViewerPageState extends State<VideoViewerPage> {
  late final VideoPlayerController _c = VideoPlayerController.file(widget.file);
  bool _ready = false;
  bool _failed = false;
  bool _controls = true;

  @override
  void initState() {
    super.initState();
    // A voice message in the background must not talk over the video.
    ChatVoicePlayer.instance.stop();
    _c
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
          _c.play();
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
    _c.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _ready && _c.value.isPlaying;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _controls = !_controls),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: _failed
                  ? const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white54,
                      size: 48,
                    )
                  : _ready
                  ? AspectRatio(
                      aspectRatio: _c.value.aspectRatio,
                      child: VideoPlayer(_c),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),
            if (_controls && _ready) ...[
              Center(
                child: GestureDetector(
                  onTap: () => playing ? _c.pause() : _c.play(),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 18,
                child: Row(
                  children: [
                    Text(
                      formatVoiceTime(_c.value.position.inMilliseconds),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: VideoProgressIndicator(
                        _c,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatVoiceTime(_c.value.duration.inMilliseconds),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
            if (_controls)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 6,
                left: 6,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
