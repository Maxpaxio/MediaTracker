import 'package:flutter/material.dart';
import '../services/storage.dart';
import '../services/tmdb_api.dart';
import '../services/settings_controller.dart';
import '../services/region.dart';

/// A compact, scrollable row of provider chips computed from the given list of shows.
/// - Shows only providers that exist in the current `items`.
/// - Multi-select; tapping a selected chip toggles it off.
/// - When no providers are selected, the filter is considered "off" and `onChanged` is called with empty set.
class ProviderFilterBar extends StatefulWidget {
  const ProviderFilterBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  final List<Show> items;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<ProviderFilterBar> createState() => _ProviderFilterBarState();
}

class _ProviderFilterBarState extends State<ProviderFilterBar> {
  static final TmdbApi _api = TmdbApi();
  static final Map<String, Set<String>> _cache = {};
  bool _loading = false;
  bool _didInitialEnsure = false;
  String? _lastItemsSig;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ProviderFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sig = _sigForItems(widget.items);
    if (_lastItemsSig != sig) {
      _lastItemsSig = sig;
      _ensureProviders();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitialEnsure) {
      _didInitialEnsure = true;
      _lastItemsSig = _sigForItems(widget.items);
      _ensureProviders();
    }
  }

  String _sigForItems(List<Show> items) {
    final ids = items.map((s) => s.id).toList()..sort();
    return ids.join(',');
  }

  String _keyFor(Show s) => '${s.mediaType.name}:${s.id}';

  String _effectiveRegion(BuildContext context) {
    try {
      final settings = SettingsScope.of(context);
      return settings.effectiveRegion ?? detectRegionCode(fallback: 'US');
    } catch (_) {
      // If SettingsScope is not available yet, fall back to detection.
      return detectRegionCode(fallback: 'US');
    }
  }

  AppStorage? _tryStorage(BuildContext context) {
    try {
      return StorageScope.of(context);
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureProviders() async {
    // If options already exist from items and cache, bail early to avoid work
    final needsFetch = widget.items.any((s) => s.providers.isEmpty && !_cache.containsKey(_keyFor(s)));
    if (!needsFetch) return;

    setState(() => _loading = true);

  final region = _effectiveRegion(context);
  final storage = _tryStorage(context);

    // Fetch a limited subset to reduce cost; stop early when we have enough unique providers to populate chips
    final pending = <Show>[];
    for (final s in widget.items) {
      final key = _keyFor(s);
      if (s.providers.isEmpty && !_cache.containsKey(key)) pending.add(s);
    }

    // If nothing to fetch, finish
    if (pending.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // Limit to up to 12 fetches per page enter to avoid jank
    final toFetch = pending.take(12).toList(growable: false);

    final discovered = <String>{};
    final bulk = <int, List<String>>{};
    for (final s in toFetch) {
      if (!mounted) break;
      final key = _keyFor(s);
      if (s.providers.isNotEmpty || _cache.containsKey(key)) continue;
      try {
        final res = s.mediaType == MediaType.movie
            ? await _api.fetchMovieWatchProviders(s.id, region: region)
            : await _api.fetchWatchProviders(s.id, region: region);
        final streaming = (res.streaming).cast<Map<String, dynamic>>();
        final names = <String>{
          for (final m in streaming)
            if ((m['provider_name'] as String?)?.isNotEmpty == true)
              (m['provider_name'] as String)
        };
        if (names.isNotEmpty) {
          _cache[key] = names;
          discovered.addAll(names);
          bulk[s.id] = names.toList();
          // If we have enough options (>= 8), we can stop early for UI responsiveness
          if (discovered.length >= 8) break;
        }
      } catch (_) {
        // Ignore failures silently; chips will be based on whatever we have.
      }
    }

    // Apply a single bulk storage update to avoid multiple rebuilds
    if (storage != null && bulk.isNotEmpty) {
      storage.updateProvidersBulkSilent(bulk);
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Compute unique providers from current items, including any cached values
    final uniq = <String>{};
    for (final s in widget.items) {
      if (s.providers.isNotEmpty) {
        uniq.addAll(s.providers);
      } else {
        final cached = _cache[_keyFor(s)];
        if (cached != null) uniq.addAll(cached);
      }
    }
    final options = uniq.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    // Always render the bar shell; if no options yet, show only All + optional spinner
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      child: SizedBox(
        height: 48,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: FilterChip(
                label: const Text('All'),
                selected: widget.selected.isEmpty,
                onSelected: (_) => widget.onChanged(<String>{}),
              ),
            ),
            if (_loading && options.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
              ),
            for (final p in options)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: FilterChip(
                  label: Text(p),
                  selected: widget.selected.contains(p),
                  onSelected: (on) {
                    final next = <String>{...widget.selected};
                    if (on) {
                      next.add(p);
                    } else {
                      next.remove(p);
                    }
                    widget.onChanged(next);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
