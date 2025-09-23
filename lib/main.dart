import 'package:flutter/material.dart';
import 'theme.dart';
import 'services/storage.dart';
import 'services/sync_file_service.dart';
import 'pages/home_page.dart';
import 'pages/media_home_page.dart';
import 'pages/films_page.dart';
import 'pages/all_completed_page.dart';
import 'pages/all_ongoing_page.dart';
import 'pages/all_watchlist_page.dart';
import 'pages/show_detail_page.dart';
import 'pages/subpages/more_info_page.dart';
import 'pages/sync_connect_page.dart';
import 'pages/all_movies_completed_page.dart';
import 'pages/all_movies_watchlist_page.dart';
import 'services/settings_controller.dart';
import 'pages/settings_page.dart';
import 'pages/search_results_page.dart';
import 'pages/statistics_page.dart';
import 'services/stats_controller.dart';
import 'pages/abandoned_page.dart';
import 'pages/all_abandoned_tv_page.dart';
import 'pages/all_abandoned_movies_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = AppStorage();
  await storage.init();
  final sync = SyncFileService(storage);
  await sync.init();
  final settings = SettingsController();
  await settings.init();
  final stats = StatsController(storage);
  await stats.init();
  runApp(MediaTrackerApp(storage: storage, sync: sync, settings: settings, stats: stats));
}

class MediaTrackerApp extends StatelessWidget {
  const MediaTrackerApp(
      {super.key,
      required this.storage,
      required this.sync,
      required this.settings,
      required this.stats});
  final AppStorage storage;
  final SyncFileService sync;
  final SettingsController settings;
  final StatsController stats;

  @override
  Widget build(BuildContext context) {
    return StorageScope(
      storage: storage,
      child: SyncScope(
        sync: sync,
        child: SettingsScope(
          controller: settings,
          child: StatsScope(
            controller: stats,
            child: MaterialApp(
            title: 'MediaTracker',
            debugShowCheckedModeBanner: false,
            theme: buildDarkTheme(),
            routes: {
              '/': (_) => const MediaHomePage(),
              SettingsPage.route: (_) => const SettingsPage(),
              FilmsPage.route: (_) => const FilmsPage(),
              HomePage.route: (_) => const HomePage(),
              AbandonedPage.route: (_) => const AbandonedPage(),
              SearchResultsPage.route: (_) => const SearchResultsPage(),
              AllOngoingPage.route: (_) => const AllOngoingPage(),
              AllCompletedPage.route: (_) => const AllCompletedPage(),
              AllWatchlistPage.route: (_) => const AllWatchlistPage(),
              AllMoviesCompletedPage.route: (_) =>
                  const AllMoviesCompletedPage(),
              AllMoviesWatchlistPage.route: (_) =>
                  const AllMoviesWatchlistPage(),
        AllAbandonedTvPage.route: (_) => const AllAbandonedTvPage(),
        AllAbandonedMoviesPage.route: (_) => const AllAbandonedMoviesPage(),
        StatisticsPage.route: (_) => const StatisticsPage(),
              SyncConnectPage.route: (_) => const SyncConnectPage(),
            },
            onGenerateRoute: (settings) {
              // Support explicit named route using arguments
              if (settings.name == ShowDetailPage.route) {
                return MaterialPageRoute(
                  builder: (_) => const ShowDetailPage(),
                  settings: settings,
                );
              }

              // Support path routes for PWA/deep-link robustness: /tv/<id> and /movie/<id>
              final name = settings.name ?? '';
              if (name.startsWith('/tv/')) {
                final idStr = name.substring('/tv/'.length);
                final id = int.tryParse(idStr);
                if (id != null) {
                  return MaterialPageRoute(
                    builder: (_) => const ShowDetailPage(),
                    settings: RouteSettings(
                      name: ShowDetailPage.route,
                      arguments: ShowDetailArgs(showId: id, forcedType: MediaType.tv),
                    ),
                  );
                }
              }
              if (name.startsWith('/movie/')) {
                final idStr = name.substring('/movie/'.length);
                final id = int.tryParse(idStr);
                if (id != null) {
                  return MaterialPageRoute(
                    builder: (_) => const ShowDetailPage(),
                    settings: RouteSettings(
                      name: ShowDetailPage.route,
                      arguments: ShowDetailArgs(showId: id, forcedType: MediaType.movie),
                    ),
                  );
                }
              }

              if (settings.name == MoreInfoPage.route) {
                final id = settings.arguments as int;
                return MaterialPageRoute(
                    builder: (_) => MoreInfoPage(showId: id));
              }
              if (settings.name == PersonCreditsPage.route) {
                final id = settings.arguments as int? ?? 0;
                return MaterialPageRoute(
                  builder: (_) => PersonCreditsPage(personId: id),
                );
              }
              return null;
            },
          ),
          ),
        ),
      ),
    );
  }
}
