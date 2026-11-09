import 'package:flutter/cupertino.dart';

import '../../core/localization/app_strings.dart';

/// "Delete this message": for me, and (when allowed) for everybody. Returns
/// `me`, `all`, or null when the sheet was closed. (iOS shows the system's own
/// sheet from the native photo viewer; this one is for the Flutter viewer.)
Future<String?> askDeleteMessage(
  BuildContext context, {
  required bool allowForAll,
}) {
  final s = S.of(context);
  return showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, 'me'),
          child: Text(s.chatMenuDeleteForMe),
        ),
        if (allowForAll)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, 'all'),
            child: Text(s.chatMenuDeleteForAll),
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
