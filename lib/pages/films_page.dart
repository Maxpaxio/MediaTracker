import 'package:flutter/material.dart';
import '../widgets/brand_logo.dart';
import '../services/sync_file_service.dart';
import '../services/storage.dart';
import '../services/movie_search_controller.dart';
import '../widgets/section_title.dart';
import '../widgets/add_menu.dart';
import 'search_results_page.dart';
import '../widgets/completed_poster.dart';
import '../widgets/watchlist_poster.dart';
import 'all_movies_completed_page.dart';
import 'all_movies_watchlist_page.dart';
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
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    search = MoviesSearchController()..addListener(_onSearchNotify);
  }

  @override
  void dispose() {
    search.removeListener(_onSearchNotify);
    search.dispose();
  _searchFocus.dispose();
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
        leadingWidth: 96,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.home),
              tooltip: 'Home',
              onPressed: () => Navigator.pushReplacementNamed(context, '/'),
            ),
          ],
        ),
        actions: [
          Builder(builder: (context) {
            final sync = SyncScope.of(context);
            Color color;
            switch (sync.state) {
              case SyncFileState.disconnected:
                color = Colors.white54;
                break;
              case SyncFileState.idle:
                color = Colors.lightGreenAccent;
                break;
              case SyncFileState.syncing:
                color = Colors.amberAccent;
                break;
              case SyncFileState.error:
                color = Colors.redAccent;
                break;
            }
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
              DrawerHeader(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const BrandLogo(height: 72),
                    const SizedBox(height: 12),
                    const Text(
                      'MediaTracker',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
                ListTile(
                  leading: const Icon(Icons.search),
                  title: const Text('Search'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, SearchResultsPage.route);
                  },
                ),
                // Home moved to AppBar; removed from drawer
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
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Abandoned'),
                onTap: () => Navigator.pushNamed(context, '/abandoned'),
              ),
              ListTile(
                leading: const Icon(Icons.insights),
                title: const Text('Statistics'),
                onTap: () => Navigator.pushNamed(context, '/stats'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud),
                title: const Text('Cloud storage'),
                onTap: () => Navigator.pushNamed(context, SyncConnectPage.route),
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
          // Pinned film search bar (SliverAppBar for robustness)
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            toolbarHeight: 88,
            elevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Material(
                      color: Colors.transparent,
                      child: TextField(
                        focusNode: _searchFocus,
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
                                  onPressed: () {
                                    search.clear();
                                    _searchFocus.requestFocus();
                                  },
                                  tooltip: 'Clear',
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (hasQuery)
            SliverToBoxAdapter(
              child: search.searching
                  ? const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: IgnorePointer(
                        ignoring: true,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

          if (hasQuery && !search.searching)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final s = search.results[i];
                  // ensure detail happens in AddMenu via ensureInStorage
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
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
                    await Navigator.pushNamed(
                      context,
                      ShowDetailPage.route,
                      arguments: ShowDetailArgs(showId: id),
                    );
                    // No need to refresh here; detail page updates storage
                  },
                  trailing: AddMenu(
                    showId: s.id,
                    compact: true,
                    ensureInStorage: () => search.ensureDetailInStorage(storage, s),
                    onChanged: () {},
                  ),
                      ),
                      if (i < search.results.length - 1)
                        const Divider(height: 1),
                    ],
                  );
                },
                childCount: search.results.length,
              ),
            ),

          if (!hasQuery)
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

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
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ],
      ),
  // No TMDb footer here; attribution is shown on Home and Settings only.
  bottomNavigationBar: null,
    );
  }
}


// Removed old _FilmsSearchHeaderDelegate; SliverAppBar is used instead for the pinned search header.
