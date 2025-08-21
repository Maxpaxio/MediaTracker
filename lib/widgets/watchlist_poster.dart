import 'package:flutter/material.dart';
import '../models/show_models.dart';
import '../pages/show_detail_page.dart';

class WatchlistPoster extends StatelessWidget {
  final Show show;
  final String apiKey;
  final String region;
  final List<Show> trackedShows;
  final VoidCallback onTrackedShowsChanged;

  /// Optional fixed width for horizontal rows; leave null in grid pages.
  final double? width;

  const WatchlistPoster({
    super.key,
    required this.show,
    required this.apiKey,
    required this.region,
    required this.trackedShows,
    required this.onTrackedShowsChanged,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final card = Column(
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
              const Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.bookmark,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // 🔒 Force single-line ellipsis under poster width
        Text(
          show.title,
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    final content = width != null
        ? SizedBox(width: width, child: card)
        : card;

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
      child: content,
    );
  }
}
