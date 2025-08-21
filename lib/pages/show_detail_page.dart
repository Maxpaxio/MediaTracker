import 'package:flutter/material.dart';
import '../models/show_models.dart';
import '../services/tmdb_api.dart';

class ShowDetailPage extends StatefulWidget {
  final int showId;
  final String apiKey;
  final String region;
  final List<Show> trackedShows;
  final VoidCallback onTrackedShowsChanged;

  const ShowDetailPage({
    super.key,
    required this.showId,
    required this.apiKey,
    required this.region,
    required this.trackedShows,
    required this.onTrackedShowsChanged,
  });

  @override
  State<ShowDetailPage> createState() => _ShowDetailPageState();
}

class _ShowDetailPageState extends State<ShowDetailPage> {
  Map<String, dynamic>? showData;
  bool loading = true;
  Show? trackedShow;
  late final TmdbApi tmdb;

  @override
  void initState() {
    super.initState();
    tmdb = TmdbApi(widget.apiKey, region: widget.region);
    _fetchShowDetails();
  }

  Future<void> _fetchShowDetails() async {
    final data = await tmdb.getShowDetail(widget.showId);
    if (data == null) return;

    final seasons = await tmdb.buildSeasonsWithEpisodeTitles(
      widget.showId,
      (data["seasons"] as List<dynamic>? ?? []),
    );
    final providerLogo = tmdb.providerLogoFromDetail(data);
    final posterSmall = tmdb.posterUrlSmallFromDetail(data);

    final existing = widget.trackedShows.firstWhere(
      (s) => s.tmdbId == widget.showId,
      orElse: () => Show.empty(),
    );

    if (existing.tmdbId != -1) {
      for (final newS in seasons) {
        final oldS = existing.seasons.firstWhere(
          (s) => s.number == newS.number,
          orElse: () => Season(number: newS.number, episodes: []),
        );
        for (final newEp in newS.episodes) {
          final oldEp = oldS.episodes.firstWhere(
            (e) => e.number == newEp.number,
            orElse: () => Episode(number: newEp.number, title: newEp.title),
          );
          newEp.watched = oldEp.watched;
        }
      }
      existing.seasons = seasons;
      existing.platformLogoUrl ??= providerLogo;
      existing.posterUrl ??= posterSmall;
      trackedShow = existing;
      widget.onTrackedShowsChanged();
    } else {
      trackedShow = Show(
        tmdbId: widget.showId,
        title: data["name"] ?? "Unknown",
        seasons: seasons,
        posterUrl: posterSmall,
        platformLogoUrl: providerLogo,
      );
      widget.trackedShows.add(trackedShow!);
      widget.onTrackedShowsChanged();
    }

    setState(() {
      showData = data;
      loading = false;
    });
  }

  void _maybeClearWatchlist() {
    if (trackedShow != null && trackedShow!.anyWatched && trackedShow!.isWatchlisted) {
      trackedShow!.isWatchlisted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final posterLarge = tmdb.posterUrlLargeFromDetail(showData!);

    return Scaffold(
      appBar: AppBar(
        title: Text(showData!["name"] ?? "Show Detail"),
        actions: [
          IconButton(
            tooltip: (trackedShow?.isWatchlisted ?? false)
                ? "Remove from Watchlist"
                : "Add to Watchlist",
            icon: Icon(
              (trackedShow?.isWatchlisted ?? false)
                  ? Icons.bookmark
                  : Icons.bookmark_outline,
            ),
            onPressed: () {
              setState(() {
                if (trackedShow != null) {
                  trackedShow!.isWatchlisted = !trackedShow!.isWatchlisted;
                }
              });
              widget.onTrackedShowsChanged();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (posterLarge != null)
              Center(
                child: SizedBox(
                  width: 160,
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(posterLarge, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              showData!["name"] ?? "",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            // Buttons row
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  icon: Icon(
                    (trackedShow?.isWatchlisted ?? false)
                        ? Icons.bookmark
                        : Icons.bookmark_outline,
                  ),
                  label: Text(
                    (trackedShow?.isWatchlisted ?? false)
                        ? "In Watchlist"
                        : "Add to Watchlist",
                  ),
                  onPressed: () {
                    setState(() {
                      if (trackedShow != null) {
                        trackedShow!.isWatchlisted =
                            !trackedShow!.isWatchlisted;
                      }
                    });
                    widget.onTrackedShowsChanged();
                  },
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text("Mark entire show watched"),
                  onPressed: () {
                    setState(() {
                      if (trackedShow != null) {
                        for (final season in trackedShow!.seasons) {
                          for (final ep in season.episodes) {
                            ep.watched = true;
                          }
                        }
                        // Starting to watch means it's no longer in the watchlist
                        _maybeClearWatchlist();
                      }
                    });
                    widget.onTrackedShowsChanged();
                  },
                ),
              ],
            ),

            if (showData!["overview"] != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(showData!["overview"]),
              ),
            if (showData!["vote_average"] != null)
              Text("Rating: ${showData!["vote_average"]}/10"),
            const Divider(),
            if (trackedShow != null)
              Column(
                children: trackedShow!.seasons.map((season) {
                  final allWatched =
                      season.episodes.every((e) => e.watched);
                  return ExpansionTile(
                    title: Row(
                      children: [
                        Expanded(child: Text("Season ${season.number}")),
                        Checkbox(
                          value: allWatched,
                          onChanged: (val) {
                            setState(() {
                              for (final ep in season.episodes) {
                                ep.watched = val ?? false;
                              }
                              _maybeClearWatchlist();
                            });
                            widget.onTrackedShowsChanged();
                          },
                        ),
                      ],
                    ),
                    children: season.episodes.map((ep) {
                      return CheckboxListTile(
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text("Ep ${ep.number}. ${ep.title}",
                            overflow: TextOverflow.ellipsis),
                        value: ep.watched,
                        onChanged: (val) {
                          setState(() {
                            ep.watched = val ?? false;
                            _maybeClearWatchlist();
                          });
                          widget.onTrackedShowsChanged();
                        },
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
