import 'package:flutter/material.dart';
import '../models/show_models.dart';
import 'show_detail_page.dart';

class AllOngoingPage extends StatelessWidget {
  final List<Show> ongoingShows;
  final String apiKey;
  final String region;
  final List<Show> trackedShows;
  final VoidCallback onTrackedShowsChanged;

  const AllOngoingPage({
    super.key,
    required this.ongoingShows,
    required this.apiKey,
    required this.region,
    required this.trackedShows,
    required this.onTrackedShowsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("All Ongoing Shows")),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: ongoingShows.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2 / 3,
        ),
        itemBuilder: (context, i) {
          final show = ongoingShows[i];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShowDetailPage(
                    showId: show.tmdbId,
                    apiKey: apiKey,
                    region: region,
                    trackedShows: trackedShows,
                    onTrackedShowsChanged: onTrackedShowsChanged,
                  ),
                ),
              );
            },
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: AspectRatio(
                          aspectRatio: 2 / 3,
                          child: Image.network(
                            show.posterUrl ?? "",
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: Colors.grey.shade700),
                          ),
                        ),
                      ),
                      if (show.platformLogoUrl != null)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Image.network(
                            show.platformLogoUrl!,
                            width: 20,
                            height: 20,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  show.title,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(
                  height: 4,
                  child: LinearProgressIndicator(value: show.progress),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
