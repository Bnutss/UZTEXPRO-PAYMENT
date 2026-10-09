import 'dart:io' show Platform;
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

  const AppSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.minSegmentWidth = 104,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
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
        final needed = labels.length * minSegmentWidth;
        final scrolls = needed > available;

        // The native iOS control can't scroll and swallows touches inside a
        // scroll view, so it is only used when every segment fits; wider
        // sets get the scrollable pill track on both platforms.
        final Widget control = Platform.isIOS && !scrolls
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

/// Android's stand-in for the native iOS control: light track with a white
/// selected pill.
class _PillSegments extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _PillSegments({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
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
          return Expanded(
            child: GestureDetector(
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
            ),
          );
        }),
      ),
    );
  }
}
