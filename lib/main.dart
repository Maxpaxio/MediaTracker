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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = AppStorage();
  await storage.init();
  final sync = SyncFileService(storage);
  await sync.init();
  runApp(MediaTrackerApp(storage: storage, sync: sync));
}

class MediaTrackerApp extends StatelessWidget {
  const MediaTrackerApp({super.key, required this.storage, required this.sync});
  final AppStorage storage;
  final SyncFileService sync;

  @override
  Widget build(BuildContext context) {
    return StorageScope(
      storage: storage,
      child: SyncScope(
        sync: sync,
        child: MaterialApp(
        title: 'TV Tracker',
        debugShowCheckedModeBanner: false,
        theme: buildDarkTheme(),
        routes: {
          '/': (_) => const MediaHomePage(),
          FilmsPage.route: (_) => const FilmsPage(),
          HomePage.route: (_) => const HomePage(),
          AllOngoingPage.route: (_) => const AllOngoingPage(),
          AllCompletedPage.route: (_) => const AllCompletedPage(),
          AllWatchlistPage.route: (_) => const AllWatchlistPage(),
          AllMoviesCompletedPage.route: (_) => const AllMoviesCompletedPage(),
          AllMoviesWatchlistPage.route: (_) => const AllMoviesWatchlistPage(),
            SyncConnectPage.route: (_) => const SyncConnectPage(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == ShowDetailPage.route) {
            return MaterialPageRoute(
              builder: (_) => const ShowDetailPage(), // ✅ no args param
              settings:
                  settings, // ✅ keep settings so arguments are available inside
            );
          }

          if (settings.name == MoreInfoPage.route) {
            final id = settings.arguments as int;
            return MaterialPageRoute(builder: (_) => MoreInfoPage(showId: id));
          }
          return null;
        },
        ),
      ),
    );
  }
}
