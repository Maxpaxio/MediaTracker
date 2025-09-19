import 'package:flutter/material.dart';
import '../widgets/brand_logo.dart';
import '../services/storage.dart';
import '../services/multi_search_controller.dart';
import '../services/sync_file_service.dart';
import 'home_page.dart';
import 'films_page.dart';
import 'show_detail_page.dart';
import 'sync_connect_page.dart';
import 'subpages/more_info_page.dart'; // for PersonCreditsPage
import '../widgets/tmdb_attribution.dart';
import '../widgets/add_menu.dart';
import 'search_results_page.dart';

class MediaHomePage extends StatefulWidget {
  static const route = '/';
  const MediaHomePage({super.key});

  @override
  State<MediaHomePage> createState() => _MediaHomePageState();
}

class _MediaHomePageState extends State<MediaHomePage> {
  final _focus = FocusNode();
  late final MultiSearchController search;

  @override
  void initState() {
    super.initState();
    search = MultiSearchController()..addListener(_onSearchNotify);
    // Autofocus when landing here
    Future.microtask(() => _focus.requestFocus());
  }

  @override
  void dispose() {
    search.removeListener(_onSearchNotify);
    search.dispose();
    _focus.dispose();
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
      if (mounted) setState(() {});
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
    // Seed initial query from navigation arguments (e.g., drawer search)
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['initialQuery'] is String) {
      final q = (args['initialQuery'] as String).trim();
      if (q.isNotEmpty && search.text.text != q) {
        search.text.text = q;
        search.onChanged(q);
      }
    }
    final hasQuery = search.text.text.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('MediaTracker'),
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
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
              // Home is already current; removed from drawer for consistency with TV/Films
              ListTile(
                leading: const Icon(Icons.live_tv),
                title: const Text('TV'),
                onTap: () =>
                    Navigator.pushReplacementNamed(context, HomePage.route),
              ),
              ListTile(
                leading: const Icon(Icons.movie),
                title: const Text('Films'),
                onTap: () =>
                    Navigator.pushReplacementNamed(context, FilmsPage.route),
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
          SliverPersistentHeader(
            pinned: true,
            delegate: _HomeSearchHeaderDelegate(
              minExtentHeight: 88,
              maxExtentHeight: 88,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Material(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: TextField(
                        focusNode: _focus,
                        controller: search.text,
                        onChanged: search.onChanged,
                        onSubmitted: search.onChanged,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search movies, TV shows, and people…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: hasQuery
                              ? IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Clear',
                                  onPressed: () {
                                    search.clear();
                                    _focus.requestFocus();
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                )),
            ),
          ),

          // Nav buttons row
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pushReplacementNamed(context, HomePage.route),
                        icon: const Icon(Icons.live_tv),
                        label: const Text('TV'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, FilmsPage.route),
                        icon: const Icon(Icons.movie),
                        label: const Text('Films'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Search results / placeholder
          if (hasQuery && search.searching)
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            ),

          if (hasQuery && !search.searching)
            SliverList.separated(
              itemCount: search.results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Builder(
                        builder: (_) => _MultiSearchItem(index: i, search: search, onOpen: _openShow),
                      ),
                    ),
                  ),
                );
              },
            ),

          if (!hasQuery)
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: const TmdbAttribution(center: true, textAbove: true, height: 72),
        ),
      ),
    );
  }
}

class _HomeSearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  _HomeSearchHeaderDelegate({
    required this.child,
    required this.minExtentHeight,
    required this.maxExtentHeight,
  });
  final Widget child;
  final double minExtentHeight;
  final double maxExtentHeight;

  @override
  double get minExtent => minExtentHeight;

  @override
  double get maxExtent => maxExtentHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: maxExtent,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeSearchHeaderDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.minExtentHeight != minExtentHeight ||
        oldDelegate.maxExtentHeight != maxExtentHeight;
  }
}

// (Old _MultiSearchResults removed; SliverList now used)

// Single list item builder used by the SliverList above
class _MultiSearchItem extends StatelessWidget {
  const _MultiSearchItem({required this.index, required this.search, required this.onOpen});
  final int index;
  final MultiSearchController search;
  final Future<void> Function(Show) onOpen;

  @override
  Widget build(BuildContext context) {
    final item = search.results[index];
    switch (item.kind) {
      case MultiKind.tv:
      case MultiKind.movie:
        final s = item.show!;
        final subtitle = s.firstAirDate.isNotEmpty
            ? (s.mediaType == MediaType.movie
                ? 'Released: ${s.firstAirDate}'
                : 'First aired: ${s.firstAirDate}')
            : '—';

        return ListTile(
          onTap: () => onOpen(s),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: s.posterUrl.isNotEmpty
                  ? Image.network(s.posterUrl, fit: BoxFit.cover)
                  : Container(color: const Color(0xFF2C2C32), child: const Icon(Icons.broken_image)),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                s.mediaType == MediaType.movie ? Icons.movie : Icons.live_tv,
                size: 16,
                color: Colors.white70,
              ),
            ],
          ),
          subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: AddMenu(
            showId: s.id,
            compact: true,
            ensureInStorage: () => _ensureDetailInStorage(context, search, s),
            onChanged: () {},
          ),
        );

      case MultiKind.person:
        final name = item.personName ?? '';
        final profile = item.personProfileUrl;
        final knownFor = (item.knownForTitles ?? const []).take(3).join(' • ');
        return ListTile(
          onTap: () => Navigator.pushNamed(
            context,
            PersonCreditsPage.route,
            arguments: item.personId,
          ),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF2C2C32),
            backgroundImage: profile != null ? NetworkImage(profile) : null,
            child: profile == null ? const Icon(Icons.person) : null,
          ),
          titleTextStyle: Theme.of(context).textTheme.titleMedium,
          title: Text(name),
          subtitle: Text(knownFor.isNotEmpty ? knownFor : 'Person', maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.person, color: Colors.white70),
        );
    }
  }

  Future<int> _ensureDetailInStorage(BuildContext context, MultiSearchController search, Show s) {
    return search.ensureDetailInStorage(StorageScope.of(context), s);
  }
}

