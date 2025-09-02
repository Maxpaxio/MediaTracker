import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/storage.dart';
import '../services/tmdb_api.dart';
import '../widgets/show_hero.dart';
import 'subpages/more_info_page.dart';

class ShowDetailArgs {
  final int showId;
  ShowDetailArgs({required this.showId});
}

class ShowDetailPage extends StatefulWidget {
  static const route = '/show';
  const ShowDetailPage({super.key});

  @override
  State<ShowDetailPage> createState() => _ShowDetailPageState();
}

class _ShowDetailPageState extends State<ShowDetailPage> {
  final TmdbApi _api = TmdbApi();

  int? _showId;
  bool _loading = true;

  Show? _show;

  List<Map<String, dynamic>> _streaming = const [];
  List<Map<String, dynamic>> _rentBuy = const [];
  bool _providersLoading = false;

  final Map<int, bool> _expanded = {}; // seasonNumber -> expanded
  final Map<int, List<String>> _episodeTitles = {}; // seasonNumber -> titles

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_showId != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ShowDetailArgs) {
      _showId = args.showId;
      _loadAll();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadAll() async {
    if (_showId == null) return;
    final id = _showId!;

    setState(() => _loading = true);

    final storage = StorageScope.of(context);

    // Peek existing to determine media type (movie vs tv)
    final cached = storage.tryGet(id);

    // Refresh full detail (en-US) using proper endpoint
    if (cached?.mediaType == MediaType.movie) {
      await _refreshMovieFromTmdb(storage, id);
    } else {
      // Default to TV if unknown
      await _refreshShowFromTmdb(storage, id);
    }

    // Reload from storage
    Show? s;
    try {
      s = storage.byId(id);
    } catch (_) {
      s = storage.tryGet(id);
    }

  // Providers: STRICT to SE (no fallback) and correct type
  final mt = (s?.mediaType) ?? cached?.mediaType ?? MediaType.tv;
  await _loadProviders(id, regionCode: 'SE', mediaType: mt);

    if (!mounted) return;
    setState(() {
      _show = s;
      _loading = false;
    });
  }

  Future<void> _refreshShowFromTmdb(AppStorage storage, int showId) async {
    try {
      final full = await _api.fetchShowDetailStorage(showId);

      final cached = storage.tryGet(showId);
      if (cached == null) {
        storage.ensureShow(full);
        return;
      }

      // Preserve watched counts per season
      final watchedBySeason = {
        for (final s in cached.seasons) s.seasonNumber: s.watched,
      };
      final mergedSeasons = [
        for (final s in full.seasons)
          s.copyWith(watched: watchedBySeason[s.seasonNumber] ?? 0),
      ];

      final merged = cached.copyWith(
        overview: cached.overview.isNotEmpty ? cached.overview : full.overview,
        posterUrl:
            cached.posterUrl.isNotEmpty ? cached.posterUrl : full.posterUrl,
        backdropUrl: cached.backdropUrl.isNotEmpty
            ? cached.backdropUrl
            : full.backdropUrl,
        firstAirDate: cached.firstAirDate.isNotEmpty
            ? cached.firstAirDate
            : full.firstAirDate,
        lastAirDate: cached.lastAirDate ?? full.lastAirDate,
        rating: cached.rating > 0 ? cached.rating : full.rating,
        genres: cached.genres.isNotEmpty ? cached.genres : full.genres,
        seasons: mergedSeasons,
      );

  // Preserve ordering: update in place
  storage.updateShow(merged);
    } catch (_) {
      // ignore network errors
    }
  }

  Future<void> _refreshMovieFromTmdb(AppStorage storage, int movieId) async {
    try {
      final full = await _api.fetchMovieDetailStorage(movieId);

      final cached = storage.tryGet(movieId);
      if (cached == null) {
        storage.ensureShow(full);
        return;
      }

      final merged = cached.copyWith(
        overview: cached.overview.isNotEmpty ? cached.overview : full.overview,
        posterUrl:
            cached.posterUrl.isNotEmpty ? cached.posterUrl : full.posterUrl,
        backdropUrl: cached.backdropUrl.isNotEmpty
            ? cached.backdropUrl
            : full.backdropUrl,
        firstAirDate: cached.firstAirDate.isNotEmpty
            ? cached.firstAirDate
            : full.firstAirDate,
        lastAirDate: full.lastAirDate, // movies: always null from API mapper
        rating: cached.rating > 0 ? cached.rating : full.rating,
        genres: cached.genres.isNotEmpty ? cached.genres : full.genres,
        seasons: const <Season>[], // movies: no seasons
        mediaType: MediaType.movie,
      );

      storage.updateShow(merged);
    } catch (_) {
      // ignore network errors
    }
  }

  Future<void> _loadProviders(int showId,
      {required String regionCode, required MediaType mediaType}) async {
    setState(() {
      _providersLoading = true;
      _streaming = const [];
      _rentBuy = const [];
    });

    try {
      final res = mediaType == MediaType.movie
          ? await _api.fetchMovieWatchProviders(showId, region: regionCode)
          : await _api.fetchWatchProviders(showId, region: regionCode);
      if (!mounted) return;
      setState(() {
        _streaming = res.streaming;
        _rentBuy = res.rentBuy;
        _providersLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _providersLoading = false);
    }
  }

  // --- Episode titles (lazy) ---
  Future<void> _ensureEpisodeTitles(int seasonNumber, int expectedCount) async {
    if (_showId == null) return;
    if (_episodeTitles.containsKey(seasonNumber)) return;

    final titles = await _api.fetchSeasonEpisodeTitles(_showId!, seasonNumber);
    if (!mounted) return;

    // Trim or pad to expectedCount so indexing is safe
    final fixed = List<String>.from(titles);
    if (fixed.length > expectedCount) {
      fixed.removeRange(expectedCount, fixed.length);
    } else if (fixed.length < expectedCount) {
      fixed.addAll(List.filled(expectedCount - fixed.length, ''));
    }

    setState(() {
      _episodeTitles[seasonNumber] = fixed;
    });
  }

  // --- Seasons helpers (tri-state) ---
  bool? _triStateFor(Season s) {
    if (s.episodeCount <= 0) return false;
    if (s.watched <= 0) return false;
    if (s.watched >= s.episodeCount) return true;
    return null; // partial
  }

  void _setSeasonWatched(Show show, Season season, bool watchedAll) {
    final storage = StorageScope.of(context);
    final target = watchedAll ? season.episodeCount : 0;

    storage.updateSeasonProgress(show.id, season.seasonNumber, target);

    // If we just added progress and the show was in Watchlist, remove Watchlist.
    final updated = storage.byId(show.id);
    final hasProgressNow = updated.watchedEpisodes > 0;
    if (hasProgressNow && updated.isWatchlist) {
      storage.toggleWatchlist(updated); // -> None
    }

    setState(() => _show = updated);
  }

  void _toggleEpisodeByCount(
      Show show, Season season, int episodeNumber, bool newChecked) {
    final storage = StorageScope.of(context);

    int target = newChecked ? episodeNumber : (episodeNumber - 1);
    if (target < 0) target = 0;
    if (target > season.episodeCount) target = season.episodeCount;

    storage.updateSeasonProgress(show.id, season.seasonNumber, target);

    // If any progress exists now, and the show was in Watchlist, remove Watchlist.
    final updated = storage.byId(show.id);
    final hasProgressNow = updated.watchedEpisodes > 0;
    if (hasProgressNow && updated.isWatchlist) {
      storage.toggleWatchlist(updated); // -> None
    }

    setState(() => _show = updated);
  }

  // Refresh current show after menu actions
  void _refreshFromStorage() {
    final storage = StorageScope.of(context);
    if (_showId == null) return;
    final s = storage.tryGet(_showId!);
    setState(() => _show = s);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_show == null) {
      return const Scaffold(body: Center(child: Text('Show not found')));
    }

    final show = _show!;
    return Scaffold(
      appBar: AppBar(
        title: Text(show.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        children: [
          // HERO
          ShowHero(
              show: show, height: 280, posterWidth: 150, horizontalPadding: 16),
          const SizedBox(height: 16),

          // OVERVIEW (clickable -> More Info)
          if (show.overview.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    MoreInfoPage.route,
                    arguments: show.id,
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show.overview,
                      maxLines: 4, // keep it trimmed in details
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'More Info >',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),

          // PROVIDERS (logos + Add-to menu pinned right)
          _ProvidersBlock(
            showId: show.id,
            onChanged: _refreshFromStorage,
            streaming: _streaming,
            rentBuy: _rentBuy,
            loading: _providersLoading,
          ),

          const Divider(),

          // SEASONS (TV only)
          if (show.mediaType == MediaType.tv)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final season in show.seasons)
                    _SeasonTile(
                      key:
                          ValueKey('season-${show.id}-${season.seasonNumber}'),
                      show: show,
                      season: season,
                      seasonTitle: season.name.isNotEmpty
                          ? season.name
                          : 'Season ${season.seasonNumber}',
                      initialExpanded: _expanded[season.seasonNumber] ?? false,
                      triStateValue: _triStateFor(season),
                      titles: _episodeTitles[season.seasonNumber],
                      onBulkChange: (v) =>
                          _setSeasonWatched(show, season, v == true),
                      onEpisodeToggle: (epNum, v) =>
                          _toggleEpisodeByCount(show, season, epNum, v),
                      onToggle: (isOpen) async {
                        _expanded[season.seasonNumber] = isOpen;
                        if (isOpen) {
                          await _ensureEpisodeTitles(
                              season.seasonNumber, season.episodeCount);
                        }
                        if (mounted) setState(() {});
                      },
                    ),
                ],
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
      // bottomNavigationBar removed – Add-to menu handles actions
    );
  }
}

class _ProvidersBlock extends StatelessWidget {
  const _ProvidersBlock({
    required this.showId,
    required this.onChanged,
    required this.streaming,
    required this.rentBuy,
    required this.loading,
  });

  final int showId;
  final VoidCallback onChanged;

  final List<Map<String, dynamic>> streaming;
  final List<Map<String, dynamic>> rentBuy;
  final bool loading;

  static const _img = 'https://image.tmdb.org/t/p';

  // Known provider deep links & web fallbacks (keys are lowercase)
  static final Map<String, List<String>> _providerLaunchOrder = {
    // Core
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

    // Regionals / extras
    'skyshowtime': ['skyshowtime://', 'https://www.skyshowtime.com'],

    // SVT Play (try schemes + universal links)
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

    // Tele2 Play
    'tele2 play': ['tele2play://', 'https://www.tele2play.se'],

    // TV4 Play
    'tv4 play': ['tv4play://', 'https://www.tv4play.se'],
    'tv4': ['tv4play://', 'https://www.tv4play.se'],

    // SF Anytime (prefer /se to avoid 504)
    'sf anytime': [
      'sfanytime://open',
      'sfanytime://',
      'https://www.sfanytime.com/se',
      'https://sfanytime.com/se',
      'https://www.sfanytime.com',
      'https://sfanytime.com',
    ],

    // Amazon Video (rent/buy store, not Prime)
    'amazon video': ['aiv://', 'https://www.amazon.com/videostore'],
    'amazon instant video': ['aiv://', 'https://www.amazon.com/videostore'],

    // BritBox
    'britbox': ['britbox://', 'https://www.britbox.com'],

    // Others
    'hulu': ['hulu://', 'https://www.hulu.com'],
    'paramount+': ['paramountplus://', 'https://www.paramountplus.com'],
    'paramount plus': ['paramountplus://', 'https://www.paramountplus.com'],
    'peacock': ['peacock://', 'https://www.peacocktv.com'],

    // Stores
    'google play movies': [
      'market://details?id=com.google.android.videos',
      'https://play.google.com/store/movies'
    ],
    'google play': [
      'market://details?id=com.google.android.videos',
      'https://play.google.com/store/movies'
    ],
    'apple itunes': [
      'itms://itunes.apple.com',
      'https://www.apple.com/itunes/'
    ],
    'itunes': ['itms://itunes.apple.com', 'https://www.apple.com/itunes/'],
  };

  String _normalize(String s) => s.toLowerCase().trim();

  Future<void> _launchProviderByName(String? providerName) async {
    if (providerName == null || providerName.isEmpty) return;

    final key = _normalize(providerName);

    // Exact or fuzzy (contains) lookup
    List<String>? candidates = _providerLaunchOrder[key];
    candidates ??= _providerLaunchOrder.entries
        .firstWhere(
          (e) => key.contains(e.key),
          orElse: () => const MapEntry<String, List<String>>('', []),
        )
        .value;

    if (candidates.isEmpty) return;

    // Try all app schemes first, then all web links
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

    // 1) Attempt app deep links (any one that can launch)
    for (final uri in appLinks) {
      try {
        if (await canLaunchUrl(uri)) {
          final ok = await launchUrl(
            uri,
            mode: LaunchMode.externalNonBrowserApplication,
          );
          if (ok) return;
        }
      } catch (_) {
        // try next
      }
    }

    // 2) Fallback to web (first one that launches)
    for (final uri in webLinks) {
      try {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      } catch (_) {
        // try next
      }
    }
  }

  // ✅ This is the helper your logo tile calls
  Widget _placeholder() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.grey.shade700,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _logoTile(BuildContext context, Map<String, dynamic> m) {
    final logoPath = (m['logo_path'] as String?) ?? '';
    final name = (m['provider_name'] as String?) ?? '';

    final img = logoPath.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              '$_img/w92$logoPath',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _placeholder(),
            ),
          )
        : _placeholder();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _launchProviderByName(name),
          child: Tooltip(
            message: name,
            child: ConstrainedBox(
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              child: Center(child: img),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final hasAny = streaming.isNotEmpty || rentBuy.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasAny) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text('Currently not available in your region'),
                ),
                _AddMenu(showId: showId, onChanged: onChanged),
              ],
            ),
          ] else ...[
            if (streaming.isNotEmpty) ...[
              const Text('Streaming'),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          streaming.map((m) => _logoTile(context, m)).toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (rentBuy.isEmpty)
                    _AddMenu(showId: showId, onChanged: onChanged),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (rentBuy.isNotEmpty) ...[
              const Text('Rent / Buy'),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          rentBuy.map((m) => _logoTile(context, m)).toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _AddMenu(showId: showId, onChanged: onChanged),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Logo-style “Add to…” menu button that **reflects current state**:
/// - Watchlist → yellow pill, bookmark icon, “Watchlist”
/// - Completed → green pill, check icon, “Completed”
/// - Ongoing (progress > 0, not watchlist/completed) → primary color, play icon, “Ongoing”
/// - None → outlined, plus icon, “Add to…”
class _AddMenu extends StatelessWidget {
  const _AddMenu({required this.showId, required this.onChanged});

  final int showId;
  final VoidCallback onChanged;

  // State colors
  static const _green = Color(0xFF22C55E); // completed
  static const _yellow = Color(0xFFFACC15); // watchlist

  @override
  Widget build(BuildContext context) {
    final storage = StorageScope.of(context);
    final s = storage.tryGet(showId);

    final bool isCompleted = s?.isCompleted ?? false;
    final bool inWatchlist = s?.isWatchlist ?? false;
    final bool isOngoing =
        (s != null) && !inWatchlist && !isCompleted && s.watchedEpisodes > 0;

    // Visuals based on state
    Color? bg;
    Color fg;
    IconData icon;
    String label;

    if (isCompleted) {
      bg = _green;
      fg = Colors.black;
      icon = Icons.check_circle;
      label = 'Completed';
    } else if (inWatchlist) {
      bg = _yellow;
      fg = Colors.black;
      icon = Icons.bookmark;
      label = 'Watchlist';
    } else if (isOngoing) {
      final scheme = Theme.of(context).colorScheme;
      bg = scheme.primary;
      fg = scheme.onPrimary;
      icon = Icons.play_circle_fill;
      label = 'Ongoing';
    } else {
      bg = null; // outlined
      fg = Theme.of(context).colorScheme.onSurface;
      icon = Icons.add;
      label = 'Add to…';
    }

    return PopupMenuButton<_AddAction>(
      offset: const Offset(0, 56),
      tooltip: 'Add to…',
      onSelected: (action) {
        final cur = storage.tryGet(showId);
        if (cur == null) return;

        switch (action) {
          case _AddAction.addWatchlist:
            if (!inWatchlist) {
              // Move to Watchlist and clear any Completed status/progress rules handled in storage layer
              storage.toggleWatchlist(cur); // none ↔ watchlist
            }
            break;

          case _AddAction.removeWatchlist:
            if (inWatchlist) {
              storage.toggleWatchlist(cur); // watchlist → none
            }
            break;

          case _AddAction.markCompleted:
            if (!isCompleted) {
              storage
                  .markCompleted(cur); // sets flag completed + fills progress
            }
            break;

          case _AddAction.removeCompleted:
            if (isCompleted) {
              // Reset completely: clear flag & progress, keep detail visible
              final reset = cur.copyWith(
                flag: WatchFlag.none,
                seasons: [
                  for (final ss in cur.seasons) ss.copyWith(watched: 0)
                ],
              );
              // Preserve list position: update in place instead of remove+re-add
              storage.updateShow(reset);
            }
            break;
        }
        onChanged();
      },
      itemBuilder: (context) => <PopupMenuEntry<_AddAction>>[
        if (!inWatchlist)
          const PopupMenuItem(
            value: _AddAction.addWatchlist,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.bookmark_add_outlined),
              title: Text('Add to Watchlist'),
            ),
          )
        else
          const PopupMenuItem(
            value: _AddAction.removeWatchlist,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.bookmark_remove_outlined),
              title: Text('Remove from Watchlist'),
            ),
          ),
        const PopupMenuDivider(),
        if (!isCompleted)
          const PopupMenuItem(
            value: _AddAction.markCompleted,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.check_circle_outline),
              title: Text('Mark Completed'),
            ),
          )
        else
          const PopupMenuItem(
            value: _AddAction.removeCompleted,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.remove_circle_outline),
              title: Text('Remove from Completed'),
            ),
          ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bg,
              border: bg == null ? Border.all(color: Colors.white24) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 26, color: fg),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

