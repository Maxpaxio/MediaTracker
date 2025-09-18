import 'package:flutter/material.dart';
import '../services/storage.dart';
import 'show_detail_page.dart';
import '../widgets/provider_corner_grid.dart';
import '../utils/sort.dart';

class AllMoviesWatchlistPage extends StatefulWidget {
  static const route = '/movies/watchlist';
  const AllMoviesWatchlistPage({super.key});

  @override
  State<AllMoviesWatchlistPage> createState() => _AllMoviesWatchlistPageState();
}

class _AllMoviesWatchlistPageState extends State<AllMoviesWatchlistPage> {
  ShowSortMode _mode = ShowSortMode.lastAdded;

  @override
  Widget build(BuildContext context) {
    final items = StorageScope.of(context)
        .watchlist
        .where((s) => s.mediaType == MediaType.movie)
        .toList()
        .sortedBy(_mode);
    return Scaffold(
      appBar: AppBar(
        title: Text('Watchlist Movies (${items.length})'),
        actions: [
          _SortButton(mode: _mode, onChanged: (m) => setState(() => _mode = m)),
        ],
      ),
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

class _SortButton extends StatelessWidget {
  const _SortButton({required this.mode, required this.onChanged});
  final ShowSortMode mode;
  final ValueChanged<ShowSortMode> onChanged;
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ShowSortMode>(
      tooltip: 'Sort',
      icon: const Icon(Icons.sort),
      initialValue: mode,
      onSelected: onChanged,
      itemBuilder: (_) => const [
        PopupMenuItem(value: ShowSortMode.lastAdded, child: Text('Last added')),
        PopupMenuItem(value: ShowSortMode.alphabetical, child: Text('Alphabetical')),
        PopupMenuItem(value: ShowSortMode.releaseYear, child: Text('Release year')),
        PopupMenuItem(value: ShowSortMode.franchise, child: Text('Franchise (beta)')),
      ],
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
          Positioned(
            left: cornerPad,
            top: cornerPad,
            child: ProviderCornerGrid(showId: show.id, mediaType: show.mediaType),
          ),
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
