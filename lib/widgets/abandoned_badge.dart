import 'package:flutter/material.dart';

/// Small red badge to indicate an item is marked Abandoned.
/// Usage:
/// - In lists (search results), show icon-only compact form.
/// - In details title area, show icon+label form when space allows.
class AbandonedBadge extends StatelessWidget {
  const AbandonedBadge({super.key, this.compact = false});

  /// If true, renders a tiny square with only the trash icon.
  /// If false, renders a pill with icon + "Abandoned" text.
  final bool compact;

  static const Color _red = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.delete, size: 14, color: Colors.white),
        if (!compact) ...[
          const SizedBox(width: 6),
          const Text(
            'Abandoned',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 4 : 4,
      ),
      decoration: BoxDecoration(
        color: _red,
        borderRadius: BorderRadius.circular(compact ? 6 : 999),
      ),
      child: child,
    );
  }
}
