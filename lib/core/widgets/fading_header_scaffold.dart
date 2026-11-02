import 'dart:io' show Platform;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'adaptive_back_button.dart';
import 'search_toggle.dart';

/// Height of the title row (back button, title, actions) below the status bar.
const double kFadingHeaderRowHeight = 58;

/// Full-screen page frame with a transparent header that floats over the
/// content: the body scrolls *underneath* it. Only a soft, short fade sits
/// behind the title row (no solid plate); [bottom] widgets float unpinned of
/// any background.
///
/// A page that can be searched passes [onToggleSearch]: the header then gets a
/// search button on the right; while [searching] the whole header row turns
/// into a focused search field with an X that closes it.
///
/// [body] receives the space it has to leave at the top (status bar + header
/// row + [bottom]) so lists can add it to their top padding and start below
/// the header while still scrolling under it.
class FadingHeaderScaffold extends StatelessWidget {
  const FadingHeaderScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.background,
    required this.body,
    this.trailing = const [],
    this.onToggleSearch,
    this.searching = false,
    this.searchController,
    this.searchHint,
    this.filterLabels,
    this.filterSelected = 0,
    this.onFilterSelected,
    this.filterActive = false,
    this.onFilterTap,
    this.filterSfSymbol = 'line.3.horizontal.decrease',
    this.bottom,
    this.bottomHeight = 0,
    this.bottomNavigationBar,
  });

  final String title;

  /// Small red line under the title (e.g. the selected factory).
  final String? subtitle;

  /// Colour of the page and of the header fade (must match what is behind).
  final Color background;

  /// Extra widgets in the title row, left of the search button.
  final List<Widget> trailing;

  final VoidCallback? onToggleSearch;
  final bool searching;
  final TextEditingController? searchController;
  final String? searchHint;

  /// A filter menu button left of the search one: tapping it opens a menu with
  /// these labels ([filterSelected] gets the check). [filterActive] puts a dot
  /// on the button while a filter is applied.
  final List<String>? filterLabels;
  final int filterSelected;
  final ValueChanged<int>? onFilterSelected;
  final bool filterActive;

  /// Instead of a menu ([filterLabels]): a filter button that just calls this
  /// (e.g. opens a picker sheet). [filterActive] still puts the dot on it.
  final VoidCallback? onFilterTap;
  final String filterSfSymbol;

  /// Floating widgets under the title row (view toggle, filter chips). They
  /// are part of the header and fade the same way. [bottomHeight] is their
  /// total height.
  final Widget? bottom;
  final double bottomHeight;

  /// Pinned bar at the bottom of the screen (action buttons of a detail page).
  final Widget? bottomNavigationBar;

  final Widget Function(BuildContext context, double topInset) body;

  static const double _fade = 26;

  @override
  Widget build(BuildContext context) {
    final statusBar = MediaQuery.paddingOf(context).top;
    final headerHeight = statusBar + kFadingHeaderRowHeight + bottomHeight;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final titleRow = Row(
      key: const ValueKey('title'),
      children: [
        const SizedBox(
          width: 58,
          height: kFadingHeaderRowHeight,
          child: AdaptiveBackButton(),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1C1C1E),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.topLeft,
                  child: subtitle == null
                      ? const SizedBox(width: double.infinity)
                      : Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFE53935),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        ...trailing,
        if (filterLabels == null && onFilterTap != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _HeaderTapFilterButton(
              active: filterActive,
              onPressed: onFilterTap!,
            ),
          ),
        if (filterLabels != null && onFilterSelected != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _HeaderFilterButton(
              labels: filterLabels!,
              selected: filterSelected,
              active: filterActive,
              sfSymbol: filterSfSymbol,
              onSelected: onFilterSelected!,
            ),
          ),
        if (onToggleSearch != null)
          SearchToggleButton(active: false, onPressed: onToggleSearch!),
      ],
    );

    final searchRow = Row(
      key: const ValueKey('search'),
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: _HeaderSearchField(
              controller: searchController,
              hint: searchHint ?? '',
            ),
          ),
        ),
        if (onToggleSearch != null)
          SearchToggleButton(active: true, onPressed: onToggleSearch!),
      ],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: background,
        bottomNavigationBar: bottomNavigationBar,
        body: Stack(
          children: [
            Positioned.fill(
              child: Builder(builder: (c) => body(c, headerHeight)),
            ),
            // Soft fade only behind the status bar + title row (not behind
            // [bottom]): solid at the top, gone before the filters begin.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: statusBar + kFadingHeaderRowHeight + _fade,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        background,
                        background,
                        background.withValues(alpha: 0),
                      ],
                      stops: [
                        0,
                        (statusBar + kFadingHeaderRowHeight) /
                            (statusBar + kFadingHeaderRowHeight + _fade) *
                            0.85,
                        1,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: statusBar,
              left: 0,
              right: 0,
              height: kFadingHeaderRowHeight,
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                child: searching ? searchRow : titleRow,
              ),
            ),
            if (bottom != null)
              Positioned(
                top: statusBar + kFadingHeaderRowHeight,
                left: 0,
                right: 0,
                height: bottomHeight,
                child: bottom!,
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderSearchField extends StatelessWidget {
  const _HeaderSearchField({required this.controller, required this.hint});

  final TextEditingController? controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const ink = Color(0xFF1C1C1E);
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.10) : Colors.white,
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 20,
            color: ink.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              cursorColor: ink,
              style: const TextStyle(color: ink, fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: ink.withValues(alpha: 0.4),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round glass filter button with a native menu (check on the selected entry)
/// and a dot while a filter is applied.
class _HeaderFilterButton extends StatelessWidget {
  const _HeaderFilterButton({
    required this.labels,
    required this.selected,
    required this.active,
    required this.sfSymbol,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final bool active;
  final String sfSymbol;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final native = PlatformInfo.isIOS26OrHigher();
    final button = AdaptivePopupMenuButton.icon<int>(
      icon: native ? sfSymbol : Icons.tune_rounded,
      size: 46,
      tint: const Color(0xFF1C1C1E),
      items: [
        for (var i = 0; i < labels.length; i++)
          AdaptivePopupMenuItem<int>(
            label: labels[i],
            value: i,
            selected: i == selected,
          ),
      ],
      onSelected: (index, item) {
        HapticFeedback.selectionClick();
        onSelected(index);
      },
    );
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: button),
          if (active)
            Positioned(
              top: 3,
              right: 3,
              child: IgnorePointer(
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6A00),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Action buttons that float at the bottom of a detail page, over the content,
/// with a soft fade behind them instead of a solid bar. Put it as the last
/// child of the body [Stack] and add [clearance] to the scroll view's bottom
/// padding so the last card can scroll clear of the buttons.
class FloatingBottomBar extends StatelessWidget {
  const FloatingBottomBar({
    super.key,
    required this.background,
    required this.child,
  });

  final Color background;
  final Widget child;

  /// Space the content keeps free at the bottom for the bar.
  static double clearance(BuildContext context) =>
      96 + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              background.withValues(alpha: 0),
              background.withValues(alpha: 0.92),
              background,
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Round glass filter button that just reports a tap (opens a picker), with
/// the same dot as [_HeaderFilterButton] while a filter is applied.
class _HeaderTapFilterButton extends StatelessWidget {
  const _HeaderTapFilterButton({required this.active, required this.onPressed});

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    void handle() {
      HapticFeedback.lightImpact();
      onPressed();
    }

    const ink = Color(0xFF1C1C1E);
    final Widget button = Platform.isIOS
        ? AdaptiveButton.icon(
            onPressed: handle,
            icon: Icons.tune_rounded,
            iconColor: ink,
            color: ink,
            style: AdaptiveButtonStyle.glass,
            size: AdaptiveButtonSize.medium,
            useSmoothRectangleBorder: false,
            padding: EdgeInsets.zero,
            minSize: const Size(46, 46),
          )
        : Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: handle,
              child: Container(
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFF2F2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tune_rounded, color: ink, size: 22),
              ),
            ),
          );
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: button),
          if (active)
            Positioned(
              top: 3,
              right: 3,
              child: IgnorePointer(
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6A00),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
