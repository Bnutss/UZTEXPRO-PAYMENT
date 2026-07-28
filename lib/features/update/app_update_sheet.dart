import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/localization/app_strings.dart';
import 'app_update_api.dart';

/// Shows the self-update sheet. Mandatory updates (`isCritical`) can't be
/// dismissed by tapping outside, dragging down, or the back button — the
/// user must download and install before returning to the app.
Future<void> showAppUpdateSheet(BuildContext context, AppUpdateInfo info) {
  return showModalBottomSheet(
    context: context,
    isDismissible: !info.isCritical,
    enableDrag: !info.isCritical,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AppUpdateSheet(info: info),
  );
}

class _AppUpdateSheet extends StatefulWidget {
  const _AppUpdateSheet({required this.info});

  final AppUpdateInfo info;

  @override
  State<_AppUpdateSheet> createState() => _AppUpdateSheetState();
}

class _AppUpdateSheetState extends State<_AppUpdateSheet> {
  static const Color _g1 = Color(0xFFFF8C00);
  static const Color _g2 = Color(0xFFCC1500);

  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _download() async {
    final url = widget.info.apkUrl;
    if (url == null) return;
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });
    try {
      final response = await http.Client().send(http.Request('GET', Uri.parse(url)));
      final total = response.contentLength ?? 0;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/uztexpro_update_${widget.info.versionCode}.apk');
      final sink = file.openWrite();
      var received = 0;
      await response.stream.listen((chunk) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0 && mounted) {
          setState(() => _progress = received / total);
        }
      }).asFuture<void>();
      await sink.close();
      if (!mounted) return;

      HapticFeedback.mediumImpact();
      final result = await OpenFilex.open(file.path);
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = result.type == ResultType.done ? null : _installErrorMessage(result.type);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = S.of(context).appUpdateDownloadFailed;
      });
    }
  }

  String _installErrorMessage(ResultType type) {
    final s = S.of(context);
    return type == ResultType.permissionDenied
        ? s.appUpdateInstallPermissionDenied
        : s.appUpdateInstallFailed;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final info = widget.info;

    return PopScope(
      canPop: !info.isCritical,
      child: Container(
        decoration: BoxDecoration(color: surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!info.isCritical)
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: onSurface.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                ),
              ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_g1, _g2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.appUpdateAvailableTitle, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: onSurface)),
                      Text(
                        s.appUpdateVersionLabel(info.versionName),
                        style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.55)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (info.changelog.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: onSurface.withOpacity(0.04), borderRadius: BorderRadius.circular(14)),
                child: Text(info.changelog, style: TextStyle(fontSize: 13, height: 1.5, color: onSurface.withOpacity(0.8))),
              ),
            ],
            if (info.isCritical) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: _g2),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.appUpdateCriticalNotice,
                      style: const TextStyle(fontSize: 12, color: _g2, fontWeight: FontWeight.w600, height: 1.4),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13)),
              const SizedBox(height: 12),
            ],
            if (_downloading)
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      minHeight: 8,
                      backgroundColor: onSurface.withOpacity(0.08),
                      valueColor: const AlwaysStoppedAnimation(_g2),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('${(_progress * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.55))),
                ],
              )
            else
              SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _download,
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: Text(s.appUpdateDownloadButton, style: const TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _g2,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
