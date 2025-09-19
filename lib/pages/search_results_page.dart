import 'package:flutter/material.dart';
import '../services/multi_search_controller.dart';
import '../services/storage.dart';
import '../widgets/brand_logo.dart';
import '../widgets/add_menu.dart';
import 'home_page.dart';
import 'films_page.dart';
import 'settings_page.dart';
import 'sync_connect_page.dart';
import 'statistics_page.dart';
import 'show_detail_page.dart';
import 'subpages/more_info_page.dart';

class SearchResultsPage extends StatefulWidget {
  static const route = '/search';
  const SearchResultsPage({super.key});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  final _focus = FocusNode();
  late final MultiSearchController search;

  @override
  void initState() {
    super.initState();
    search = MultiSearchController()..addListener(_onSearchNotify);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['initialQuery'] is String) {
      final q = (args['initialQuery'] as String).trim();
      if (q.isNotEmpty && search.text.text != q) {
        search.text.text = q;
        search.onChanged(q);
        // Focus the text field so users can continue typing
        Future.microtask(() => _focus.requestFocus());
      }
    }
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
    } catch (_) {
      await Navigator.pushNamed(
        context,
        ShowDetailPage.route,
        arguments: ShowDetailArgs(showId: s.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = search.text.text.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
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
                  children: const [
                    BrandLogo(height: 72),
                    SizedBox(height: 12),
                    Text(
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
                  // Already here; no navigation needed.
                },
              ),
              ListTile(
                leading: const Icon(Icons.live_tv),
                title: const Text('TV'),
                onTap: () => Navigator.pushReplacementNamed(context, HomePage.route),
              ),
              ListTile(
                leading: const Icon(Icons.movie),
                title: const Text('Films'),
                onTap: () => Navigator.pushReplacementNamed(context, FilmsPage.route),
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Abandoned'),
                onTap: () => Navigator.pushNamed(context, '/abandoned'),
              ),
              ListTile(
                leading: const Icon(Icons.insights),
                title: const Text('Statistics'),
                onTap: () => Navigator.pushNamed(context, StatisticsPage.route),
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
                onTap: () => Navigator.pushNamed(context, SettingsPage.route),
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
            Expanded(
              child: hasQuery
                  ? AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: search.searching
                          ? const IgnorePointer(
                              ignoring: true,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : _ResultsList(search: search, onOpen: _openShow),
                    )
                  : const Center(child: Text('Type to start searching')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.search, required this.onOpen});
  final MultiSearchController search;
  final Future<void> Function(Show) onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: search.results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final item = search.results[i];
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
                      : Container(
                          color: const Color(0xFF2C2C32),
                          child: const Icon(Icons.broken_image),
                        ),
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
              subtitle: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: AddMenu(
                showId: s.id,
                onChanged: () {},
                compact: true,
                ensureInStorage: () async {
                  final storage = StorageScope.of(context);
                  try {
                    await search.ensureDetailInStorage(storage, s);
                  } catch (_) {}
                },
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
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.person, size: 16, color: Colors.white70),
                ],
              ),
              subtitle: Text(
                knownFor.isNotEmpty ? knownFor : 'Person',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const SizedBox.shrink(),
            );
        }
      },
    );
  }
}
