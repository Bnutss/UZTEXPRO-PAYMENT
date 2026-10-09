import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shared building blocks for the compact "dashboard" screens (issued
/// orders, analytics): one rounded white block per logical group, hairline
/// dividers inside instead of a floating card per row.

const Color kInk = Color(0xFF1C1C1E);
const Color kInkMuted = Color(0xFF8A8A8E);

Color _hairline(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface.withOpacity(0.07);

/// White rounded container with a hairline border and a very soft shadow.
class BlockCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? radius;

  const BlockCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: radius ?? BorderRadius.circular(16),
        border: Border.all(color: _hairline(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Tiny uppercase-free caption above a control or a section.
class BlockCaption extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const BlockCaption(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: kInkMuted,
                letterSpacing: 0.1,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class Metric {
  final String label;
  final String value;
  final IconData? icon;
  final bool accent;

  const Metric(this.label, this.value, {this.icon, this.accent = false});
}

/// A row of metrics separated by thin vertical dividers, e.g.
/// `Orders | Pieces | Amount`. Values scale down instead of wrapping.
class MetricRow extends StatelessWidget {
  final List<Metric> metrics;
  final List<int> flex;

  const MetricRow({super.key, required this.metrics, this.flex = const []});

  @override
  Widget build(BuildContext context) {
    final line = _hairline(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < metrics.length; i++) ...[
            if (i > 0) Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 12), color: line),
            Expanded(
              flex: i < flex.length ? flex[i] : 1,
              child: _MetricCell(metrics[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final Metric metric;
  const _MetricCell(this.metric);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            if (metric.icon != null) ...[
              Icon(metric.icon, size: 13, color: metric.accent ? AppColors.brandRed : kInkMuted),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                metric.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: kInkMuted, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            metric.value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: metric.accent ? AppColors.brandRed : kInk,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Horizontal hairline for use between metric rows / list rows.
class BlockDivider extends StatelessWidget {
  final double indent;
  final double gap;

  const BlockDivider({super.key, this.indent = 0, this.gap = 10});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: indent, top: gap, bottom: gap),
        child: Container(height: 1, color: _hairline(context)),
      );
}

/// One candidate image for [FallbackNetworkImage].
class PhotoSource {
  final String url;
  final Map<String, String>? headers;

  const PhotoSource(this.url, {this.headers});
}

/// Shows the first source that loads; when one fails (404, no network, bad
/// image) it moves on to the next, and shows [placeholder] once all failed.
class FallbackNetworkImage extends StatefulWidget {
  final List<PhotoSource> sources;
  final double width;
  final double height;
  final Widget Function() placeholder;

  const FallbackNetworkImage({
    super.key,
    required this.sources,
    required this.width,
    required this.height,
    required this.placeholder,
  });

  @override
  State<FallbackNetworkImage> createState() => _FallbackNetworkImageState();
}

class _FallbackNetworkImageState extends State<FallbackNetworkImage> {
  int _index = 0;

  @override
  void didUpdateWidget(FallbackNetworkImage old) {
    super.didUpdateWidget(old);
    final changed = old.sources.length != widget.sources.length ||
        (widget.sources.isNotEmpty && old.sources.isNotEmpty && old.sources.first.url != widget.sources.first.url);
    if (changed) _index = 0;
  }

  void _next() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _index++);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.sources.length) return widget.placeholder();
    final source = widget.sources[_index];
    return Image.network(
      source.url,
      key: ValueKey('$_index:${source.url}'),
      headers: source.headers,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        _next();
        return widget.placeholder();
      },
      loadingBuilder: (_, child, progress) => progress == null ? child : widget.placeholder(),
    );
  }
}

/// Round avatar: the first photo source that loads, otherwise soft coloured
/// initials (colour derived from the name so it stays stable).
class PersonAvatar extends StatelessWidget {
  final String name;
  final List<PhotoSource> sources;
  final double size;

  const PersonAvatar({super.key, required this.name, this.sources = const [], this.size = 40});

  static const _tints = [
    (Color(0xFFFFEBD2), Color(0xFFC25E00)),
    (Color(0xFFE3EEFF), Color(0xFF2F6BDB)),
    (Color(0xFFE2F5E9), Color(0xFF2E7D32)),
    (Color(0xFFF1E6FB), Color(0xFF7B3FC4)),
    (Color(0xFFFFE4E6), Color(0xFFC62840)),
  ];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final second = parts.length > 1 ? parts[1].characters.first : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final tint = _tints[name.hashCode.abs() % _tints.length];
    Widget fallback() => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          color: tint.$1,
          child: Text(
            _initials,
            style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w700, color: tint.$2),
          ),
        );
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: sources.isEmpty
            ? fallback()
            : FallbackNetworkImage(sources: sources, width: size, height: size, placeholder: fallback),
      ),
    );
  }
}

/// Small status label: coloured dot + text (never colour alone).
class StatusTag extends StatelessWidget {
  final String text;
  final Color color;

  const StatusTag(this.text, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// Row of a long, lazily built list that should read as one grouped block:
/// the first row rounds the top corners, the last one the bottom corners,
/// and a hairline separates rows.
class GroupedTile extends StatelessWidget {
  final int index;
  final int count;
  final Widget child;

  const GroupedTile({super.key, required this.index, required this.count, required this.child});

  @override
  Widget build(BuildContext context) {
    final first = index == 0;
    final last = index == count - 1;
    final line = _hairline(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(
          top: first ? const Radius.circular(16) : Radius.zero,
          bottom: last ? const Radius.circular(16) : Radius.zero,
        ),
        border: Border(
          left: BorderSide(color: line),
          right: BorderSide(color: line),
          top: first ? BorderSide(color: line) : BorderSide.none,
          bottom: BorderSide(color: line, width: last ? 1 : 0.6),
        ),
      ),
      child: child,
    );
  }
}
