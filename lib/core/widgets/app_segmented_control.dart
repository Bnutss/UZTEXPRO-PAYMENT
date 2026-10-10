import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../theme/app_colors.dart';

/// Segmented control shared by every screen: the native
/// [AdaptiveSegmentedControl] on iOS, a matching pill track on Android.
///
/// Native segmented controls can't scroll, so when the segments would be
/// narrower than [minSegmentWidth] the whole control gets a scrollable row
/// instead of squeezing the labels.
class AppSegmentedControl extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double minSegmentWidth;
  final EdgeInsetsGeometry padding;

  /// Skip the native iOS control and always draw the Flutter pill track.
  /// Use on screens that flicker while the platform view is being created
  /// during the route transition.
  final bool forcePill;

  const AppSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.minSegmentWidth = 104,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.forcePill = false,
  });

  @override
  Widget build(BuildContext context) {
    void handleChanged(int i) {
      HapticFeedback.selectionClick();
      onChanged(i);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolved = padding.resolve(Directionality.of(context));
        final available = constraints.maxWidth - resolved.horizontal;
        // Each segment is at least [minSegmentWidth], but grows to fit its
        // label so long names are never ellipsized.
        final widths = [
          for (final l in labels) math.max(minSegmentWidth, _textWidth(l) + 28),
        ];
        final equal = widths.reduce(math.max) * labels.length;
        final needed = widths.fold<double>(0, (a, b) => a + b);
        // minSegmentWidth == 0 means "never scroll, just share the width":
        // those callers (short 2-3 segment sets) keep the native control.
        final overflows = minSegmentWidth > 0 && equal > available;
        // Segments of uneven width still fit: stretch them proportionally to
        // fill the row instead of leaving an empty gap on the right.
        final stretch = overflows && needed <= available;
        final scrolls = overflows && !stretch;

        // The native iOS control can't scroll and swallows touches inside a
        // scroll view, so it is only used when every segment fits; wider
        // sets get the scrollable pill track on both platforms.
        final Widget control = Platform.isIOS && !overflows && !forcePill
            ? AdaptiveSegmentedControl(
                labels: labels,
                selectedIndex: selectedIndex,
                color: AppColors.brandOrange,
                onValueChanged: handleChanged,
              )
            : _PillSegments(
                labels: labels,
                selectedIndex: selectedIndex,
                onChanged: handleChanged,
                widths: scrolls
                    ? widths
                    : stretch
                        ? [for (final w in widths) w * available / needed]
                        : null,
              );

        final sized = SizedBox(
          width: scrolls ? needed : available,
          height: 36,
          child: control,
        );
        if (!scrolls) return Padding(padding: padding, child: sized);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: padding,
          child: sized,
        );
      },
    );
  }
}

double _textWidth(String text) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout();
  return tp.width;
}

/// Android's stand-in for the native iOS control: light track with a white
/// selected pill.
class _PillSegments extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Per-segment widths when the track scrolls; null = equal split.
  final List<double>? widths;

  const _PillSegments({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.widths,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == selectedIndex;
          final cell = GestureDetector(
            onTap: () => onChanged(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                labels[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.brandOrange
                      : const Color(0xFF8A8A8E),
                ),
              ),
            ),
          );
          return widths == null
              ? Expanded(child: cell)
              : SizedBox(width: widths![i] - 6 / labels.length, child: cell);
        }),
      ),
    );
  }
}
