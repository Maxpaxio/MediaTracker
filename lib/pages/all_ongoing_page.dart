import 'package:flutter/material.dart';
import '../services/storage.dart';
import 'show_detail_page.dart';
import '../widgets/provider_corner_grid.dart';

class AllOngoingPage extends StatelessWidget {
  static const route = '/ongoing';
  const AllOngoingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = StorageScope.of(context)
        .ongoing
        .where((s) => s.mediaType == MediaType.tv)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text('Ongoing (${items.length})')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const minCardWidth = 130.0;
          final crossAxisCount =
              (constraints.maxWidth / minCardWidth).floor().clamp(3, 12);
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              // Allow space for a progress bar and a small label under the poster
              childAspectRatio: 0.54,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => _Poster(show: items[i]),
          );
        },
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.show});
  final Show show;
  @override
  Widget build(BuildContext context) {
    const double cornerPad = 8;
    final epSeen = show.watchedEpisodes;
    final epTotal = show.totalEpisodes;
    final pct = (show.progress * 100).round();

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        ShowDetailPage.route,
        arguments: ShowDetailArgs(showId: show.id),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster with overlays
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    show.posterUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF2C2C32),
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
                // Top-left provider logos (2x2)
                Positioned(
                  left: cornerPad,
                  top: cornerPad,
                  child: ProviderCornerGrid(
                      showId: show.id, mediaType: show.mediaType),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(value: show.progress),
            ),
          ),
          const SizedBox(height: 2),
          // Episodes and percent
          Text(
            '$epSeen/$epTotal • $pct%',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  height: 1.0,
                ),
          ),
        ],
      ),
    );
  }
}
