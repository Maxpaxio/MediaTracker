import 'package:flutter/material.dart';
import '../services/storage.dart';
import '../services/tmdb_api.dart';

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
                child: _ProviderCornerGrid(showId: show.id),
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

class _ProviderCornerGrid extends StatefulWidget {
  const _ProviderCornerGrid({required this.showId});
  final int showId;

  @override
  State<_ProviderCornerGrid> createState() => _ProviderCornerGridState();
}

class _ProviderCornerGridState extends State<_ProviderCornerGrid> {
  static const _imgBase = 'https://image.tmdb.org/t/p';
  final _api = TmdbApi();

  List<Map<String, dynamic>> _logos = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ProviderCornerGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showId != widget.showId) {
      setState(() {
        _loading = true;
        _logos = const [];
      });
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final res = await _api.fetchWatchProviders(widget.showId, region: 'SE');
      final combined = <Map<String, dynamic>>[...res.streaming, ...res.rentBuy];
      if (!mounted) return;
      setState(() {
        _logos = combined.take(4).toList(growable: false); // 2x2 max
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Widget _placeholder(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xCC2F2F35),
          borderRadius: BorderRadius.circular(size * 0.18),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading || _logos.isEmpty) {
      return const SizedBox.shrink();
    }

    // 2x2 grid to match checkmark size visually
    const cols = 2;
    const size = 28.0; // ~ same as checkmark
    const gap = 4.0;
    final rows = (((_logos.length + cols - 1) ~/ cols)).clamp(1, 2);
    final gridWidth = cols * size + (cols - 1) * gap;
    final gridHeight = rows * size + (rows - 1) * gap;

    final badges = _logos.map((m) {
      final logoPath = (m['logo_path'] as String?) ?? '';
      if (logoPath.isEmpty) return _placeholder(size);
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.18),
        child: Image.network(
          '$_imgBase/w92$logoPath',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _placeholder(size),
        ),
      );
    }).toList();

    return Container(
      width: gridWidth,
      height: gridHeight,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(3),
        itemCount: badges.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          childAspectRatio: 1,
        ),
        itemBuilder: (_, i) => badges[i],
      ),
    );
  }
}