enum _AddAction {
  addWatchlist,
  removeWatchlist,
  markCompleted,
  removeCompleted,
}

class _SeasonTile extends StatelessWidget {
  const _SeasonTile({
    super.key,
    required this.show,
    required this.season,
    required this.seasonTitle,
    required this.initialExpanded,
    required this.triStateValue,
    required this.titles,
    required this.onBulkChange,
    required this.onEpisodeToggle,
    required this.onToggle,
  });

  final Show show;
  final Season season;
  final String seasonTitle;
  final bool initialExpanded;
  final bool? triStateValue;
  final List<String>? titles;
  final ValueChanged<bool?> onBulkChange;
  final void Function(int episodeNumber, bool newValue) onEpisodeToggle;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey('expansion-${show.id}-${season.seasonNumber}'),
        title: Text(seasonTitle),
        subtitle: Text('Episodes: ${season.episodeCount}'),
        trailing: SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            tristate: true,
            value: triStateValue,
            onChanged: onBulkChange,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        initiallyExpanded: initialExpanded,
        onExpansionChanged: onToggle,
        children: [
          if (season.episodeCount == 0)
            const ListTile(title: Text('No episodes listed for this season.'))
          else
            ...List.generate(season.episodeCount, (idx) {
              final epNum = idx + 1;
              final isChecked = epNum <= season.watched;
              final title = (titles != null &&
                      idx < titles!.length &&
                      titles![idx].trim().isNotEmpty)
                  ? titles![idx].trim()
                  : '';
              final line = title.isNotEmpty ? 'Ep $epNum: $title' : 'Ep $epNum';
              return CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: isChecked,
                title: Text(line),
                onChanged: (v) => onEpisodeToggle(epNum, v ?? false),
              );
            }),
        ],
      ),
    );
  }
}
