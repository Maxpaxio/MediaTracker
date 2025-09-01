import 'package:flutter/material.dart';
import '../services/storage.dart';
import 'show_detail_page.dart';
import '../widgets/provider_corner_grid.dart';

class AllWatchlistPage extends StatelessWidget {
  static const route = '/watchlist';
  const AllWatchlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = StorageScope.of(context).watchlist;
    return Scaffold(
      appBar: AppBar(title: Text('Watchlist (${items.length})')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const minCardWidth = 130.0;
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
    const Color badgeColor = Color(0xFFFACC15);
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
          // Top-left provider logos (2x2)
          Positioned(
            left: cornerPad,
            top: cornerPad,
            child: ProviderCornerGrid(showId: show.id),
          ),
          // Top-right bookmark
          const Positioned(
            right: cornerPad,
            top: cornerPad,
            child: Icon(Icons.bookmark, size: iconSize, color: badgeColor),
          ),
        ],
      ),
    );
  }
}
