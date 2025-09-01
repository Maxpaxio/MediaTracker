import 'package:flutter/material.dart';
import '../services/storage.dart';
import '../services/show_search_controller.dart';
import '../services/tmdb_api.dart'; // NEW: to fetch provider logos
import '../services/sync_file_service.dart';
import 'sync_connect_page.dart';
import '../widgets/section_title.dart';
import '../widgets/watchlist_poster.dart';
import '../widgets/completed_poster.dart';
import 'all_ongoing_page.dart';
import 'all_completed_page.dart';
import 'all_watchlist_page.dart';
import 'show_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ShowsSearchController search;

  @override
  void initState() {
    super.initState();
    search = ShowsSearchController()..addListener(_onSearchNotify);
  }

  @override
  void dispose() {
    search.removeListener(_onSearchNotify);
    search.dispose();
    super.dispose();
  }

  void _onSearchNotify() {
    if (mounted) setState(() {});
  }

  Future<void> _openShow(Show s) async {
    final storage = StorageScope.of(context);
    try {
      final id = await search.ensureDetailInStorage(storage, s);
      await Navigator.pushNamed(
        context,
        ShowDetailPage.route,
        arguments: ShowDetailArgs(showId: id),
      );
      if (mounted) setState(() {}); // refresh pills after return
    } catch (_) {
      await Navigator.pushNamed(
        context,
        ShowDetailPage.route,
        arguments: ShowDetailArgs(showId: s.id),
      );
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = StorageScope.of(context);
  // Show newest-added first by reversing the lists at display time
  final ongoing = List<Show>.from(storage.ongoing.reversed);
  final completed = List<Show>.from(storage.completed.reversed);
  final watchlist = List<Show>.from(storage.watchlist.reversed);

    final hasQuery = search.text.text.isNotEmpty;

    return WillPopScope(
      onWillPop: () async {
        if (hasQuery) {
          search.clear();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TV Tracker'),
          actions: [
            Builder(builder: (context) {
              final sync = SyncScope.of(context);
              final color = switch (sync.state) {
                SyncFileState.disconnected => Colors.white54,
                SyncFileState.idle => Colors.lightGreenAccent,
                SyncFileState.syncing => Colors.amberAccent,
                SyncFileState.error => Colors.redAccent,
              };
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.circle, size: 10, color: color),
              );
            }),
            IconButton(
              tooltip: 'Sync now',
              onPressed: () => SyncScope.of(context).syncNow(),
              icon: const Icon(Icons.sync),
            ),
            IconButton(
              tooltip: 'Connect storage',
              onPressed: () => Navigator.pushNamed(context, SyncConnectPage.route),
              icon: const Icon(Icons.cloud),
            ),
          ],
        ),
        body: CustomScrollView(
          slivers: [
            // Search bar always on top
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: search.text,
                  onChanged: search.onChanged,
                  onSubmitted: search.onChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search TV shows…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: hasQuery
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: search.clear,
                            tooltip: 'Clear',
                          )
                        : null,
                  ),
                ),
              ),
            ),

            // Searching indicator
            if (hasQuery)
              SliverToBoxAdapter(
                child: search.searching
                    ? const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : const SizedBox.shrink(),
              ),

            // Results directly under the search bar
            if (hasQuery && !search.searching)
              SliverList.separated(
                itemCount: search.results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final s = search.results[i];
                  return _SearchRow(
                    show: s,
                    search: search,
                    onOpen: () => _openShow(s),
                  );
                },
              ),

            // Shelves when not searching
            if (!hasQuery) ...[
              // Ongoing
              SliverToBoxAdapter(
                child: SectionTitle(
                  title: 'Ongoing (${ongoing.length})',
                  onSeeAll: () =>
                      Navigator.pushNamed(context, AllOngoingPage.route),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 205,
                  child: ongoing.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Nothing added yet'),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: ongoing.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (_, i) => _OngoingCard(
                            key: ValueKey('ongoing-${ongoing[i].id}'),
                            show: ongoing[i],
                          ),
                        ),
                ),
              ),

              // Completed
              SliverToBoxAdapter(
                child: SectionTitle(
                  title: 'Completed (${completed.length})',
                  onSeeAll: () =>
                      Navigator.pushNamed(context, AllCompletedPage.route),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 205,
                  child: completed.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Nothing added yet'),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: completed.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (_, i) => GestureDetector(
                            key: ValueKey('completed-${completed[i].id}'),
                            onTap: () => Navigator.pushNamed(
                              context,
                              ShowDetailPage.route,
                              arguments:
                                  ShowDetailArgs(showId: completed[i].id),
                            ),
                            child: CompletedPoster(show: completed[i]),
                          ),
                        ),
                ),
              ),

              // Watchlist
              SliverToBoxAdapter(
                child: SectionTitle(
                  title: 'Watchlist (${watchlist.length})',
                  onSeeAll: () =>
                      Navigator.pushNamed(context, AllWatchlistPage.route),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 205,
                  child: watchlist.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Nothing added yet'),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: watchlist.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (_, i) => GestureDetector(
                            key: ValueKey('watchlist-${watchlist[i].id}'),
                            onTap: () => Navigator.pushNamed(
                              context,
                              ShowDetailPage.route,
                              arguments:
                                  ShowDetailArgs(showId: watchlist[i].id),
                            ),
                            child: WatchlistPoster(show: watchlist[i]),
                          ),
                        ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ongoing card with provider **logos from TMDb** (same as details), placed under title.
/// Ongoing card with provider **logos from TMDb** (same as details), placed under title.
class _OngoingCard extends StatelessWidget {
  const _OngoingCard({super.key, required this.show});
  final Show show;

  @override
  Widget build(BuildContext context) {
    final epSeen = show.watchedEpisodes;
    final epTotal = show.totalEpisodes;
    final pct = (show.progress * 100).round();

    return SizedBox(
      width: 210, // tightened overall width
      child: Card(
        margin: EdgeInsets.zero, // no extra margin
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pushNamed(
              context,
              ShowDetailPage.route,
              arguments: ShowDetailArgs(showId: show.id),
            );
          },
          child: Padding(
            // less right/bottom padding
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: poster + right column (title + logos)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Poster
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        show.posterUrl,
                        width: 90,
                        height: 130,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 70,
                          height: 105,
                          color: const Color(0xFF2C2C32),
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Right side: title + provider logos grid
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            show.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // TMDb provider logos
                          _ProviderLogosGrid(showId: show.id),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Ep seen line
                Text(
                  '$epSeen/$epTotal Ep seen',
                  style: Theme.of(context).textTheme.bodySmall,
                ),

                // Progress bar
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(value: show.progress),
                  ),
                ),

                // Percentage
                Text(
                  'Progress: $pct%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact grid that fetches watch providers from TMDb (same as details)
/// and renders their logos (up to 8) under the title.
class _ProviderLogosGrid extends StatefulWidget {
  const _ProviderLogosGrid({required this.showId});
  final int showId;

  @override
  State<_ProviderLogosGrid> createState() => _ProviderLogosGridState();
}

class _ProviderLogosGridState extends State<_ProviderLogosGrid> {
  static const _imgBase = 'https://image.tmdb.org/t/p';
  final _api = TmdbApi();

  List<Map<String, dynamic>> _logos = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.fetchWatchProviders(widget.showId, region: 'SE');
      final combined = <Map<String, dynamic>>[
        ...res.streaming,
        ...res.rentBuy,
      ];
      setState(() {
        _logos = combined.take(8).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Widget _placeholder() => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF2F2F35),
          borderRadius: BorderRadius.circular(6),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 60);
    }
    if (_logos.isEmpty) {
      return const SizedBox.shrink();
    }

    final badges = _logos.map((m) {
      final logoPath = (m['logo_path'] as String?) ?? '';
      if (logoPath.isEmpty) return _placeholder();
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          '$_imgBase/w92$logoPath',
      // Let the image fill the grid cell and scale as needed
      fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }).toList();

    // 3 across (slightly larger logos), up to 2 rows (6 items visible)
    const cols = 3;
    const size = 32.0; // desired visual size per cell
    const gap = 6.0;
    final rows = ((badges.length + cols - 1) ~/ cols).clamp(1, 2);
    final gridHeight = rows * size + (rows - 1) * gap;

    return SizedBox(
      height: gridHeight,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: badges.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: cols,
      mainAxisSpacing: gap,
      crossAxisSpacing: gap,
          childAspectRatio: 1,
        ),
        itemBuilder: (_, i) => badges[i],
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.show,
    required this.onOpen,
    required this.search,
  });
  final Show show;
  final VoidCallback onOpen;
  final ShowsSearchController search;

  @override
  Widget build(BuildContext context) {
    final storage = StorageScope.of(context);

    final existing = storage.tryGet(show.id);
    final inWatchlist = existing?.isWatchlist ?? false;
    final isCompleted = existing?.isCompleted ?? false;

    return ListTile(
      onTap: onOpen,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: show.posterUrl.isNotEmpty
              ? Image.network(show.posterUrl, fit: BoxFit.cover)
              : Container(
                  color: const Color(0xFF2C2C32),
                  child: const Icon(Icons.broken_image),
                ),
        ),
      ),
      title: Text(show.title),
      subtitle: Text(
        show.firstAirDate.isNotEmpty
            ? 'First aired: ${show.firstAirDate}'
            : '—',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _PillActionsButton(
        inWatchlist: inWatchlist,
        isCompleted: isCompleted,
        // Ensure detail before mutating, so we never insert an "empty seasons" show
        onAddWatchlist: () async {
          final id = await search.ensureDetailInStorage(storage, show);
          storage.toggleWatchlist(storage.byId(id));
        },
        onRemoveWatchlist: () {
          if (!storage.exists(show.id)) return;
          storage.removeFromWatchlist(show.id);
        },
        onAddCompleted: () async {
          final id = await search.ensureDetailInStorage(storage, show);
          storage.markCompleted(storage.byId(id));
        },
        onRemoveCompleted: () {
          if (!storage.exists(show.id)) return;
          storage.removeFromCompleted(show.id);
        },
      ),
    );
  }
}

