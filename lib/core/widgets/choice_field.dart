import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import 'ui_blocks.dart';

class ChoiceOption<T> {
  final T value;
  final String label;
  const ChoiceOption(this.value, this.label);
}

/// A compact field that shows the current choice and opens a bottom sheet
/// with every option — unlike a segmented control it stays usable with any
/// number of options (e.g. a long list of shops) and never truncates names.
class ChoiceField<T> extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<ChoiceOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const ChoiceField({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.icon = Icons.storefront_rounded,
  });

  String get _currentLabel {
    for (final o in options) {
      if (o.value == selected) return o.label;
    }
    return options.isEmpty ? '' : options.first.label;
  }

  Future<void> _open(BuildContext context) async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<ChoiceOption<T>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChoiceSheet<T>(title: title, options: options, selected: selected),
    );
    if (picked != null) onChanged(picked.value);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF2F2F7),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => _open(context),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 17, color: AppColors.brandOrange),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _currentLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kInk),
                ),
              ),
              const Icon(Icons.unfold_more_rounded, size: 19, color: kInkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceSheet<T> extends StatelessWidget {
  final String title;
  final List<ChoiceOption<T>> options;
  final T selected;

  const _ChoiceSheet({required this.title, required this.options, required this.selected});

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(color: kInk.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kInk)),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                itemCount: options.length,
                separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.6, indent: 12, endIndent: 12),
                itemBuilder: (_, i) {
                  final o = options[i];
                  final active = o.value == selected;
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: Text(
                      o.label,
                      style: TextStyle(fontSize: 15, fontWeight: active ? FontWeight.w800 : FontWeight.w500, color: kInk),
                    ),
                    trailing: active ? const Icon(Icons.check_rounded, color: AppColors.brandOrange) : null,
                    onTap: () => Navigator.pop(context, o),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
