import 'package:adaptive_platform_ui/adaptive_platform_ui.dart'
    show AlertAction, AlertActionStyle;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// The confirmation dialog of Android, in the manner of Telegram: a soft
/// rounded card that scales in, a bold title, a grey explanation and the
/// actions. One or two actions sit in a row on the right; more than that are
/// stacked full-width with the cancel last. Destructive ones are red.
Future<void> showAndroidAlert({
  required BuildContext context,
  required String title,
  String? message,
  required List<AlertAction> actions,
}) {
  HapticFeedback.selectionClick();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, _) =>
        _AlertCard(title: title, message: message, actions: actions),
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.title,
    required this.message,
    required this.actions,
  });

  final String title;
  final String? message;
  final List<AlertAction> actions;

  static const _red = Color(0xFFD93025);

  Color _color(AlertAction a) {
    if (!a.enabled) return const Color(0xFFB0B0B5);
    if (a.style == AlertActionStyle.destructive) return _red;
    if (a.style == AlertActionStyle.cancel) return const Color(0xFF6D6D72);
    return AppColors.brandOrange;
  }

  void _run(BuildContext context, AlertAction a) {
    if (!a.enabled) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
    a.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF111111);
    final sub = dark ? Colors.white70 : const Color(0xFF6D6D72);
    final cancel = actions
        .where((a) => a.style == AlertActionStyle.cancel)
        .toList();
    final others = actions
        .where((a) => a.style != AlertActionStyle.cancel)
        .toList();
    final stacked = actions.length > 2;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Material(
              color: dark ? const Color(0xFF242426) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              elevation: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      22,
                      24,
                      message == null && !stacked ? 6 : 8,
                    ),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: ink,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  if (message != null && message!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Text(
                        message!,
                        style: TextStyle(
                          fontSize: 15.5,
                          height: 1.35,
                          color: sub,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  if (stacked) ...[
                    const SizedBox(height: 4),
                    for (final a in others)
                      _StackedAction(
                        action: a,
                        color: _color(a),
                        onTap: () => _run(context, a),
                      ),
                    for (final a in cancel)
                      _StackedAction(
                        action: a,
                        color: _color(a),
                        onTap: () => _run(context, a),
                      ),
                    const SizedBox(height: 6),
                  ] else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                      // A Wrap, not a Row: two long titles ("Terminate all other
                      // sessions" and "Cancel") do not fit side by side, and the
                      // second button goes to the next line instead of overflowing.
                      child: SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          children: [
                            for (final a in [...cancel, ...others])
                              TextButton(
                                onPressed: a.enabled
                                    ? () => _run(context, a)
                                    : null,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(64, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  a.title,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600,
                                    color: _color(a),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StackedAction extends StatelessWidget {
  const _StackedAction({
    required this.action,
    required this.color,
    required this.onTap,
  });

  final AlertAction action;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: action.enabled ? onTap : null,
    child: SizedBox(
      height: 52,
      width: double.infinity,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            action.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: color,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    ),
  );
}
