import 'package:flutter/material.dart';
import '../services/storage.dart';
import '../services/tmdb_api.dart';
import 'provider_corner_grid.dart';

class WatchlistPoster extends StatelessWidget {
  const WatchlistPoster({super.key, required this.show});
  final Show show;

  @override
  Widget build(BuildContext context) {
    const double posterWidth = 120;
    const double cornerPad = 8;
    const double iconSize = 28; // match completed check size
    const Color badgeColor = Color(0xFFFACC15); // watchlist yellow

    return SizedBox(
      width: posterWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster with overlays
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

              // State icon at top-right
              Positioned(
                right: cornerPad,
                top: cornerPad,
                child: const Icon(
                  Icons.bookmark,
                  size: iconSize,
                  color: badgeColor,
                ),
              ),

              // Provider logos 2x2 at top-left
              Positioned(
                left: cornerPad,
                top: cornerPad,
                child: ProviderCornerGrid(showId: show.id, mediaType: show.mediaType),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(show.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
