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
        // Filter and search share one glass capsule.
        if ((filterLabels != null && onFilterSelected != null) ||
            onFilterTap != null ||
            onToggleSearch != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _HeaderActionsCapsule(
              filterLabels: filterLabels,
              filterSelected: filterSelected,
              onFilterSelected: onFilterSelected,
              onFilterTap: onFilterTap,
              filterActive: filterActive,
              filterSfSymbol: filterSfSymbol,
              onSearch: onToggleSearch,
            ),
          ),
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

/// The search field. On iOS it sits on a native Liquid Glass capsule (the
/// package has only glass buttons, so the field is the content of one); tapping
/// the glass puts the cursor in the field. Elsewhere a plain white pill.
class _HeaderSearchField extends StatefulWidget {
  const _HeaderSearchField({required this.controller, required this.hint});

  final TextEditingController? controller;
  final String hint;

  @override
  State<_HeaderSearchField> createState() => _HeaderSearchFieldState();
}

class _HeaderSearchFieldState extends State<_HeaderSearchField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1C1C1E);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
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
              controller: widget.controller,
              focusNode: _focus,
              autofocus: true,
              textInputAction: TextInputAction.search,
              cursorColor: ink,
              style: const TextStyle(color: ink, fontSize: 15),
              onSubmitted: (_) => _focus.unfocus(),
              decoration: InputDecoration(
                hintText: widget.hint,
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

    if (Platform.isIOS) {
      return SizedBox(
        height: 46,
        child: LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth.isFinite ? box.maxWidth : 240.0;
            return AdaptiveButton.child(
              onPressed: _focus.requestFocus,
              color: ink,
              style: AdaptiveButtonStyle.glass,
              size: AdaptiveButtonSize.large,
              useSmoothRectangleBorder: false,
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(23),
              minSize: Size(width, 46),
              child: SizedBox(width: width, height: 46, child: content),
            );
          },
        ),
      );
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.10) : Colors.white,
        borderRadius: BorderRadius.circular(23),
      ),
      child: content,
    );
  }
}

/// Filter and search side by side in ONE capsule: native Liquid Glass on iOS,
/// a light pill elsewhere. The filter opens a menu (check on the selected
/// entry) or just reports a tap; a dot on it shows an applied filter.
class _HeaderActionsCapsule extends StatelessWidget {
  const _HeaderActionsCapsule({
    required this.filterLabels,
    required this.filterSelected,
    required this.onFilterSelected,
    required this.onFilterTap,
    required this.filterActive,
    required this.filterSfSymbol,
    required this.onSearch,
  });

  final List<String>? filterLabels;
  final int filterSelected;
  final ValueChanged<int>? onFilterSelected;
  final VoidCallback? onFilterTap;
  final bool filterActive;
  final String filterSfSymbol;
  final VoidCallback? onSearch;

  static const _slot = 46.0;
  static const _ink = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    final hasMenu = filterLabels != null && onFilterSelected != null;
    final hasFilter = hasMenu || onFilterTap != null;
    final hasSearch = onSearch != null;
    final count = (hasFilter ? 1 : 0) + (hasSearch ? 1 : 0);
    if (count == 0) return const SizedBox.shrink();
    final width = _slot * count;

    final Widget background = Platform.isIOS
        ? AdaptiveButton.child(
            onPressed: () {},
            color: _ink,
            style: AdaptiveButtonStyle.glass,
            size: AdaptiveButtonSize.medium,
            useSmoothRectangleBorder: false,
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(_slot / 2),
            minSize: Size(width, _slot),
            child: SizedBox(width: width, height: _slot),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(_slot / 2),
            ),
          );

    Widget filter() {
      if (hasMenu) {
        return AdaptivePopupMenuButton.icon<int>(
          icon: PlatformInfo.isIOS26OrHigher()
              ? filterSfSymbol
              : Icons.tune_rounded,
          size: _slot,
          tint: _ink,
          // Plain: the capsule behind it is the glass.
          buttonStyle: PopupButtonStyle.plain,
          items: [
            for (var i = 0; i < filterLabels!.length; i++)
              AdaptivePopupMenuItem<int>(
                label: filterLabels![i],
                value: i,
                selected: i == filterSelected,
              ),
          ],
          onSelected: (index, item) {
            HapticFeedback.selectionClick();
            onFilterSelected!(index);
          },
        );
      }
      return InkResponse(
        onTap: () {
          HapticFeedback.lightImpact();
          onFilterTap!();
        },
        child: const Center(
          child: Icon(Icons.tune_rounded, color: _ink, size: 22),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: _slot,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: background),
          Row(
            children: [
              if (hasFilter)
                SizedBox(width: _slot, height: _slot, child: filter()),
              if (hasSearch)
                SizedBox(
                  width: _slot,
                  height: _slot,
                  child: InkResponse(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onSearch!();
                    },
                    child: const Center(
                      child: Icon(Icons.search_rounded, color: _ink, size: 22),
                    ),
                  ),
                ),
            ],
          ),
          if (hasFilter && filterActive)
            Positioned(
              top: 5,
              left: _slot - 17,
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
