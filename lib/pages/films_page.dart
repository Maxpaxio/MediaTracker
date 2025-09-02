import 'package:flutter/material.dart';
import '../services/sync_file_service.dart';
import '../services/storage.dart';
import '../services/movie_search_controller.dart';
import '../widgets/section_title.dart';
import '../widgets/completed_poster.dart';
import '../widgets/watchlist_poster.dart';
import '../widgets/provider_corner_grid.dart';
import 'all_movies_completed_page.dart';
import 'all_movies_watchlist_page.dart';
import 'media_home_page.dart';
import 'home_page.dart';
import 'sync_connect_page.dart';
import 'show_detail_page.dart';

class FilmsPage extends StatefulWidget {
  static const route = '/films';
  const FilmsPage({super.key});

  @override
  State<FilmsPage> createState() => _FilmsPageState();
}

class _FilmsPageState extends State<FilmsPage> {
  late final MoviesSearchController search;

  @override
  void initState() {
    super.initState();
    search = MoviesSearchController()..addListener(_onSearchNotify);
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

  @override
  Widget build(BuildContext context) {
    final storage = StorageScope.of(context);
    // Only movies: filter by mediaType
    final completed = storage.completed.where((s) => s.mediaType == MediaType.movie).toList().reversed.toList();
    final watchlist = storage.watchlist.where((s) => s.mediaType == MediaType.movie).toList().reversed.toList();

    final hasQuery = search.text.text.isNotEmpty;

    return Scaffold(
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
        title: const Text('Films'),
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
                child: Text('MediaTracker', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Search / Home'),
                onTap: () => Navigator.pushReplacementNamed(context, MediaHomePage.route),
              ),
              ListTile(
                leading: const Icon(Icons.live_tv),
                title: const Text('TV'),
                onTap: () => Navigator.pushReplacementNamed(context, HomePage.route),
              ),
              ListTile(
                leading: const Icon(Icons.movie),
                title: const Text('Films'),
                onTap: () => Navigator.pop(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud),
                title: const Text('Cloud storage'),
                onTap: () => Navigator.pushNamed(context, SyncConnectPage.route),
              ),
            ],
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Film-only search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: search.text,
                onChanged: search.onChanged,
                onSubmitted: search.onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search films…',
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

          if (hasQuery)
            SliverToBoxAdapter(
              child: search.searching
                  ? const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const SizedBox.shrink(),
            ),

          if (hasQuery && !search.searching)
            SliverList.separated(
              itemCount: search.results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = search.results[i];
                final existing = storage.tryGet(s.id);
                final inWatchlist = existing?.isWatchlist ?? false;
                final isCompleted = existing?.isCompleted ?? false;
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: s.posterUrl.isNotEmpty
                          ? Image.network(s.posterUrl, fit: BoxFit.cover)
                          : Container(
                              color: const Color(0xFF2C2C32),
                              child: const Icon(Icons.broken_image),
                            ),
                    ),
                  ),
                  title: Text(s.title),
                  subtitle: Text(
                    s.firstAirDate.isNotEmpty
                        ? 'Released: ${s.firstAirDate}'
                        : '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    final id = await search.ensureDetailInStorage(storage, s);
                    // Navigate to unified details page
                    if (context.mounted) {
                      await Navigator.pushNamed(
                        context,
                        ShowDetailPage.route,
                        arguments: ShowDetailArgs(showId: id),
                      );
                      // No need to refresh here; detail page updates storage
                    }
                  },
                  trailing: _PillActions(
                    inWatchlist: inWatchlist,
                    isCompleted: isCompleted,
                    onAddWatchlist: () async {
                      final id = await search.ensureDetailInStorage(storage, s);
                      storage.toggleWatchlist(storage.byId(id));
                    },
                    onRemoveWatchlist: () {
                      if (!storage.exists(s.id)) return;
                      storage.removeFromWatchlist(s.id);
                    },
                    onAddCompleted: () async {
                      final id = await search.ensureDetailInStorage(storage, s);
                      storage.markCompleted(storage.byId(id));
                    },
                    onRemoveCompleted: () {
                      if (!storage.exists(s.id)) return;
                      storage.removeFromCompleted(s.id);
                    },
                  ),
                );
              },
            ),

          if (!hasQuery) ...[
            // Completed movies row (horizontal like TV page) + See all
            SliverToBoxAdapter(
              child: SectionTitle(
                title: 'Completed (${completed.length})',
                onSeeAll: () => Navigator.pushNamed(context, AllMoviesCompletedPage.route),
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
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => Navigator.pushNamed(
                            context,
                            ShowDetailPage.route,
                            arguments: ShowDetailArgs(showId: completed[i].id),
                          ),
                          child: CompletedPoster(show: completed[i]),
                        ),
                      ),
              ),
            ),

            // Watchlist movies row + See all
            SliverToBoxAdapter(
              child: SectionTitle(
                title: 'Watchlist (${watchlist.length})',
                onSeeAll: () => Navigator.pushNamed(context, AllMoviesWatchlistPage.route),
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
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => Navigator.pushNamed(
                            context,
                            ShowDetailPage.route,
                            arguments: ShowDetailArgs(showId: watchlist[i].id),
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
    );
  }
}

class _PillActions extends StatelessWidget {
  const _PillActions({
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
    const green = Color(0xFF22C55E);
    const yellow = Color(0xFFFACC15);
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
