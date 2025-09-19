import 'package:flutter/material.dart';
import '../services/storage.dart';

/// Logo-style “Add to…” menu button that reflects current state.
/// States precedence: Abandoned (red) > Completed (green) > Watchlist (yellow) > Ongoing (primary) > None (outlined).
/// Set [compact] to true to hide the label (useful in tight list rows).
class AddMenu extends StatelessWidget {
  const AddMenu({
    super.key,
    required this.showId,
    required this.onChanged,
    this.compact = false,
    this.ensureInStorage,
  });

  final int showId;
  final VoidCallback onChanged;
  final bool compact;
  final Future<void> Function()? ensureInStorage;

  // State colors
  static const _green = Color(0xFF22C55E); // completed
  static const _yellow = Color(0xFFFACC15); // watchlist
  static const _red = Color(0xFFDC2626); // abandoned

  @override
  Widget build(BuildContext context) {
    final storage = StorageScope.of(context);
    final s = storage.tryGet(showId);

    final bool isCompleted = s?.isCompleted ?? false;
    final bool inWatchlist = s?.isWatchlist ?? false;
    final bool isOngoing = (s != null) && !inWatchlist && !isCompleted && s.watchedEpisodes > 0;
    final bool isAbandoned = s?.isAbandoned ?? false;

    // Visuals based on state (Abandoned overrides all)
    Color? bg;
    Color fg;
    IconData icon;
    String label;

    if (isAbandoned) {
      bg = _red;
      fg = Colors.white;
      icon = Icons.delete;
      label = 'Abandoned';
    } else if (isCompleted) {
      bg = _green;
      fg = Colors.black;
      icon = Icons.check_circle;
      label = 'Completed';
    } else if (inWatchlist) {
      bg = _yellow;
      fg = Colors.black;
      icon = Icons.bookmark;
      label = 'Watchlist';
    } else if (isOngoing) {
      final scheme = Theme.of(context).colorScheme;
      bg = scheme.primary;
      fg = scheme.onPrimary;
      icon = Icons.play_circle_fill;
      label = 'Ongoing';
    } else {
      bg = null; // outlined
      fg = Theme.of(context).colorScheme.onSurface;
      icon = Icons.add;
      label = 'Add to…';
    }

    return PopupMenuButton<_AddAction>(
      offset: const Offset(0, 56),
      tooltip: 'Add to…',
      onSelected: (action) async {
        // Ensure the item exists in storage (useful from search results)
        if (ensureInStorage != null) {
          try { await ensureInStorage!(); } catch (_) {}
        }
        final cur = storage.tryGet(showId);
        if (cur == null) return;

        switch (action) {
          case _AddAction.addWatchlist:
            if (!inWatchlist) {
              storage.toggleWatchlist(cur); // none ↔ watchlist
            }
            break;
          case _AddAction.removeWatchlist:
            if (inWatchlist) {
              storage.toggleWatchlist(cur); // watchlist → none
            }
            break;
          case _AddAction.markCompleted:
            if (!isCompleted) {
              storage.markCompleted(cur); // sets flag completed + fills progress
            }
            break;
          case _AddAction.removeCompleted:
            if (isCompleted) {
              final reset = cur.copyWith(
                flag: WatchFlag.none,
                seasons: [for (final ss in cur.seasons) ss.copyWith(watched: 0)],
              );
              storage.updateShow(reset);
            }
            break;
        }
        onChanged();
      },
      itemBuilder: (context) => <PopupMenuEntry<_AddAction>>[
        if (!inWatchlist)
          const PopupMenuItem(
            value: _AddAction.addWatchlist,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.bookmark_add_outlined),
              title: Text('Add to Watchlist'),
            ),
          )
        else
          const PopupMenuItem(
            value: _AddAction.removeWatchlist,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.bookmark_remove_outlined),
              title: Text('Remove from Watchlist'),
            ),
          ),
        const PopupMenuDivider(),
        if (!isCompleted)
          const PopupMenuItem(
            value: _AddAction.markCompleted,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.check_circle_outline),
              title: Text('Mark Completed'),
            ),
          )
        else
          const PopupMenuItem(
            value: _AddAction.removeCompleted,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.remove_circle_outline),
              title: Text('Remove from Completed'),
            ),
          ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bg,
              border: bg == null ? Border.all(color: Colors.white24) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 26, color: fg),
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

enum _AddAction {
  addWatchlist,
  removeWatchlist,
  markCompleted,
  removeCompleted,
}
