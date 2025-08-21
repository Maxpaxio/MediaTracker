import 'package:flutter/material.dart';
import '../models/show_models.dart';
import '../pages/show_detail_page.dart';

class AccordionShowTile extends StatelessWidget {
  final Show show;
  final bool isExpanded;
  final VoidCallback onExpand;
  final VoidCallback onChanged;
  final String apiKey;
  final String region;
  final List<Show> trackedShowsRef;

  const AccordionShowTile({
    super.key,
    required this.show,
    required this.isExpanded,
    required this.onExpand,
    required this.onChanged,
    required this.apiKey,
    required this.region,
    required this.trackedShowsRef,
  });

  void _maybeClearWatchlist() {
    // If any episode is watched, it should no longer be on the watchlist
    if (show.anyWatched && show.isWatchlisted) {
      show.isWatchlisted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShowDetailPage(
                    showId: show.tmdbId,
                    apiKey: apiKey,
                    region: region,
                    trackedShows: trackedShowsRef,
                    onTrackedShowsChanged: onChanged,
                  ),
                ),
              );
            },
            child: SizedBox(
              width: 60,
              height: 90, // 2:3 portrait
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: show.posterUrl != null
                    ? Image.network(show.posterUrl!, fit: BoxFit.cover)
                    : Container(color: Colors.grey.shade700),
              ),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  show.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (show.platformLogoUrl != null) ...[
                const SizedBox(width: 6),
                Image.network(show.platformLogoUrl!, width: 16, height: 16),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: show.progress,
                minHeight: 4,
              ),
              const SizedBox(height: 3),
              Text("${(show.progress * 100).toStringAsFixed(0)}%",
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
          onTap: onExpand,
        ),
        if (isExpanded)
          Column(
            children: show.seasons.map((season) {
              final allWatched = season.episodes.every((e) => e.watched);
              return ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Row(
                  children: [
                    Expanded(child: Text("Season ${season.number}")),
                    Checkbox(
                      value: allWatched,
                      onChanged: (val) {
                        // Toggle entire season
                        for (final ep in season.episodes) {
                          ep.watched = val ?? false;
                        }
                        _maybeClearWatchlist();
                        onChanged();
                      },
                    ),
                  ],
                ),
                children: season.episodes.map((ep) {
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text("Ep ${ep.number}. ${ep.title}",
                        overflow: TextOverflow.ellipsis),
                    value: ep.watched,
                    onChanged: (val) {
                      ep.watched = val ?? false;
                      _maybeClearWatchlist();
                      onChanged();
                    },
                  );
                }).toList(),
              );
            }).toList(),
          ),
      ],
    );
  }
}
