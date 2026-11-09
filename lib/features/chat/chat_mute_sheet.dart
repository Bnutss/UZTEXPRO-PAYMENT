import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';

import '../../core/localization/app_strings.dart';

/// "Mute notifications": for 1 hour, 8 hours, 2 days or for good. Returns the
/// hours (0: for good), or null when the sheet was closed.
Future<int?> askMuteDuration(BuildContext context) {
  final s = S.of(context);
  return showCupertinoModalPopup<int>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(s.muteTitle),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, 1),
          child: Text(s.mute1h),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, 8),
          child: Text(s.mute8h),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, 48),
          child: Text(s.mute2d),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, 0),
          child: Text(s.muteForever),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.pop(ctx),
        child: Text(s.chatCancel),
      ),
    ),
  );
}

/// The "Mute" button of a chat's profile, as in Telegram: a tap while the chat
/// is on opens a small menu right at the button (the native Liquid Glass menu
/// on iOS 26, a popup on Android) with "Mute for 1 hour", "8 hours", "2 days",
/// "forever"; a tap while it is muted turns the notifications back on at once.
class MuteMenu extends StatelessWidget {
  const MuteMenu({
    super.key,
    required this.muted,
    required this.onMute,
    required this.onUnmute,
    required this.child,
    this.enabled = true,
  });

  final bool muted;

  /// Hours to mute for; 0 means for good.
  final ValueChanged<int> onMute;
  final VoidCallback onUnmute;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    if (muted) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onUnmute();
        },
        child: child,
      );
    }
    final s = S.of(context);
    final native = PlatformInfo.isIOS26OrHigher();
    dynamic icon(String symbol, IconData fallback) =>
        native ? symbol : fallback;

    AdaptivePopupMenuItem<int> item(String label, int hours, dynamic icon) =>
        AdaptivePopupMenuItem<int>(label: label, icon: icon, value: hours);

    return AdaptivePopupMenuButton.widget<int>(
      items: [
        item(s.mute1h, 1, icon('clock', Icons.schedule_rounded)),
        item(s.mute8h, 8, icon('clock', Icons.schedule_rounded)),
        item(s.mute2d, 48, icon('clock', Icons.schedule_rounded)),
        item(
          s.muteForever,
          0,
          icon('bell.slash', Icons.notifications_off_rounded),
        ),
      ],
      onSelected: (_, entry) {
        final hours = entry.value;
        if (hours != null) {
          HapticFeedback.selectionClick();
          onMute(hours);
        }
      },
      child: child,
    );
  }
}
