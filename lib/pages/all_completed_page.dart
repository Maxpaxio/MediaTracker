import 'package:flutter/material.dart';
import '../services/storage.dart';
import 'show_detail_page.dart';
import '../widgets/provider_corner_grid.dart';
import '../utils/sort.dart';

class AllCompletedPage extends StatefulWidget {
  static const route = '/completed';
  const AllCompletedPage({super.key});

  @override
  State<AllCompletedPage> createState() => _AllCompletedPageState();
}

class _AllCompletedPageState extends State<AllCompletedPage> {
  ShowSortMode _mode = ShowSortMode.lastAdded;
  bool _ascending = defaultAscendingFor(ShowSortMode.lastAdded);

  static const _kModeKey = 'sort.completed.mode';
  static const _kAscKey = 'sort.completed.asc';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storage = StorageScope.of(context);
      final savedMode = storage.readInt(_kModeKey);
      final savedAsc = storage.readBool(_kAscKey);
      if (savedMode != null && savedMode >= 0 && savedMode < ShowSortMode.values.length) {
        setState(() {
          _mode = ShowSortMode.values[savedMode];
          _ascending = savedAsc ?? defaultAscendingFor(_mode);
        });
      } else if (savedAsc != null) {
        setState(() => _ascending = savedAsc);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
  final items = StorageScope.of(context)
    .completed
    .where((s) => s.mediaType == MediaType.tv)
    .toList()
    .sortedBy(_mode, ascending: _ascending);
    return Scaffold(
      appBar: AppBar(
        title: Text('Completed (${items.length})'),
        actions: [
          _SortButton(
            mode: _mode,
            ascending: _ascending,
            onChanged: (m) => setState(() {
              if (m == _mode) {
                _ascending = !_ascending;
              } else {
                _mode = m;
                _ascending = defaultAscendingFor(m);
              }
              final storage = StorageScope.of(context);
              storage.writeInt(_kModeKey, _mode.index);
              storage.writeBool(_kAscKey, _ascending);
            }),
          ),
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
  const _SortButton({required this.mode, required this.ascending, required this.onChanged});
  final ShowSortMode mode;
  final bool ascending;
  final ValueChanged<ShowSortMode> onChanged;
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ShowSortMode>(
      tooltip: 'Sort',
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sort),
          const SizedBox(width: 4),
          Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
        ],
      ),
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
            child: ProviderCornerGrid(showId: show.id, mediaType: show.mediaType),
          ),
          // Top-right checkmark
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
