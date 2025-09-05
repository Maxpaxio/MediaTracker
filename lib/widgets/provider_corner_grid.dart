import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // --- Deep link helpers: open app homepage when possible ---
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
        .firstWhere(
          (e) => key.contains(e.key),
          orElse: () => const MapEntry<String, List<String>>('', []),
        )
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
          final _ = await launchUrl(
            uri,
            mode: LaunchMode.externalNonBrowserApplication,
          );
          return; // do not fall back to web to avoid double-open
        }
      } catch (_) {
        // continue
      }
    }
    if (!anyAppCandidate) {
      for (final uri in webLinks) {
        try {
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (ok) return;
        } catch (_) {
          // continue
        }
      }
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
      final name = (m['provider_name'] as String?) ?? '';
      Widget img = _placeholder(size);
      if (logoPath.isNotEmpty) {
        img = ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.18),
          child: Image.network(
            '$_imgBase/w92$logoPath',
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _placeholder(size),
          ),
        );
      }
      return GestureDetector(
        onTap: () => _launchProviderByName(name),
        child: Tooltip(message: name.isNotEmpty ? name : 'Open provider', child: img),
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
