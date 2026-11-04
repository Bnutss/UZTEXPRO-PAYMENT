import 'dart:io' show Platform;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'app_segmented_control.dart';

/// A segmented switch: the package's own [AdaptiveSegmentedControl] on iOS
/// (native, Liquid Glass on iOS 26); the shared pill track on Android, where
/// the package would draw a Material 3 control that clashes with the theme.
class NativeSegments extends StatelessWidget {
  const NativeSegments({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.minSegmentWidth = 84,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Only for the Android pill track (it scrolls when segments get narrower).
  final double minSegmentWidth;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) {
      return AppSegmentedControl(
        labels: labels,
        selectedIndex: selectedIndex,
        onChanged: onChanged,
        minSegmentWidth: minSegmentWidth,
        padding: EdgeInsets.zero,
      );
    }
    return SizedBox(
      height: 36,
      child: AdaptiveSegmentedControl(
        labels: labels,
        selectedIndex: selectedIndex,
        color: AppColors.brandOrange,
        onValueChanged: (i) {
          HapticFeedback.selectionClick();
          onChanged(i);
        },
      ),
    );
  }
}
