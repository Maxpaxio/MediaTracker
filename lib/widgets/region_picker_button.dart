import 'package:flutter/material.dart';

/// Simple region picker that shows a flag (emoji) + code. Callbacks return the
/// selected region code (uppercase). Supply a list of candidate region codes.
class RegionPickerButton extends StatelessWidget {
  const RegionPickerButton({
    super.key,
    required this.current,
    required this.candidates,
    required this.onSelected,
    this.counts = const {},
  });

  final String current;
  final List<String> candidates; // Already uppercase ISO codes
  final ValueChanged<String> onSelected;
  final Map<String, int> counts; // region -> provider count

  String _flagEmoji(String code) {
    if (code.length != 2) return '🏳️';
    final base = 0x1F1E6; // regional indicator A
    final first = base + code.codeUnitAt(0) - 0x41; // 'A'
    final second = base + code.codeUnitAt(1) - 0x41;
    return String.fromCharCodes([first, second]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = current.toUpperCase();
    return PopupMenuButton<String>(
      tooltip: 'Change region for this view',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final c in candidates)
          PopupMenuItem(
            value: c,
            child: Row(
              children: [
                Text(_flagEmoji(c)),
                const SizedBox(width: 8),
                Expanded(child: Text(c)),
                if (counts[c] != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${counts[c]}',
                        style: TextStyle(
                            fontSize: 12, color: theme.colorScheme.primary)),
                  ),
                if (c == current) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
                ]
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_flagEmoji(display)),
            const SizedBox(width: 6),
            Text(display, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}
