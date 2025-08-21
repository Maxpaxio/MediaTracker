import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  final String text;
  final int? count;
  final VoidCallback? onTap;

  const SectionTitle(
    this.text, {
    super.key,
    this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = (count != null)
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
              ),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          )
        : const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Text(
              text,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            badge,
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios, size: 14),
            ]
          ],
        ),
      ),
    );
  }
}