/// Pill-shaped button that shows state and opens a bottom sheet with context-aware actions.
class _PillActionsButton extends StatelessWidget {
  const _PillActionsButton({
    required this.inWatchlist,
    required this.isCompleted,
    required this.onAddWatchlist,
    required this.onRemoveWatchlist,
    required this.onAddCompleted,
    required this.onRemoveCompleted,
  });

  final bool inWatchlist;
  final bool isCompleted;
  final Future<void> Function() onAddWatchlist;
  final VoidCallback onRemoveWatchlist;
  final Future<void> Function() onAddCompleted;
  final VoidCallback onRemoveCompleted;

  @override
  Widget build(BuildContext context) {
    // Colors
    const green = Color(0xFF22C55E); // completed
    const yellow = Color(0xFFFACC15); // watchlist
    final theme = Theme.of(context);

    String label;
    IconData icon;
    Color? bg;
    Color? fg;

    if (isCompleted) {
      label = 'Completed';
      icon = Icons.check_circle;
      bg = green;
      fg = Colors.black;
    } else if (inWatchlist) {
      label = 'Watchlist';
      icon = Icons.bookmark;
      bg = yellow;
      fg = Colors.black;
    } else {
      label = 'Not added';
      icon = Icons.add;
      bg = theme.colorScheme.surface;
      fg = theme.colorScheme.onSurface;
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: bg,
        foregroundColor: fg,
        side: BorderSide(
          color: (bg == theme.colorScheme.surface)
              ? Colors.white24
              : Colors.transparent,
        ),
      ),
      onPressed: () async {
        await showModalBottomSheet(
          context: context,
          backgroundColor: theme.cardColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (_) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!inWatchlist)
                    ListTile(
                      leading: const Icon(Icons.bookmark_add_outlined),
                      title: const Text('Add to Watchlist'),
                      onTap: () async {
                        Navigator.pop(context);
                        await onAddWatchlist();
                      },
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.bookmark_remove_outlined),
                      title: const Text('Remove from Watchlist'),
                      onTap: () {
                        Navigator.pop(context);
                        onRemoveWatchlist();
                      },
                    ),
                  const Divider(height: 1),
                  if (!isCompleted)
                    ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: const Text('Add to Completed'),
                      onTap: () async {
                        Navigator.pop(context);
                        await onAddCompleted();
                      },
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.remove_circle_outline),
                      title: const Text('Remove from Completed'),
                      onTap: () {
                        Navigator.pop(context);
                        onRemoveCompleted();
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
