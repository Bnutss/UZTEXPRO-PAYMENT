import 'package:flutter/cupertino.dart';

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
