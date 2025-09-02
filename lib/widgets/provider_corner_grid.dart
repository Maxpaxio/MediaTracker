import 'package:flutter/material.dart';
import '../services/tmdb_api.dart';
import '../services/storage.dart';

class ProviderCornerGrid extends StatefulWidget {
  const ProviderCornerGrid({super.key, required this.showId, required this.mediaType, this.size = 28});
  final int showId;
  final MediaType mediaType;
  final double size; // badge size (match checkmark/bookmark)

  @override
  State<ProviderCornerGrid> createState() => _ProviderCornerGridState();
}

class _ProviderCornerGridState extends State<ProviderCornerGrid> {
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
  void didUpdateWidget(covariant ProviderCornerGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showId != widget.showId) {
      // Reset and reload for the new show
      setState(() {
        _loading = true;
        _logos = const [];
      });
      _load();
    }
  }

  Future<void> _load() async {
    try {
    final res = widget.mediaType == MediaType.movie
      ? await _api.fetchMovieWatchProviders(widget.showId, region: 'SE')
      : await _api.fetchWatchProviders(widget.showId, region: 'SE');
      final combined = <Map<String, dynamic>>[...res.streaming, ...res.rentBuy];
      if (!mounted) return;
      setState(() {
        _logos = combined.take(4).toList(growable: false); // 2x2
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Widget _placeholder(double s) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: const Color(0xCC2F2F35),
          borderRadius: BorderRadius.circular(s * 0.18),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading || _logos.isEmpty) {
      return const SizedBox.shrink();
    }

    const cols = 2;
    final size = widget.size;
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
