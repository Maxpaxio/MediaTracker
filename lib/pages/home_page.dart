import 'package:flutter/material.dart';
import '../services/storage.dart';
import '../services/show_search_controller.dart';
import '../services/multi_search_controller.dart'; // NEW: to integrate multi search
// (region & settings imports removed after unifying provider logos overlay)
import '../services/sync_file_service.dart';
import 'sync_connect_page.dart';
import '../widgets/section_title.dart';
import '../widgets/watchlist_poster.dart';
import '../widgets/completed_poster.dart';
import '../widgets/provider_mini_grid.dart';
import 'all_ongoing_page.dart';
import 'all_completed_page.dart';
import 'all_watchlist_page.dart';
import 'show_detail_page.dart';

class HomePage extends StatefulWidget {
  static const route = '/tv';
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ShowsSearchController
      search; // legacy (kept for any TV-only logic if needed)
  late final MultiSearchController multiSearch;
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    search = ShowsSearchController()..addListener(_onSearchNotify);
    multiSearch = MultiSearchController()..addListener(_onSearchNotify);
  }

  @override
  void dispose() {
    search.removeListener(_onSearchNotify);
    search.dispose();
    multiSearch.removeListener(_onSearchNotify);
    multiSearch.dispose();
    _searchFocus.dispose();
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
    final ongoing = storage.ongoing
        .where((s) => s.mediaType == MediaType.tv)
        .toList()
        .reversed
        .toList();
    final completed = storage.completed
        .where((s) => s.mediaType == MediaType.tv)
        .toList()
        .reversed
        .toList();
    final watchlist = storage.watchlist
        .where((s) => s.mediaType == MediaType.tv)
        .toList()
        .reversed
        .toList();

    final hasQuery = multiSearch.text.text.isNotEmpty;

    return PopScope(
      canPop: !hasQuery,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (hasQuery) {
          multiSearch.clear();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF232327), Color(0xFF1B1B1E)],
              ),
            ),
          ),
          title: const Text('TV'),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
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
          ],
        ),
        drawer: Drawer(
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const DrawerHeader(
                  child: Text('MediaTracker',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  leading: const Icon(Icons.search),
                  title: const Text('Search / Home'),
                  onTap: () => Navigator.pushReplacementNamed(context, '/'),
                ),
                ListTile(
                  leading: const Icon(Icons.live_tv),
                  title: const Text('TV'),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.movie),
                  title: const Text('Films'),
                  onTap: () => Navigator.pushNamed(context, '/films'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud),
                  title: const Text('Cloud storage'),
                  onTap: () =>
                      Navigator.pushNamed(context, SyncConnectPage.route),
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  onTap: () => Navigator.pushNamed(context, '/settings'),
                ),
              ],
            ),
          ),
        ),
        body: CustomScrollView(
          slivers: [
            // Search bar always on top
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  focusNode: _searchFocus,
                  controller: multiSearch.text,
                  onChanged: multiSearch.onChanged,
                  onSubmitted: multiSearch.onChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search TV shows…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: hasQuery
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              multiSearch.clear();
                              _searchFocus.requestFocus();
                            },
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
                child: multiSearch.searching
                    ? const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : const SizedBox.shrink(),
              ),

            // Results directly under the search bar
            if (hasQuery && !multiSearch.searching)
              SliverList.separated(
                itemCount: multiSearch.results
                    .where((r) => r.kind != MultiKind.person)
                    .length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final list = multiSearch.results
                      .where((r) => r.kind != MultiKind.person)
                      .toList();
                  final item = list[i];
                  switch (item.kind) {
                    case MultiKind.tv:
                    case MultiKind.movie:
                      final show = item.show!;
                      return _SearchRow(
                        show: show,
                        search: ShowsSearchControllerAdapter(multiSearch),
                        onOpen: () => _openShow(show),
                      );
                    case MultiKind.person:
                      // Excluded on TV page
                      return const SizedBox.shrink();
                  }
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
                          itemBuilder: (_, i) => _OngoingCardWide(
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

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ],
        ),
  // No TMDb footer here; attribution is shown on Home and Settings only.
  bottomNavigationBar: null,
      ),
    );
  }
}

/// Wide ongoing card: poster left, title + provider right column, progress lines below.
class _OngoingCardWide extends StatelessWidget {
  const _OngoingCardWide({super.key, required this.show});
  final Show show;

  @override
  Widget build(BuildContext context) {
    final epSeen = show.watchedEpisodes;
    final epTotal = show.totalEpisodes;
    final pct = (show.progress * 100).round();

    return SizedBox(
      width: 210,
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushNamed(
            context,
            ShowDetailPage.route,
            arguments: ShowDetailArgs(showId: show.id),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        show.posterUrl,
                        width: 90,
                        height: 130,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 90,
                          height: 130,
                          color: const Color(0xFF2C2C32),
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          const SizedBox(height: 6),
                          ProviderMiniGrid(
                            showId: show.id,
                            mediaType: show.mediaType,
                            size: 26,
                            row: false,
                            streamingOnly: false,
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('$epSeen/$epTotal Ep seen', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 6,
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      tween: Tween<double>(end: show.progress),
                      builder: (context, value, _) => LinearProgressIndicator(value: value),
                    ),
                  ),
                ),
                Text('Progress: $pct%', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// (right-side provider column removed in favor of 2x2 mini grid under title)

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.show,
    required this.onOpen,
    required this.search, // Updated to use the adapter
  });
  final Show show;
  final VoidCallback onOpen;
  final ShowsSearchControllerAdapter search;

  @override
  Widget build(BuildContext context) {
    final storage = StorageScope.of(context);

    final existing = storage.tryGet(show.id);
    final inWatchlist = existing?.isWatchlist ?? false;
    final isCompleted = existing?.isCompleted ?? false;
  final isOngoing = existing != null &&
    !existing.isCompleted &&
    !existing.isWatchlist &&
    existing.watchedEpisodes > 0;

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
        isOngoing: isOngoing,
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

// Adapter to reuse existing show detail ensuring logic with MultiSearchController
class ShowsSearchControllerAdapter {
  final MultiSearchController controller;
  ShowsSearchControllerAdapter(this.controller);
  Future<int> ensureDetailInStorage(AppStorage storage, Show s) async {
  return controller.ensureDetailInStorage(storage, s);
  }
}

// Person search rows are only shown on the Home (Media) page, not on the TV page.

/// Pill-shaped button that shows state and opens a bottom sheet with context-aware actions.
class _PillActionsButton extends StatelessWidget {
  const _PillActionsButton({
    required this.inWatchlist,
    required this.isCompleted,
    required this.isOngoing,
    required this.onAddWatchlist,
    required this.onRemoveWatchlist,
    required this.onAddCompleted,
    required this.onRemoveCompleted,
  });

  final bool inWatchlist;
  final bool isCompleted;
  final bool isOngoing;
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
    } else if (isOngoing) {
      label = 'Ongoing';
      icon = Icons.play_circle_fill;
      bg = theme.colorScheme.primary;
      fg = theme.colorScheme.onPrimary;
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

// (Ongoing badge replaced by using the unified pill with an "Ongoing" variant.)
