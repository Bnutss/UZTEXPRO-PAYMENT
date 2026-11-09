import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colors of the icon tiles, the ones iOS Settings and Telegram use.
class SettingsColors {
  const SettingsColors._();

  static const blue = Color(0xFF3478F6);
  static const orange = Color(0xFFFF9500);
  static const green = Color(0xFF34C759);
  static const indigo = Color(0xFF5856D6);
  static const gray = Color(0xFF8E8E93);
  static const red = Color(0xFFEB5545);
}

/// A Telegram / iOS Settings icon: a white glyph on a colored rounded square.
class SettingsIconTile extends StatelessWidget {
  const SettingsIconTile({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  /// The size of the tile for the user's text scale (30 like iOS Settings).
  static double sizeOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(30).clamp(28.0, 40.0);

  @override
  Widget build(BuildContext context) {
    final side = sizeOf(context);
    return ExcludeSemantics(
      child: Container(
        width: side,
        height: side,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(side * 0.23),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(color, Colors.white, 0.12)!, color],
          ),
        ),
        child: Icon(icon, size: side * 0.62, color: Colors.white),
      ),
    );
  }
}

/// A rounded white card holding rows, set apart by hairlines that start at the
/// text and stop 16 pt short of the right edge, as in the contacts list.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children, this.indent});

  final List<Widget> children;

  /// Where the hairlines start; by default at the text of a row that has an
  /// icon tile. Rows without a tile start the text (and the line) at 16.
  final double? indent;

  @override
  Widget build(BuildContext context) {
    final indent = this.indent ?? 16 + SettingsIconTile.sizeOf(context) + 12;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      // Telegram's card: continuous (superellipse) corners, no outline.
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              // The same line as in the contacts list: from the text to 16 pt
              // short of the right edge.
              Divider(
                height: 0.5,
                thickness: 0.5,
                indent: indent,
                endIndent: 16,
                color: const Color(0x1F000000),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One row of a [SettingsGroup]: colored icon tile, title, an optional line
/// under it, then a value, a custom [trailing] widget or a chevron.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    this.icon,
    this.color = SettingsColors.gray,
    this.leading,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
  });

  final IconData? icon;
  final Color color;

  /// Replaces the icon tile (the Face ID mark, for one).
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            leading ?? SettingsIconTile(icon: icon!, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1C1C1E),
                      fontSize: 16,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Color(0xFF8A8A8E),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 12),
              Text(
                value!,
                style: const TextStyle(color: Color(0xFF8A8A8E), fontSize: 16),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            if (onTap != null && trailing == null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFC7C7CC)),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: row,
      ),
    );
  }
}
