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

  // Streaming providers limited for display on poster (max 3)
  List<Map<String, dynamic>> _streaming = const [];
  // Full lists for the sheet
  List<Map<String, dynamic>> _allStreaming = const [];
  List<Map<String, dynamic>> _rentBuy = const [];
  bool _loading = true;
  bool _hasMoreStreaming = false;
  bool _hasRentBuy = false;

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
  _streaming = const [];
  _allStreaming = const [];
  _rentBuy = const [];
  _hasMoreStreaming = false;
  _hasRentBuy = false;
      });
      _load();
    }
  }

  Future<void> _load() async {
    try {
    final res = widget.mediaType == MediaType.movie
      ? await _api.fetchMovieWatchProviders(widget.showId, region: 'SE')
      : await _api.fetchWatchProviders(widget.showId, region: 'SE');
      final streaming = (res.streaming).cast<Map<String, dynamic>>();
      final rentBuy = (res.rentBuy).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _allStreaming = streaming;
        _rentBuy = rentBuy;
        _hasRentBuy = _rentBuy.isNotEmpty;
        _hasMoreStreaming = _allStreaming.length > 3;
        _streaming = _allStreaming.take(3).toList(growable: false); // max 3 streaming logos
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openProvidersSheet() {
    if (_allStreaming.isEmpty && _rentBuy.isEmpty) return;
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        Widget logoTile(Map<String, dynamic> m) {
          final logoPath = (m['logo_path'] as String?) ?? '';
          final name = (m['provider_name'] as String?) ?? '—';
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: logoPath.isNotEmpty
                  ? Image.network('$_imgBase/w92$logoPath', width: 32, height: 32, fit: BoxFit.contain)
                  : Container(width: 32, height: 32, color: const Color(0xFF2F2F35)),
            ),
            title: Text(name),
          );
        }

        return SafeArea(
          child: SizedBox(
            height: 460,
            child: ListView(
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_allStreaming.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('Streaming', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ..._allStreaming.map(logoTile),
                ],
                if (_rentBuy.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('Rent/Buy', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ..._rentBuy.map(logoTile),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
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
  if (_loading) return const SizedBox.shrink();
  final showEllipsis = _hasMoreStreaming || _hasRentBuy;
  if (_streaming.isEmpty && !showEllipsis) return const SizedBox.shrink();

  final size = widget.size;
  const gap = 4.0;
  // total items = streaming logos + optional ellipsis badge
  final total = _streaming.length + (showEllipsis ? 1 : 0);
  final colWidth = size; // one logo per row
  final colHeight = total * size + (total - 1) * gap;

    final badges = _streaming.map((m) {
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

    // Ellipsis badge if there are more streaming providers or any rent/buy options
    if (showEllipsis) {
      badges.add(GestureDetector(
        onTap: _openProvidersSheet,
        child: Semantics(
          label: 'More providers',
          button: true,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xCC2F2F35),
              borderRadius: BorderRadius.circular(size * 0.18),
            ),
            alignment: Alignment.center,
            child: Text('…', style: TextStyle(fontSize: size * 0.9, height: 1.0)),
          ),
        ),
      ));
    }

    return Container(
      width: colWidth + 6,
      height: colHeight + 6,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (int i = 0; i < badges.length; i++) ...[
            badges[i],
            if (i != badges.length - 1) const SizedBox(height: gap),
          ],
        ],
      ),
    );
  }
}
