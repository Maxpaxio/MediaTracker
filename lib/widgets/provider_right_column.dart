import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage.dart';
import '../services/tmdb_api.dart';
import '../services/region.dart';
import '../services/settings_controller.dart';

/// Renders a vertical stack of provider logos for use on the right side of a card.
/// Uses the same data logic as ProviderCornerGrid (no US fallback, rent/buy fallback,
/// caching, retry, bottom sheet, deep links), but laid out in a single column.
class ProviderRightColumn extends StatefulWidget {
  const ProviderRightColumn({super.key, required this.showId, required this.mediaType, this.size = 28});
  final int showId;
  final MediaType mediaType;
  final double size;

  @override
  State<ProviderRightColumn> createState() => _ProviderRightColumnState();
}

class _ProviderRightColumnState extends State<ProviderRightColumn> {
  static const _imgBase = 'https://image.tmdb.org/t/p';
  final _api = TmdbApi();
  static final Map<String, ({
    List<Map<String, dynamic>> streaming,
    List<Map<String, dynamic>> rentBuy,
    String region,
  })> _cache = {};

  List<Map<String, dynamic>> _streaming = const [];
  List<Map<String, dynamic>> _allStreaming = const [];
  List<Map<String, dynamic>> _rentBuy = const [];
  bool _loading = true;
  bool _showEllipsis = false;
  bool _hasRentBuy = false;
  String? _regionUsed;
  bool _error = false;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = SettingsScope.of(context);
    final region = settings.effectiveRegion ?? detectRegionCode(fallback: 'US');
    if (_regionUsed != null && _regionUsed != region) {
      _load(forceRegion: region);
    }
  }

  @override
  void didUpdateWidget(covariant ProviderRightColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showId != widget.showId || oldWidget.mediaType != widget.mediaType) {
      setState(() {
        _loading = true;
        _streaming = const [];
        _allStreaming = const [];
        _rentBuy = const [];
        _showEllipsis = false;
        _hasRentBuy = false;
        _error = false;
        _attempts = 0;
      });
      _load();
    }
  }

  Future<void> _load({String? forceRegion}) async {
    try {
      final key = '${widget.mediaType.name}:${widget.showId}';
      if (_attempts == 0 && _cache.containsKey(key)) {
        final cached = _cache[key]!;
        _applyData(
          streaming: cached.streaming,
          rentBuy: cached.rentBuy,
          usedRegion: cached.region,
        );
      }
      final settings = SettingsScope.of(context);
      final region = (forceRegion ?? settings.effectiveRegion ?? detectRegionCode(fallback: 'US')).toUpperCase();
      final res = widget.mediaType == MediaType.movie
          ? await _api.fetchMovieWatchProviders(widget.showId, region: region)
          : await _api.fetchWatchProviders(widget.showId, region: region);
      final streaming = (res.streaming).cast<Map<String, dynamic>>();
      final rentBuy = (res.rentBuy).cast<Map<String, dynamic>>();
      if (!mounted) return;
      _applyData(streaming: streaming, rentBuy: rentBuy, usedRegion: region);
      _cache[key] = (streaming: _allStreaming, rentBuy: _rentBuy, region: _regionUsed ?? region);
    } catch (_) {
      if (!mounted) return;
      if (_attempts < 2) {
        _attempts += 1;
        Future<void>.delayed(const Duration(milliseconds: 650), () => _load(forceRegion: forceRegion));
      } else {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  void _applyData({
    required List<Map<String, dynamic>> streaming,
    required List<Map<String, dynamic>> rentBuy,
    required String usedRegion,
  }) {
    setState(() {
      _allStreaming = streaming;
      _rentBuy = rentBuy;
      _hasRentBuy = _rentBuy.isNotEmpty;
      final displayingStreaming = _allStreaming.isNotEmpty || !_hasRentBuy;
      final displayedList = displayingStreaming ? _allStreaming : _rentBuy;
      _streaming = displayedList.take(3).toList(growable: false);
      final otherExists = displayingStreaming ? _hasRentBuy : _allStreaming.isNotEmpty;
      _showEllipsis = displayedList.length > 3 || otherExists;
      _loading = false;
      _regionUsed = usedRegion;
      _error = false;
    });
  }

  // Bottom sheet and deep link helpers (copied from ProviderCornerGrid)
  static final Map<String, List<String>> _providerLaunchOrder = {
    'netflix': ['nflx://www.netflix.com', 'https://www.netflix.com'],
    'disney+': ['disneyplus://', 'https://www.disneyplus.com'],
    'disney plus': ['disneyplus://', 'https://www.disneyplus.com'],
    'max': ['hbomax://open', 'https://www.max.com'],
    'hbo max': ['hbomax://open', 'https://www.max.com'],
    'amazon prime video': ['primevideo://', 'https://www.primevideo.com'],
    'prime video': ['primevideo://', 'https://www.primevideo.com'],
    'apple tv+': ['tv://', 'https://tv.apple.com'],
    'apple tv': ['tv://', 'https://tv.apple.com'],
    'viaplay': ['viaplay://open', 'https://viaplay.com'],
    'youtube': ['vnd.youtube://', 'https://www.youtube.com'],
    'skyshowtime': ['skyshowtime://', 'https://www.skyshowtime.com'],
    'svt play': [
      'svtplay://open',
      'svtplay://',
      'https://www.svtplay.se',
      'https://svtplay.se',
    ],
    'svtplay': [
      'svtplay://open',
      'svtplay://',
      'https://www.svtplay.se',
      'https://svtplay.se',
    ],
    'tele2 play': ['tele2play://', 'https://www.tele2play.se'],
    'tv4 play': ['tv4play://', 'https://www.tv4play.se'],
    'tv4': ['tv4play://', 'https://www.tv4play.se'],
    'sf anytime': [
      'sfanytime://open',
      'sfanytime://',
      'https://www.sfanytime.com/se',
      'https://sfanytime.com/se',
      'https://www.sfanytime.com',
      'https://sfanytime.com',
    ],
    'hulu': ['hulu://', 'https://www.hulu.com'],
    'paramount+': ['paramountplus://', 'https://www.paramountplus.com'],
    'paramount plus': ['paramountplus://', 'https://www.paramountplus.com'],
    'peacock': ['peacock://', 'https://www.peacocktv.com'],
  };

  String _normalize(String s) => s.toLowerCase().trim();

  Future<void> _launchProviderByName(String? providerName) async {
    if (providerName == null || providerName.isEmpty) return;
    final key = _normalize(providerName);
    List<String>? candidates = _providerLaunchOrder[key];
    candidates ??= _providerLaunchOrder.entries
        .firstWhere((e) => key.contains(e.key), orElse: () => const MapEntry<String, List<String>>('', []))
        .value;
    if (candidates.isEmpty) return;
    final appLinks = <Uri>[];
    final webLinks = <Uri>[];
    for (final s in candidates) {
      final uri = Uri.tryParse(s);
      if (uri == null) continue;
      final scheme = uri.scheme.toLowerCase();
      if (scheme == 'http' || scheme == 'https') {
        webLinks.add(uri);
      } else {
        appLinks.add(uri);
      }
    }
    bool anyAppCandidate = false;
    for (final uri in appLinks) {
      try {
        if (await canLaunchUrl(uri)) {
          anyAppCandidate = true;
          final _ = await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
          return;
        }
      } catch (_) {}
    }
    if (!anyAppCandidate) {
      for (final uri in webLinks) {
        try {
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (ok) return;
        } catch (_) {}
      }
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
            onTap: () async {
              Navigator.pop(context);
              await _launchProviderByName(name);
            },
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
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(100)),
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
        decoration: BoxDecoration(color: const Color(0xCC2F2F35), borderRadius: BorderRadius.circular(s * 0.18)),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 60, width: 32);
    if (_error) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _loading = true;
            _error = false;
            _attempts = 0;
          });
          _load();
        },
        child: Container(
          width: widget.size + 6,
          height: widget.size + 6,
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: const Icon(Icons.refresh, size: 18, color: Colors.white54),
        ),
      );
    }

    final showEllipsis = _showEllipsis;
    if (_streaming.isEmpty && !showEllipsis) return const SizedBox.shrink();

    final size = widget.size;
    const gap = 4.0;
    final items = <Widget>[];
    for (final m in _streaming) {
      final logoPath = (m['logo_path'] as String?) ?? '';
      final name = (m['provider_name'] as String?) ?? '';
      Widget img = _placeholder(size);
      if (logoPath.isNotEmpty) {
        img = ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.18),
          child: Image.network('$_imgBase/w92$logoPath', width: size, height: size, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _placeholder(size)),
        );
      }
      items.add(GestureDetector(
        onTap: () => _launchProviderByName(name),
        child: Tooltip(message: name.isNotEmpty ? name : 'Open provider', child: img),
      ));
    }
    if (showEllipsis) {
      items.add(GestureDetector(
        onTap: _openProvidersSheet,
        child: Semantics(
          label: 'More providers',
          button: true,
          child: Tooltip(
            message: 'More providers (Region: ${_regionUsed ?? '—'})',
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: const Color(0xCC2F2F35), borderRadius: BorderRadius.circular(size * 0.18)),
              alignment: Alignment.center,
              child: Text('…', style: TextStyle(fontSize: size * 0.9, height: 1.0)),
            ),
          ),
        ),
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          items[i],
          if (i != items.length - 1) const SizedBox(height: gap),
        ],
      ],
    );
  }
}
