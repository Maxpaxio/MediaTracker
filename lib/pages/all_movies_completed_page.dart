import 'package:flutter/material.dart';
import '../services/storage.dart';
import 'show_detail_page.dart';
import '../widgets/provider_corner_grid.dart';

class AllMoviesCompletedPage extends StatelessWidget {
  static const route = '/movies/completed';
  const AllMoviesCompletedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = StorageScope.of(context)
        .completed
        .where((s) => s.mediaType == MediaType.movie)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text('Completed Movies (${items.length})')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const minCardWidth = 130.0; // poster width target
          final crossAxisCount = (constraints.maxWidth / minCardWidth)
              .floor()
              .clamp(3, 12);
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 2 / 3,
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
    const double iconSize = 28;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        ShowDetailPage.route,
        arguments: ShowDetailArgs(showId: show.id),
      ),
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
          Positioned(
            left: cornerPad,
            top: cornerPad,
            child: ProviderCornerGrid(showId: show.id, mediaType: show.mediaType),
          ),
          const Positioned(
            right: cornerPad,
            top: cornerPad,
            child: Icon(Icons.check_circle, size: iconSize, color: Color(0xFF6EE7B7)),
          ),
        ],
      ),
    );
  }
}
