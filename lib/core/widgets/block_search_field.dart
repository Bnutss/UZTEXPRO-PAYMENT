import 'package:flutter/material.dart';
import 'ui_blocks.dart';

/// Search field used by the shop screens, below their filter blocks.
class BlockSearchField extends StatelessWidget {
  const BlockSearchField({
    super.key,
    required this.controller,
    required this.hint,
  });

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kInk.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: kInk, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: kInkMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: kInkMuted),
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }
}
