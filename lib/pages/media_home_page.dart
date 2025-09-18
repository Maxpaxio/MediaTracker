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
  body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            shrinkWrap: true,
            primary: false,
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              TextField(
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, HomePage.route),
                    icon: const Icon(Icons.live_tv),
                    label: const Text('TV'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, FilmsPage.route),
                    icon: const Icon(Icons.movie),
                    label: const Text('Films'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (hasQuery)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: search.searching
                      ? const Center(
                          child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ))
                      : _MultiSearchResults(search: search, onOpen: _openShow),
                ),
              if (!hasQuery) const SizedBox(height: 24),
            ],
          ),
        ),
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

class _MultiSearchResults extends StatelessWidget {
  const _MultiSearchResults({required this.search, required this.onOpen});
  final MultiSearchController search;
  final Future<void> Function(Show) onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: search.results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final item = search.results[i];
        switch (item.kind) {
          case MultiKind.tv:
          case MultiKind.movie:
            final s = item.show!;
            final storage = StorageScope.of(context);
            final existing = storage.tryGet(s.id);
            final inWatchlist = existing?.isWatchlist ?? false;
            final isCompleted = existing?.isCompleted ?? false;
      final isOngoing = existing != null &&
        !existing.isCompleted &&
        !existing.isWatchlist &&
        existing.watchedEpisodes > 0;
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
                      : Container(
                          color: const Color(0xFF2C2C32),
                          child: const Icon(Icons.broken_image)),
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
                    s.mediaType == MediaType.movie
                        ? Icons.movie
                        : Icons.live_tv,
                    size: 16,
                    color: Colors.white70,
                  ),
                ],
              ),
              subtitle: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      trailing: _AddToPill(
                    inWatchlist: inWatchlist,
                    isCompleted: isCompleted,
        isOngoing: isOngoing,
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

          case MultiKind.person:
            final name = item.personName ?? '';
            final profile = item.personProfileUrl;
            final knownFor =
                (item.knownForTitles ?? const []).take(3).join(' • ');
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
              subtitle: Text(
                knownFor.isNotEmpty ? knownFor : 'Person',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.person, color: Colors.white70),
            );
        }
      },
    );
  }
}

class _AddToPill extends StatelessWidget {
  const _AddToPill({
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
    } else if (isOngoing) {
      label = 'Ongoing';
      icon = Icons.play_circle_fill;
      bg = theme.colorScheme.primary;
      fg = theme.colorScheme.onPrimary;
    } else {
      label = 'Add to…';
      icon = Icons.add;
      bg = theme.colorScheme.surface;
      fg = theme.colorScheme.onSurface;
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
