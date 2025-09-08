import 'package:flutter/material.dart';
import '../services/storage.dart';
import 'provider_corner_grid.dart';

class CompletedPoster extends StatelessWidget {
  const CompletedPoster({super.key, required this.show});
  final Show show;

  @override
  Widget build(BuildContext context) {
    const double posterWidth = 120;
    const double cornerPad = 8;
    const double checkSize = 28; // slightly larger checkmark

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

              // Bigger checkmark at top-right
              Positioned(
                right: cornerPad,
                top: cornerPad,
                child: const Icon(
                  Icons.check_circle,
                  size: checkSize,
                  color: Color(0xFF6EE7B7),
                ),
              ),

              // Provider logos grid (4x4) at top-left, same row as checkmark
              Positioned(
                left: cornerPad,
                top: cornerPad,
                child: ProviderCornerGrid(
                    showId: show.id, mediaType: show.mediaType),
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
