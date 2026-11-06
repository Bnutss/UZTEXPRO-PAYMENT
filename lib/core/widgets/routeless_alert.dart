import 'dart:io' show Platform;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// The native iOS 26 (Liquid Glass) alert of adaptive_platform_ui, shown in
/// the root [Overlay] instead of as a dialog route.
///
/// `AdaptiveAlertDialog.show` pushes a route. While any route is on top of a
/// page, adaptive_platform_ui hides that page's native tab bar and toolbar
/// (`ModalRoute.isCurrent == false`), so they vanished whenever a dialog
/// opened. An overlay entry is not a route: the page stays current and its
/// bars stay on screen, with the same native alert on top.
///
/// Returns false (and shows nothing) when the native alert is unavailable
/// (not iOS 26+); the caller should fall back to its usual dialog then.
/// A native alert that does not disturb the page under it: the routeless one on
/// iOS 26+ (the page keeps its bars and colours), else the package's dialog.
Future<void> showNativeAlert({
  required BuildContext context,
  required String title,
  String? message,
  required List<AlertAction> actions,
}) async {
  if (showRoutelessNativeAlert(
    context,
    title: title,
    message: message,
    actions: actions,
  )) {
    return;
  }
  await AdaptiveAlertDialog.show(
    context: context,
    title: title,
    message: message,
    actions: actions,
  );
}

bool showRoutelessNativeAlert(
  BuildContext context, {
  required String title,
  String? message,
  required List<AlertAction> actions,
}) {
  if (!Platform.isIOS || !PlatformInfo.isIOS26OrHigher()) return false;

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return false;

  final tint = CupertinoTheme.of(context).primaryColor;
  final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _RoutelessAlert(
      title: title,
      message: message,
      actions: actions,
      tint: tint,
      isDark: isDark,
      onClose: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
  return true;
}

class _RoutelessAlert extends StatefulWidget {
  const _RoutelessAlert({
    required this.title,
    required this.message,
    required this.actions,
    required this.tint,
    required this.isDark,
    required this.onClose,
  });

  final String title;
  final String? message;
  final List<AlertAction> actions;
  final Color tint;
  final bool isDark;
  final VoidCallback onClose;

  @override
  State<_RoutelessAlert> createState() => _RoutelessAlertState();
}

class _RoutelessAlertState extends State<_RoutelessAlert> {
  MethodChannel? _channel;

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  int _argb(Color c) =>
      ((c.a * 255.0).round() & 0xff) << 24 |
      ((c.r * 255.0).round() & 0xff) << 16 |
      ((c.g * 255.0).round() & 0xff) << 8 |
      ((c.b * 255.0).round() & 0xff);

  void _onCreated(int id) {
    _channel = MethodChannel('adaptive_platform_ui/ios26_alert_dialog_$id')
      ..setMethodCallHandler((call) async {
        if (call.method != 'actionPressed') return null;
        final idx = ((call.arguments as Map?)?['index'] as num?)?.toInt();
        if (idx == null || idx < 0 || idx >= widget.actions.length) return null;
        final action = widget.actions[idx];
        widget.onClose();
        action.onPressed();
        return null;
      });
  }

  @override
  Widget build(BuildContext context) {
    final params = <String, dynamic>{
      'title': widget.title,
      if (widget.message != null) 'message': widget.message,
      'actionTitles': widget.actions.map((a) => a.title).toList(),
      'actionStyles': widget.actions.map((a) => a.style.name).toList(),
      'actionEnabled': widget.actions.map((a) => a.enabled).toList(),
      'alertStyle': 'glass',
      'isDark': widget.isDark,
      'tint': _argb(widget.tint),
    };

    // Same layout as the package's dialog: centered 270 wide platform view
    // whose height the native side adjusts. The barrier swallows touches so
    // the page underneath (and its tab bar) cannot be used meanwhile.
    return Stack(
      children: [
        const Positioned.fill(
          child: ModalBarrier(dismissible: false, color: Color(0x00000000)),
        ),
        Center(
          child: SizedBox(
            width: 270,
            height: 200,
            child: UiKitView(
              viewType: 'adaptive_platform_ui/ios26_alert_dialog',
              creationParams: params,
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: _onCreated,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
              },
            ),
          ),
        ),
      ],
    );
  }
}
