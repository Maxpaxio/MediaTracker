import 'package:flutter/material.dart';
import 'theme.dart';
import 'services/storage.dart';
import 'pages/home_page.dart';
import 'pages/all_completed_page.dart';
import 'pages/all_ongoing_page.dart';
import 'pages/all_watchlist_page.dart';
import 'pages/show_detail_page.dart';
import 'pages/subpages/more_info_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = AppStorage();
  await storage.init();
  runApp(MediaTrackerApp(storage: storage));
}

class MediaTrackerApp extends StatelessWidget {
  const MediaTrackerApp({super.key, required this.storage});
  final AppStorage storage;

  @override
  Widget build(BuildContext context) {
    return StorageScope(
      storage: storage,
      child: MaterialApp(
        title: 'TV Tracker',
        debugShowCheckedModeBanner: false,
        theme: buildDarkTheme(),
        routes: {
          '/': (_) => const HomePage(),
          AllOngoingPage.route: (_) => const AllOngoingPage(),
          AllCompletedPage.route: (_) => const AllCompletedPage(),
          AllWatchlistPage.route: (_) => const AllWatchlistPage(),
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
    );
  }
}
