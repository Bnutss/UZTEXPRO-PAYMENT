import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

import 'chat_api.dart';

// Picking and shrinking what is sent, so that little goes over the network and
// onto the server: photos to 1600 px, videos to 720p, and a small preview
// for both. The same limits as the server's (it checks them again).

const int kMaxPhotoBytes = 10 * 1024 * 1024;
const int kMaxVideoBytes = 50 * 1024 * 1024;
const int kMaxFileBytes = 20 * 1024 * 1024;

const kImageExt = ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'gif'];
const kVideoExt = ['mp4', 'mov', 'm4v', 'webm', '3gp'];
const kFileExt = [
  'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'rtf', //
  'odt', 'ods', 'zip', 'rar', '7z', 'json', 'xml',
];

/// Why something was not attached.
enum AttachProblem { tooLarge, badType, failed }

/// What the person picked: ready to send, and what was left out.
class AttachResult {
  AttachResult();

  final List<ChatUpload> ready = [];
  final List<AttachProblem> problems = [];
}

class ChatAttach {
  ChatAttach._();

  static final _picker = ImagePicker();

  static String _ext(String path) =>
      p.extension(path).replaceFirst('.', '').toLowerCase();

  static String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}_'
        '${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }

  /// iOS: the native sheet (recent photos in a grid, camera, files). It returns
  /// photos and videos already shrunk; documents are checked here. Null when
  /// there is no native sheet (the caller falls back to the menu).
  static Future<AttachResult?> nativeSheet(Map<String, String> strings) async {
    final List<dynamic>? items;
    try {
      items = await const MethodChannel(
        'uztexpro/native_sheet',
      ).invokeListMethod<dynamic>('attachSheet', {...strings, 'limit': 10});
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
    final out = AttachResult();
    for (final raw in items ?? const <dynamic>[]) {
      final m = (raw as Map).cast<String, dynamic>();
      final path = m['path'] as String?;
      final kind = m['kind'] as String?;
      if (path == null || kind == null) continue;
      final name = (m['name'] as String?) ?? p.basename(path);
      try {
        if (kind == 'file') {
          await _addFile(out, path, name);
          continue;
        }
        final size = await File(path).length();
        if (size > (kind == 'video' ? kMaxVideoBytes : kMaxPhotoBytes)) {
          out.problems.add(AttachProblem.tooLarge);
          continue;
        }
        out.ready.add(
          ChatUpload(
            filePath: path,
            kind: kind,
            name: name,
            width: (m['width'] as num?)?.toInt() ?? 0,
            height: (m['height'] as num?)?.toInt() ?? 0,
            durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
            thumbPath: m['thumb'] as String?,
            caption: ((m['caption'] as String?) ?? '').trim(),
          ),
        );
      } catch (_) {
        out.problems.add(AttachProblem.failed);
      }
    }
    return out;
  }

  /// Photos / videos already on the phone (ticked in the Android sheet).
  static Future<AttachResult> fromPaths(
    List<String> paths, {
    VoidCallback? onPicked,
  }) async {
    final out = AttachResult();
    if (paths.isNotEmpty) onPicked?.call();
    for (final path in paths) {
      await _add(out, path);
    }
    return out;
  }

  /// Photos and videos from the gallery (several at once).
  static Future<AttachResult> gallery({
    int limit = 10,
    VoidCallback? onPicked,
  }) async {
    final out = AttachResult();
    List<XFile> files;
    try {
      files = await _picker.pickMultipleMedia(
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
        limit: limit,
      );
    } catch (_) {
      out.problems.add(AttachProblem.failed);
      return out;
    }
    if (files.isNotEmpty) onPicked?.call();
    for (final f in files) {
      await _add(out, f.path);
    }
    return out;
  }

  static Future<AttachResult> cameraPhoto({VoidCallback? onPicked}) async {
    final out = AttachResult();
    try {
      final f = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (f != null) {
        onPicked?.call();
        await _add(out, f.path);
      }
    } catch (_) {
      out.problems.add(AttachProblem.failed);
    }
    return out;
  }

  static Future<AttachResult> cameraVideo({VoidCallback? onPicked}) async {
    final out = AttachResult();
    try {
      final f = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 3),
      );
      if (f != null) {
        onPicked?.call();
        await _add(out, f.path);
      }
    } catch (_) {
      out.problems.add(AttachProblem.failed);
    }
    return out;
  }

  /// Documents (PDF, Word, Excel…) from the phone's files.
  static Future<AttachResult> files({VoidCallback? onPicked}) async {
    final out = AttachResult();
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: kFileExt,
        allowMultiple: true,
      );
      if (res == null) return out;
      onPicked?.call();
      for (final f in res.files) {
        final path = f.path;
        if (path == null) continue;
        await _addFile(out, path, f.name);
      }
    } catch (_) {
      out.problems.add(AttachProblem.failed);
    }
    return out;
  }

  static Future<void> _add(AttachResult out, String path) async {
    final ext = _ext(path);
    try {
      if (kImageExt.contains(ext)) {
        await _addPhoto(out, path);
      } else if (kVideoExt.contains(ext)) {
        await _addVideo(out, path);
      } else {
        out.problems.add(AttachProblem.badType);
      }
    } catch (e) {
      debugPrint('attach: $path failed: $e');
      out.problems.add(AttachProblem.failed);
    }
  }

  static Future<void> _addFile(
    AttachResult out,
    String path,
    String name,
  ) async {
    final size = await File(path).length();
    if (!kFileExt.contains(_ext(name))) {
      out.problems.add(AttachProblem.badType);
    } else if (size > kMaxFileBytes) {
      out.problems.add(AttachProblem.tooLarge);
    } else {
      out.ready.add(ChatUpload(filePath: path, kind: 'file', name: name));
    }
  }

  static Future<(int, int)> _dimensions(String path) async {
    final bytes = await File(path).readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final d = await ui.ImageDescriptor.encoded(buffer);
      final size = (d.width, d.height);
      d.dispose();
      return size;
    } finally {
      buffer.dispose();
    }
  }

  /// A small JPEG preview (about 320 px) in the temp folder.
  static Future<String?> _thumb(String imagePath) async {
    try {
      final tmp = await getTemporaryDirectory();
      final out =
          '${tmp.path}/thumb_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final res = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        out,
        minWidth: 320,
        minHeight: 320,
        quality: 70,
      );
      return res?.path;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _addPhoto(AttachResult out, String path) async {
    var file = path;
    var size = await File(file).length();
    if (size > kMaxPhotoBytes) {
      // Rarely (a PNG, a GIF): squeeze it harder.
      final tmp = await getTemporaryDirectory();
      final res = await FlutterImageCompress.compressAndGetFile(
        file,
        '${tmp.path}/photo_${DateTime.now().microsecondsSinceEpoch}.jpg',
        minWidth: 1600,
        minHeight: 1600,
        quality: 75,
      );
      if (res == null) {
        out.problems.add(AttachProblem.failed);
        return;
      }
      file = res.path;
      size = await File(file).length();
      if (size > kMaxPhotoBytes) {
        out.problems.add(AttachProblem.tooLarge);
        return;
      }
    }
    final (w, h) = await _dimensions(file);
    var ext = _ext(file);
    if (!kImageExt.contains(ext)) ext = 'jpg';
    out.ready.add(
      ChatUpload(
        filePath: file,
        kind: 'image',
        name: 'IMG_${_stamp()}.$ext',
        width: w,
        height: h,
        thumbPath: await _thumb(file),
      ),
    );
  }

  static Future<void> _addVideo(AttachResult out, String path) async {
    final info = await VideoCompress.compressVideo(
      path,
      quality: VideoQuality.Res1280x720Quality,
      deleteOrigin: false,
      includeAudio: true,
    );
    final file = info?.path;
    if (info == null || file == null) {
      out.problems.add(AttachProblem.failed);
      return;
    }
    if (await File(file).length() > kMaxVideoBytes) {
      out.problems.add(AttachProblem.tooLarge);
      return;
    }
    String? thumb;
    try {
      final frame = await VideoCompress.getFileThumbnail(
        file,
        quality: 60,
        position: -1,
      );
      thumb = await _thumb(frame.path);
    } catch (_) {}
    out.ready.add(
      ChatUpload(
        filePath: file,
        kind: 'video',
        name: 'VID_${_stamp()}.mp4',
        width: info.width ?? 0,
        height: info.height ?? 0,
        durationMs: (info.duration ?? 0).round(),
        thumbPath: thumb,
      ),
    );
  }
}
