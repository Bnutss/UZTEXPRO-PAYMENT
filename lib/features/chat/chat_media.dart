import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'chat_api.dart';
import 'chat_models.dart';

// Photos, videos and documents live on the PHONE: the server keeps an original
// only until every recipient has saved it (then deletes it). This is the
// phone's side: where the files are kept, and the downloads and uploads that
// are going on.

/// The phone's folder of chat files. A file's name comes from the message's
/// client id, which is the same before and after the server stored it, so the
/// sender's own copy and a recipient's download are found the same way.
class ChatMediaStore {
  ChatMediaStore._();

  static Directory? _dir;

  /// Must be awaited once before the files are looked up.
  static Future<void> init() async {
    if (_dir != null) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/chat_media');
      if (!await dir.exists()) await dir.create(recursive: true);
      _dir = dir;
    } catch (_) {
      // No folder (a test, a broken plugin): the files are simply not found.
    }
  }

  static String key(ChatMessage m) =>
      m.clientId.isNotEmpty ? m.clientId : 'm${m.id}';

  static String _safe(String name) =>
      name.replaceAll(RegExp(r'[^\w.\- ]', unicode: true), '_');

  /// The original of [m] on this phone (may not exist yet).
  static File? fileOf(ChatMessage m) {
    final dir = _dir;
    final media = m.media;
    if (dir == null || media == null) return null;
    return File('${dir.path}/${_safe(key(m))}_${_safe(media.name)}');
  }

  /// The small preview kept on this phone (the sender's own, before the server
  /// has one).
  static File? thumbOf(ChatMessage m) {
    final dir = _dir;
    if (dir == null) return null;
    return File('${dir.path}/${_safe(key(m))}.thumb.jpg');
  }

  /// The original is on this phone: shown and opened from here.
  static bool has(ChatMessage m) => fileOf(m)?.existsSync() ?? false;

  /// The sender keeps what was sent: copies it (and the preview) in.
  static Future<void> keepOutgoing(
    ChatMessage local,
    String filePath,
    String? thumbPath,
  ) async {
    final dest = fileOf(local);
    if (dest != null && !dest.existsSync()) {
      await File(filePath).copy(dest.path);
    }
    final thumb = thumbOf(local);
    if (thumb != null && thumbPath != null && !thumb.existsSync()) {
      await File(thumbPath).copy(thumb.path);
    }
  }

  // Leftovers the chat makes in the temp folder (recordings, previews, shrunk
  // photos): cleared together with the saved files.
  static bool _isChatTemp(String name) =>
      name.startsWith('voice_') ||
      name.startsWith('thumb_') ||
      name.startsWith('photo_');

  /// How much the chat files take on this phone.
  static Future<int> usedBytes() async {
    var total = 0;
    final dir = _dir;
    if (dir != null && await dir.exists()) {
      await for (final e in dir.list()) {
        if (e is File) total += await e.length();
      }
    }
    try {
      final tmp = await getTemporaryDirectory();
      await for (final e in tmp.list()) {
        if (e is File && _isChatTemp(e.uri.pathSegments.last)) {
          total += await e.length();
        }
      }
    } catch (_) {}
    return total;
  }

  /// Deletes every saved chat file (the messages stay; originals the server
  /// already dropped cannot be fetched again) and the chat's temp leftovers.
  static Future<void> clear() async {
    final dir = _dir;
    if (dir != null && await dir.exists()) {
      await for (final e in dir.list()) {
        try {
          await e.delete(recursive: true);
        } catch (_) {}
      }
    }
    try {
      final tmp = await getTemporaryDirectory();
      await for (final e in tmp.list()) {
        if (e is File && _isChatTemp(e.uri.pathSegments.last)) {
          try {
            await e.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
    ChatMediaManager.instance.notifyCleared();
  }
}

/// Downloads and uploads in progress, by message key, for the bubbles to show.
class ChatMediaManager extends ChangeNotifier {
  ChatMediaManager._();
  static final ChatMediaManager instance = ChatMediaManager._();

  final Map<String, double> _progress = {};
  final Set<String> _gone = {};
  final Set<String> _failed = {};
  final Map<String, ChatCancelToken> _tokens = {};

  /// 0..1 while a download / upload of [m] is going on; null when none is.
  double? progressOf(ChatMessage m) => _progress[ChatMediaStore.key(m)];

  /// The server no longer has the original and this phone has none.
  bool isGone(ChatMessage m) =>
      _gone.contains(ChatMediaStore.key(m)) ||
      (m.media != null && !m.media!.available && !ChatMediaStore.has(m));

  bool hasFailed(ChatMessage m) => _failed.contains(ChatMediaStore.key(m));

  void setUpload(String key, double? value) {
    if (value == null) {
      _progress.remove(key);
    } else {
      _progress[key] = value;
    }
    notifyListeners();
  }

  /// Fetches the original of [m] from the server. True when it is on the
  /// phone after this.
  Future<bool> download(ChatMessage m, ChatRest rest) async {
    final dest = ChatMediaStore.fileOf(m);
    if (dest == null || m.isLocal) return false;
    if (dest.existsSync()) return true;
    final key = ChatMediaStore.key(m);
    if (_progress.containsKey(key)) return false; // already going on
    _failed.remove(key);
    _progress[key] = 0;
    final token = _tokens[key] = ChatCancelToken();
    notifyListeners();
    var lastPush = 0.0;
    try {
      await rest.downloadMedia(
        m.id,
        dest.path,
        cancel: token,
        onProgress: (p) {
          _progress[key] = p;
          // Not on every chunk: a bubble repaints a few times a second.
          if (p - lastPush >= 0.02) {
            lastPush = p;
            notifyListeners();
          }
        },
      );
      // Saved: now the server may delete its copy.
      unawaited(rest.ackDownloaded(m.id).catchError((_) {}));
      return true;
    } on ChatCancelled {
      return false; // the person stopped it: not a failure
    } on ChatApiException catch (e) {
      if (e.statusCode == 410 || e.statusCode == 404) {
        _gone.add(key);
      } else {
        _failed.add(key);
      }
      return false;
    } catch (_) {
      _failed.add(key);
      return false;
    } finally {
      _tokens.remove(key);
      _progress.remove(key);
      notifyListeners();
    }
  }

  /// The files on the phone were deleted: the bubbles look again.
  void notifyCleared() {
    _failed.clear();
    notifyListeners();
  }

  /// Stops the download of [m] that is going on.
  void cancelDownload(ChatMessage m) =>
      _tokens[ChatMediaStore.key(m)]?.cancel();
}

/// "12.3 MB" / "840 KB".
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
}
