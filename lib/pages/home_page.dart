import 'package:flutter/material.dart';
import '../models/show_models.dart';
import '../widgets/accordion_show_tile.dart';
import '../widgets/completed_poster.dart';
import '../widgets/watchlist_poster.dart';
import '../widgets/section_title.dart';
import 'all_completed_page.dart';
import 'all_ongoing_page.dart';
import 'all_watchlist_page.dart';
import 'show_detail_page.dart';
import '../services/tmdb_api.dart';

class HomePage extends StatefulWidget {
  final List<Show> trackedShows;
  final int? expandedShowId;
  final void Function(int id) onExpandedChanged;
  final VoidCallback onTrackedShowsChanged;

  const HomePage({
    super.key,
    required this.trackedShows,
    required this.expandedShowId,
    required this.onExpandedChanged,
    required this.onTrackedShowsChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final String apiKey = "6f8c0bbf88560ad26d47fcfa5f12cdc4";
  static const String region = "SE";

  late final TmdbApi tmdb;
  final TextEditingController _searchCtrl = TextEditingController();
  List<dynamic> searchResults = [];
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    tmdb = TmdbApi(apiKey, region: region);
  }

  Future<void> _searchTMDB(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        isSearching = false;
      });
      return;
    }
    setState(() => isSearching = true);
    final results = await tmdb.searchShows(query);
    setState(() {
      searchResults = results;
      isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ongoing = widget.trackedShows
        .where((s) => s.anyWatched && !s.allWatched)
        .toList()
        .reversed
        .toList();

    final completed = widget.trackedShows
        .where((s) => s.allWatched)
        .toList()
        .reversed
        .toList();

    final watchlist = widget.trackedShows
        .where((s) => s.isWatchlisted)
        .toList()
        .reversed
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            setState(() {
              _searchCtrl.clear();
              searchResults = [];
              isSearching = false;
            });
          },
          child: const Text("TV Tracker"),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // 🔎 SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "Search for a show…",
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: _searchTMDB,
            ),
          ),

          if (isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            ),

          if (searchResults.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: searchResults.length,
              itemBuilder: (context, i) {
                final r = searchResults[i] as Map<String, dynamic>;
                final poster = r["poster_path"] != null
                    ? "https://image.tmdb.org/t/p/w154${r["poster_path"]}"
                    : null;
                return ListTile(
                  leading: poster != null
                      ? SizedBox(
                          width: 50,
                          child: AspectRatio(
                            aspectRatio: 2 / 3,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(poster, fit: BoxFit.cover),
                            ),
                          ),
                        )
                      : const Icon(Icons.tv),
                  title: Text(r["name"] ?? "Unknown"),
                  subtitle:
                      Text("First Air: ${r["first_air_date"] ?? "—"}"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShowDetailPage(
                          showId: r["id"],
                          apiKey: apiKey,
                          region: region,
                          trackedShows: widget.trackedShows,
                          onTrackedShowsChanged:
                              widget.onTrackedShowsChanged,
                        ),
                      ),
                    );
                  },
                );
              },
            ),

          // ONGOING
          SectionTitle(
            "Ongoing Shows",
            count: ongoing.length,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AllOngoingPage(
                    ongoingShows: ongoing,
                    apiKey: apiKey,
                    region: region,
                    trackedShows: widget.trackedShows,
                    onTrackedShowsChanged: widget.onTrackedShowsChanged,
                  ),
                ),
              );
            },
          ),
          if (ongoing.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("No ongoing shows yet"),
            )
          else
            Column(
              children: ongoing.take(3).map((s) {
                return AccordionShowTile(
                  show: s,
                  isExpanded: widget.expandedShowId == s.tmdbId,
                  onExpand: () => widget.onExpandedChanged(s.tmdbId),
                  onChanged: widget.onTrackedShowsChanged,
                  apiKey: apiKey,
                  region: region,
                  trackedShowsRef: widget.trackedShows,
                );
              }).toList(),
            ),

          const SizedBox(height: 12),

          // COMPLETED (tighter horizontal row)
          SectionTitle(
            "Completed Shows",
            count: completed.length,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AllCompletedPage(
                    completedShows: completed,
                    apiKey: apiKey,
                    region: region,
                    trackedShows: widget.trackedShows,
                    onTrackedShowsChanged: widget.onTrackedShowsChanged,
                  ),
                ),
              );
            },
          ),
          if (completed.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("No shows completed yet"),
            )
          else
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: completed.take(6).length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final show = completed[i];
                  return CompletedPoster(
                    show: show,
                    apiKey: apiKey,
                    region: region,
                    trackedShows: widget.trackedShows,
                    onTrackedShowsChanged: widget.onTrackedShowsChanged,
                    width: 90,
                  );
                },
              ),
            ),

          const SizedBox(height: 12),

          // WATCHLIST (tighter horizontal row)
          SectionTitle(
            "Watchlist",
            count: watchlist.length,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AllWatchlistPage(
                    watchlist: watchlist,
                    apiKey: apiKey,
                    region: region,
                    trackedShows: widget.trackedShows,
                    onTrackedShowsChanged: widget.onTrackedShowsChanged,
                  ),
                ),
              );
            },
          ),
          if (watchlist.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Your watchlist is empty"),
            )
          else
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: watchlist.take(6).length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final show = watchlist[i];
                  return WatchlistPoster(
                    show: show,
                    apiKey: apiKey,
                    region: region,
                    trackedShows: widget.trackedShows,
                    onTrackedShowsChanged: widget.onTrackedShowsChanged,
                    width: 90,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
