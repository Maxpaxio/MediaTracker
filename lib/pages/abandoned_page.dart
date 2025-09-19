import 'package:flutter/material.dart';
import '../widgets/brand_logo.dart';
import '../services/storage.dart';
import '../widgets/section_title.dart';
import '../widgets/provider_corner_grid.dart';
import 'all_abandoned_tv_page.dart';
import 'all_abandoned_movies_page.dart';
import 'home_page.dart';
import 'films_page.dart';
import 'search_results_page.dart';
import 'settings_page.dart';
import 'statistics_page.dart';
import 'sync_connect_page.dart';
import 'show_detail_page.dart';

class AbandonedPage extends StatelessWidget {
  static const route = '/abandoned';
  const AbandonedPage({super.key});

  @override
  Widget build(BuildContext context) {
  final storage = StorageScope.of(context);
  final tv = storage.abandoned
    .where((s) => s.mediaType == MediaType.tv)
    .toList()
    .reversed
    .toList();
  final movies = storage.abandoned
    .where((s) => s.mediaType == MediaType.movie)
    .toList()
    .reversed
    .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Abandoned'),
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
                  Navigator.pushNamed(context, SearchResultsPage.route);
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
                onTap: () => Navigator.pop(context),
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
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: tv.isEmpty && movies.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No abandoned items yet. Items you stopped midway will show up here.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          // Films row
          if (movies.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionTitle(
                title: 'Films (${movies.length})',
                onSeeAll: () => Navigator.pushNamed(context, AllAbandonedMoviesPage.route),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 205,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: movies.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => Navigator.pushNamed(
                      context,
                      ShowDetailPage.route,
                      arguments: ShowDetailArgs(showId: movies[i].id),
                    ),
                    child: _AbandonedPoster(show: movies[i]),
                  ),
                ),
              ),
            ),
          ],

          // TV row
          if (tv.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionTitle(
                title: 'TV (${tv.length})',
                onSeeAll: () => Navigator.pushNamed(context, AllAbandonedTvPage.route),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 205,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: tv.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => Navigator.pushNamed(
                      context,
                      ShowDetailPage.route,
                      arguments: ShowDetailArgs(showId: tv[i].id),
                    ),
                    child: _AbandonedPoster(show: tv[i]),
                  ),
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

class _AbandonedPoster extends StatelessWidget {
  const _AbandonedPoster({required this.show});
  final Show show;

  @override
  Widget build(BuildContext context) {
    const double posterWidth = 120;
    const double cornerPad = 8;
  const double badgeSize = 28;
    const Color badgeColor = Color(0xFFEF4444); // red-500

    return SizedBox(
      width: posterWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: Image.network(
                    show.posterUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF2C2C32),
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              ),
              // Trash icon top-right (Abandoned)
              const Positioned(
                right: cornerPad,
                top: cornerPad,
                child: Icon(
                  Icons.delete,
                  size: badgeSize,
                  color: badgeColor,
                ),
              ),
              // Providers top-left
              Positioned(
                left: cornerPad,
                top: cornerPad,
                child: ProviderCornerGrid(showId: show.id, mediaType: show.mediaType),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            show.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
