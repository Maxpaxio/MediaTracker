import 'package:flutter/material.dart';
import '../widgets/add_menu.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/storage.dart';
import '../services/tmdb_api.dart';
import '../services/region.dart';
import '../services/settings_controller.dart';
import '../widgets/show_hero.dart';
import 'subpages/more_info_page.dart';
import '../widgets/region_picker_button.dart';
import '../widgets/sync_actions.dart';

class ShowDetailArgs {
  final int showId;
  // Optional hint to force the media type (tv/movie) when loading details.
  // This helps avoid ambiguities on platforms where route arguments/state can be flaky (e.g., PWA).
  final MediaType? forcedType;
  ShowDetailArgs({required this.showId, this.forcedType});
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

  MediaType? _forcedType; // from navigation args or parsed route

  Show? _show;

  List<Map<String, dynamic>> _streaming = const [];
  List<Map<String, dynamic>> _rentBuy = const [];
  bool _providersLoading = false;
  String? _lastRegion;
  String? _overrideRegion; // temporary page-level region
  List<String> _availableRegions = const [];
  Map<String, int> _regionCounts = const {};
  // Provider -> list of available seasons (streaming only) for the current region
  Map<int, Set<int>> _providerSeasonCoverage = const {};

  // Quick metadata for right-of-poster (movies): runtime in minutes.
  int? _movieRuntimeMinutes; // null when unknown/not loaded

  final Map<int, bool> _expanded = {}; // seasonNumber -> expanded
  final Map<int, List<String>> _episodeTitles = {}; // seasonNumber -> titles
  final Map<int, List<String>> _episodeAirDates = {}; // seasonNumber -> air dates
  final Map<int, Map<int, String>> _episodeOverviews = {}; // season -> (ep -> overview)
  final Map<int, Map<int, double>> _episodeRatings = {}; // season -> (ep -> rating)
  final Map<int, Map<int, List<String>>> _episodeDirectors = {}; // season -> (ep -> names)
  // Track single open season and single open episode per season (collapse others when new opens)
  int? _openSeason; // seasonNumber
  final Map<int, int?> _openEpisodePerSeason = {}; // seasonNumber -> episodeNumber
  // When multi-open for episodes is enabled, track a set of open episodes per season
  final Map<int, Set<int>> _openEpisodesMulti = {};

  void setOpenSeason(int? seasonNumber) {
    setState(() {
      _openSeason = seasonNumber;
      if (seasonNumber != null) {
        // collapse others in _expanded
        _expanded.clear();
        _expanded[seasonNumber] = true;
      } else {
        _expanded.clear();
      }
    });
  }

  void setOpenEpisode(int seasonNumber, int? episodeNumber) {
    setState(() {
      _openEpisodePerSeason[seasonNumber] = episodeNumber;
    });
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_showId != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ShowDetailArgs) {
      _showId = args.showId;
      _forcedType = args.forcedType;
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
    final isMovie = (_forcedType ?? cached?.mediaType) == MediaType.movie;

    // Refresh full detail (en-US) using proper endpoint
    if (isMovie) {
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
  final mt = _forcedType ?? (s?.mediaType) ?? cached?.mediaType ?? MediaType.tv;
    final settingsCtrl = SettingsScope.of(context);
    final region =
        settingsCtrl.effectiveRegion ?? detectRegionCode(fallback: 'US');
    _lastRegion = region;
    await _loadProviders(id, regionCode: region, mediaType: mt);
    // After base providers load, resolve season coverage (TV only)
    if (!mounted) return;
    if (mt == MediaType.tv) {
      await _loadProviderSeasonCoverage(id, region, s);
    } else {
      _providerSeasonCoverage = const {};
    }

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

      // Additionally, fetch extras for runtime (movies only) for right-side badges.
      try {
        final extras = await _api.fetchMovieExtras(movieId);
        if (mounted) {
          setState(() {
            _movieRuntimeMinutes = extras.runtime > 0 ? extras.runtime : null;
          });
        }
      } catch (_) {
        // ignore extras failure
      }
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

  Future<void> _loadProviderSeasonCoverage(int showId, String region, Show? s) async {
    final show = s ?? _show;
    if (show == null || show.mediaType != MediaType.tv) return;
    // Only consider real seasons (>=1)
    final seasons = show.seasons.map((e) => e.seasonNumber).where((n) => n >= 1).toList();
    if (seasons.isEmpty) {
      setState(() => _providerSeasonCoverage = const {});
      return;
    }
    final api = _api;
    final byProvider = <int, Set<int>>{};
    for (final sn in seasons) {
      Set<int> providersForSeason = await api.fetchSeasonStreamingProviders(showId, sn, region);
      for (final pid in providersForSeason) {
        byProvider.putIfAbsent(pid, () => <int>{});
        byProvider[pid]!.add(sn);
      }
    }
    if (!mounted) return;
    setState(() => _providerSeasonCoverage = byProvider);
  }

  Future<void> _ensureAvailableRegions(int showId, MediaType mt) async {
    // Always ensure current base region appears (top) even if it has 0 streaming providers.
    final settingsCtrl = SettingsScope.of(context);
    final baseRegion =
        (settingsCtrl.effectiveRegion ?? detectRegionCode(fallback: 'US'))
            .toUpperCase();

    // If we've already loaded once, just enforce baseRegion presence/order and exit.
    if (_availableRegions.isNotEmpty) {
      final hasBase = _availableRegions.contains(baseRegion);
      if (!hasBase) {
        setState(() {
          _availableRegions = [baseRegion, ..._availableRegions];
          _regionCounts = {..._regionCounts, baseRegion: _regionCounts[baseRegion] ?? 0};
        });
      } else if (_availableRegions.first != baseRegion) {
        setState(() {
          _availableRegions = [
            baseRegion,
            ..._availableRegions.where((c) => c != baseRegion),
          ];
        });
      }
      return;
    }

    try {
      final entries = await _api.fetchStreamingRegionCounts(showId,
          isMovie: mt == MediaType.movie);
      if (!mounted) return;
      final mapCounts = {for (final e in entries) e.code: e.count};

      // If base region not in streaming list, synthesize an entry with count 0.
      final hasBase = entries.any((e) => e.code == baseRegion);
      final mutable = List.of(entries);
      if (!hasBase) {
        mutable.add((code: baseRegion, count: 0));
        mapCounts[baseRegion] = 0;
      }

      // Sort (excluding the forced base at top): base first, then by count desc, then code asc.
      mutable.sort((a, b) {
        // Base region pinned: treat it as highest priority (appear first after reinsert).
        if (a.code == baseRegion && b.code != baseRegion) return -1;
        if (b.code == baseRegion && a.code != baseRegion) return 1;
        final cmp = b.count.compareTo(a.count);
        if (cmp != 0) return cmp;
        return a.code.compareTo(b.code);
      });

      // Ensure base region is position 0 (in case count logic moved it already, still fine).
      if (mutable.first.code != baseRegion) {
        final baseEntry = mutable.firstWhere((e) => e.code == baseRegion);
        mutable.removeWhere((e) => e.code == baseRegion);
        mutable.insert(0, baseEntry);
      }

      setState(() {
        _availableRegions = mutable.map((e) => e.code).toList();
        _regionCounts = mapCounts;
      });
    } catch (_) {
      // On error, still at least expose base region so user can see current selection.
      if (mounted && _availableRegions.isEmpty) {
        setState(() {
          _availableRegions = [baseRegion];
          _regionCounts = {baseRegion: 0};
        });
      }
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

  Future<void> _ensureEpisodeAirDates(int seasonNumber, int expectedCount) async {
    if (_showId == null) return;
    if (_episodeAirDates.containsKey(seasonNumber)) return;

    final dates = await _api.fetchSeasonEpisodeAirDates(_showId!, seasonNumber);
    if (!mounted) return;

    final fixed = List<String>.from(dates);
    if (fixed.length > expectedCount) {
      fixed.removeRange(expectedCount, fixed.length);
    } else if (fixed.length < expectedCount) {
      fixed.addAll(List.filled(expectedCount - fixed.length, ''));
    }

    setState(() {
      _episodeAirDates[seasonNumber] = fixed;
    });
  }

  Future<void> _ensureEpisodeMeta(int seasonNumber, int episodeNumber) async {
    // Fetch and cache overview, rating, and directors for a specific episode.
    final id = _showId;
    if (id == null) return;
    final api = _api;
    final details = await api.fetchEpisodeDetails(id, seasonNumber, episodeNumber);
    final directors = await api.fetchEpisodeDirectors(id, seasonNumber, episodeNumber);
    if (!mounted) return;
    _episodeOverviews.putIfAbsent(seasonNumber, () => {});
    _episodeRatings.putIfAbsent(seasonNumber, () => {});
    _episodeDirectors.putIfAbsent(seasonNumber, () => {});
    _episodeOverviews[seasonNumber]![episodeNumber] = details.overview;
    _episodeRatings[seasonNumber]![episodeNumber] = details.rating;
    _episodeDirectors[seasonNumber]![episodeNumber] = directors;
    setState(() {});
  }

  // --- Seasons helpers (tri-state) ---
  bool? _triStateFor(Season s) {
    if (s.episodeCount <= 0) return false;
    if (s.watched <= 0) return false;
    if (s.watched >= s.episodeCount) return true;
    return null; // partial
  }

  Future<void> _setSeasonWatched(Show show, Season season, bool watchedAll) async {
    final storage = StorageScope.of(context);
    int target = 0;
    if (watchedAll) {
      // Only allow up to aired episodes
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      List<String> dates = _episodeAirDates[season.seasonNumber] ?? const [];
      if (dates.isEmpty) {
        // fetch if missing
        await _ensureEpisodeAirDates(season.seasonNumber, season.episodeCount);
        dates = _episodeAirDates[season.seasonNumber] ?? const [];
      }
      int aired = 0;
      for (final d in dates) {
        if (d.isEmpty) { aired++; continue; }
        final dt = DateTime.tryParse(d);
        if (dt == null) { aired++; continue; }
        final day = DateTime(dt.year, dt.month, dt.day);
        if (!day.isAfter(today)) aired++;
      }
      if (aired <= 0) {
        // fall back to season air date if provided
        if (season.airDate.isNotEmpty) {
          final sd = DateTime.tryParse(season.airDate);
          if (sd != null && !DateTime(sd.year, sd.month, sd.day).isAfter(today)) {
            aired = season.episodeCount; // assume all available when season date reached
          }
        }
      }
      target = aired.clamp(0, season.episodeCount);
    } else {
      target = 0;
    }

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
    final settingsCtrl = SettingsScope.of(context);
    final baseRegion =
        settingsCtrl.effectiveRegion ?? detectRegionCode(fallback: 'US');
    final effectiveRegion = _overrideRegion ?? baseRegion;
  final singleOpen = SettingsScope.of(context).singleOpenSeasons;
    if (_lastRegion != null &&
        _lastRegion != effectiveRegion &&
        !_providersLoading) {
      _lastRegion = effectiveRegion;
      // Refresh providers and season coverage when effective region changes
      _loadProviders(show.id,
          regionCode: effectiveRegion, mediaType: show.mediaType);
      if (show.mediaType == MediaType.tv) {
        _loadProviderSeasonCoverage(show.id, effectiveRegion, show);
      } else {
        setState(() => _providerSeasonCoverage = const {});
      }
    }
    _ensureAvailableRegions(show.id, show.mediaType); // fire & forget
    return Scaffold(
      appBar: AppBar(
        title: Text(
          show.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [SyncActions()],
      ),
      body: ListView(
        children: [
          // HERO
          ShowHero(
            show: show,
            height: 280,
            posterWidth: 150,
            horizontalPadding: 16,
            bottomOverlay: _BottomMetaPanel(
              child: _HeroMetaColumn(
                mediaType: show.mediaType,
                rating: show.rating,
                date: show.firstAirDate,
                runtimeMinutes: show.mediaType == MediaType.movie ? _movieRuntimeMinutes : null,
              ),
            ),
          ),
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

          // PROVIDERS + Region picker
          // Region picker row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _availableRegions.isNotEmpty
                  ? RegionPickerButton(
                      current: effectiveRegion,
                      candidates: _availableRegions,
                      counts: _regionCounts,
                      onSelected: (code) async {
                        setState(() {
                          _overrideRegion = code;
                          _lastRegion = code;
                        });
                        await _loadProviders(
                          show.id,
                          regionCode: code,
                          mediaType: show.mediaType,
                        );
                        if (show.mediaType == MediaType.tv) {
                          await _loadProviderSeasonCoverage(show.id, code, show);
                        } else {
                          if (mounted) {
                            setState(() => _providerSeasonCoverage = const {});
                          }
                        }
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          // Providers block below picker
          _ProvidersBlock(
            showId: show.id,
            onChanged: _refreshFromStorage,
            streaming: _streaming,
            rentBuy: _rentBuy,
            loading: _providersLoading,
            seasonCoverage: _providerSeasonCoverage,
            totalSeasons: show.seasons.length,
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
                      key: ValueKey('season-${show.id}-${season.seasonNumber}-open-${singleOpen ? (_openSeason == season.seasonNumber) : (_expanded[season.seasonNumber] ?? false)}'),
                      show: show,
                      season: season,
                      seasonTitle: season.name.isNotEmpty
                          ? season.name
                          : 'Season ${season.seasonNumber}',
                      seasonAirDate: season.airDate,
                      initialExpanded: singleOpen
                          ? _openSeason == season.seasonNumber
                          : (_expanded[season.seasonNumber] ?? false),
                      triStateValue: _triStateFor(season),
                      titles: _episodeTitles[season.seasonNumber],
                      airDates: _episodeAirDates[season.seasonNumber],
                      onBulkChange: (v) =>
                          _setSeasonWatched(show, season, v == true),
                      onEpisodeToggle: (epNum, v) =>
                          _toggleEpisodeByCount(show, season, epNum, v),
                      onToggle: (isOpen) async {
                        if (isOpen) {
                          await _ensureEpisodeTitles(
                              season.seasonNumber, season.episodeCount);
                          await _ensureEpisodeAirDates(
                              season.seasonNumber, season.episodeCount);
                        }
                        if (mounted) {
                          setState(() {
                            if (singleOpen) {
                              _openSeason = isOpen ? season.seasonNumber : null;
                            } else {
                              _expanded[season.seasonNumber] = isOpen;
                            }
                          });
                        }
                      },
                    ),
                  const SizedBox(height: 8),
                  _AbandonRow(show: show),
                ],
              ),
            ),

          if (show.mediaType == MediaType.movie)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _AbandonRow(show: show),
            ),

          const SizedBox(height: 24),
        ],
      ),
      // bottomNavigationBar removed – Add-to menu handles actions
    );
  }
}

class _HeroMetaColumn extends StatelessWidget {
  const _HeroMetaColumn({
    required this.mediaType,
    required this.rating,
    required this.date,
    this.runtimeMinutes,
  });

  final MediaType mediaType;
  final double rating; // 0..10
  final String? date; // YYYY-MM-DD or null/empty
  final int? runtimeMinutes; // movies only

  String _yearOf(String? d) {
    if (d == null || d.isEmpty) return '';
    if (d.length >= 4) return d.substring(0, 4);
    return '';
  }

  String _formatRuntime(int minutes) {
    if (minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}min';
    if (h > 0) return '${h}h 0min';
    return '${m}min';
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> lines = [];

    // Line 1: Star + rating (one decimal), if rating > 0
    if (rating > 0) {
      lines.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rate_rounded, color: Color(0xFFFFC107), size: 20),
          const SizedBox(width: 6),
          Text(
            rating.toStringAsFixed(1),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ));
    }

    // Line 2: Year for both TV and movies (from firstAirDate)
    final year = _yearOf(date);
    if (year.isNotEmpty) {
      lines.add(Text(year, style: Theme.of(context).textTheme.bodyMedium));
    }

    // Line 3 (movies only): runtime formatted as "2h 24min"
    if (mediaType == MediaType.movie && (runtimeMinutes ?? 0) > 0) {
      final rt = _formatRuntime(runtimeMinutes!);
      if (rt.isNotEmpty) {
        lines.add(Text(rt, style: Theme.of(context).textTheme.bodyMedium));
      }
    }

    if (lines.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          lines[i],
        ],
      ],
    );
  }
}

class _BottomMetaPanel extends StatelessWidget {
  const _BottomMetaPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Rectangular translucent panel (no rounded corners, no side feather).
    final bg = Colors.black.withValues(alpha: 0.35);
    return Align(
      alignment: Alignment.bottomLeft,
      child: IntrinsicWidth(
        child: IntrinsicHeight(
          child: DecoratedBox(
            decoration: BoxDecoration(color: bg),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _AbandonRow extends StatelessWidget {
  const _AbandonRow({required this.show});
  final Show show;

  @override
  Widget build(BuildContext context) {
    final storage = StorageScope.of(context);
    final isAbandoned = storage.tryGet(show.id)?.isAbandoned ?? false;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: isAbandoned ? Colors.grey.shade800 : const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              side: BorderSide(color: isAbandoned ? Colors.white24 : const Color(0xFFDC2626)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: Icon(isAbandoned ? Icons.restore : Icons.delete),
            label: Text(isAbandoned ? 'Remove Abandoned' : 'Abandon'),
            onPressed: () {
              final cur = storage.tryGet(show.id);
              if (cur == null) return;
              if (!isAbandoned) {
                storage.markAbandoned(cur);
              } else {
                storage.removeFromAbandoned(cur.id);
              }
            },
          ),
        ),
      ],
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
  this.seasonCoverage = const {},
  this.totalSeasons = 0,
  });

  final int showId;
  final VoidCallback onChanged;

  final List<Map<String, dynamic>> streaming;
  final List<Map<String, dynamic>> rentBuy;
  final bool loading;
  final Map<int, Set<int>> seasonCoverage; // provider_id -> set of seasonNumbers
  final int totalSeasons;

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

    // 1) Attempt app deep links
    bool anyAppCandidate = false;
    for (final uri in appLinks) {
      try {
        if (await canLaunchUrl(uri)) {
          anyAppCandidate = true;
          // Even if launchUrl reports false on some platforms, the OS may still
          // hand off to the app. To prevent double-open, do not fall back to web
          // when at least one app candidate exists.
          final _ = await launchUrl(
            uri,
            mode: LaunchMode.externalNonBrowserApplication,
          );
          return; // stop here regardless of result to avoid also opening web
        }
      } catch (_) {
        // try next app candidate
      }
    }

    // 2) Fallback to web only if there were no app-scheme candidates
    if (!anyAppCandidate) {
      for (final uri in webLinks) {
        try {
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (ok) return;
        } catch (_) {
          // try next
        }
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
    final pid = (m['provider_id'] as int?) ?? 0;
    final covered = seasonCoverage[pid] ?? const <int>{};
    final hasCoverage = totalSeasons > 0 && covered.isNotEmpty;
    String label() {
      if (!hasCoverage) return '';
      // Compact: if coverage equals total show seasons, show "All"; else show sorted list
      if (covered.length >= totalSeasons) return 'All';
      final sorted = covered.toList()..sort();
      // Collapse long lists: e.g., 1,2,5 or 1-4,6 depending on gaps
      return _compactSeasons(sorted);
    }

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

    final badge = hasCoverage
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white24, width: 0.5),
            ),
            child: Text(
              label(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          )
        : const SizedBox.shrink();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _launchProviderByName(name),
          child: Tooltip(
            message: name,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                  child: Center(child: img),
                ),
                if (hasCoverage) ...[
                  const SizedBox(height: 4),
                  badge,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Turn [1,2,5] into "1,2,5", and sequences like [1,2,3,5] into "1-3,5".
  String _compactSeasons(List<int> sorted) {
    if (sorted.isEmpty) return '';
    final ranges = <String>[];
    int start = sorted.first;
    int prev = start;
    for (int i = 1; i < sorted.length; i++) {
      final cur = sorted[i];
      if (cur == prev + 1) {
        prev = cur;
        continue;
      }
      ranges.add(start == prev ? '$start' : '$start-$prev');
      start = prev = cur;
    }
    ranges.add(start == prev ? '$start' : '$start-$prev');
    return ranges.join(',');
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
                AddMenu(showId: showId, onChanged: onChanged),
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
                    AddMenu(showId: showId, onChanged: onChanged),
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
                  AddMenu(showId: showId, onChanged: onChanged),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
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
    this.seasonAirDate,
    this.airDates,
  });

  final Show show;
  final Season season;
  final String seasonTitle;
  final String? seasonAirDate;
  final bool initialExpanded;
  final bool? triStateValue;
  final List<String>? titles;
  final List<String>? airDates;
  final ValueChanged<bool?> onBulkChange;
  final void Function(int episodeNumber, bool newValue) onEpisodeToggle;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
  return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
  key: ValueKey('expansion-${show.id}-${season.seasonNumber}-${initialExpanded}'),
        title: Text(seasonTitle),
        subtitle: Builder(builder: (context) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final sd = (seasonAirDate != null && seasonAirDate!.isNotEmpty)
              ? DateTime.tryParse(seasonAirDate!)
              : null;
          final seasonAired = sd != null &&
              !DateTime(sd.year, sd.month, sd.day).isAfter(today);

          String left;
          if (!seasonAired) {
            final when = (seasonAirDate != null && seasonAirDate!.isNotEmpty)
                ? seasonAirDate!
                : 'T.B.A.';
            left = 'Available $when';
          } else if (seasonAirDate != null && seasonAirDate!.isNotEmpty) {
            left = seasonAirDate!;
          } else {
            left = '';
          }
          final prefix = left.isNotEmpty ? '$left • ' : '';
          return Text('${prefix}Episodes: ${season.episodeCount}');
        }),
        trailing: SizedBox(
          width: 28,
          height: 28,
          child: Builder(builder: (context) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final sd = (seasonAirDate != null && seasonAirDate!.isNotEmpty)
                ? DateTime.tryParse(seasonAirDate!)
                : null;
      final seasonAired = sd != null &&
        !DateTime(sd.year, sd.month, sd.day).isAfter(today);
            return Checkbox(
            tristate: true,
            value: triStateValue,
              onChanged: seasonAired ? onBulkChange : null,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            );
          }),
        ),
        initiallyExpanded: initialExpanded,
  onExpansionChanged: onToggle,
        children: [
          if (season.episodeCount == 0)
            const ListTile(title: Text('No episodes listed for this season.'))
          else
            ...List.generate(season.episodeCount, (idx) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final seasonDate = (seasonAirDate != null && seasonAirDate!.isNotEmpty)
                  ? DateTime.tryParse(seasonAirDate!)
                  : null;
              final seasonAired = seasonDate == null
                  ? true
                  : !DateTime(seasonDate.year, seasonDate.month, seasonDate.day)
                      .isAfter(today);
              final epNum = idx + 1;
              final isChecked = epNum <= season.watched;
              final title = (titles != null &&
                      idx < titles!.length &&
                      titles![idx].trim().isNotEmpty)
                  ? titles![idx].trim()
                  : '';
              final line = title.isNotEmpty ? 'Ep $epNum: $title' : 'Ep $epNum';
              // Episode-level air date gating
              final epDateStr = (airDates != null && idx < airDates!.length)
                  ? airDates![idx]
                  : '';
              final epDate = epDateStr.isNotEmpty
                  ? DateTime.tryParse(epDateStr)
                  : null;
              bool epAired = epDate != null &&
                  !DateTime(epDate.year, epDate.month, epDate.day)
                      .isAfter(today);

              // Inference rule: if an episode has no release date but lies between
              // two episodes that have already aired, consider it released.
              bool inferredAiredBetween = false;
              if (!epAired && epDateStr.isEmpty && airDates != null && airDates!.isNotEmpty) {
                bool hasPrevAired = false;
                for (int j = idx - 1; j >= 0; j--) {
                  final s = airDates![j];
                  if (s.isEmpty) continue;
                  final dt = DateTime.tryParse(s);
                  if (dt == null) continue;
                  final day = DateTime(dt.year, dt.month, dt.day);
                  hasPrevAired = !day.isAfter(today);
                  break; // only the nearest previous known date matters
                }
                bool hasNextAired = false;
                for (int j = idx + 1; j < airDates!.length; j++) {
                  final s = airDates![j];
                  if (s.isEmpty) continue;
                  final dt = DateTime.tryParse(s);
                  if (dt == null) continue;
                  final day = DateTime(dt.year, dt.month, dt.day);
                  hasNextAired = !day.isAfter(today);
                  break; // only the nearest next known date matters
                }
                inferredAiredBetween = hasPrevAired && hasNextAired;
              }

              final enabled = seasonAired && (epAired || inferredAiredBetween);
        final host = context.findAncestorStateOfType<_ShowDetailPageState>();
        final settings = SettingsScope.of(context);
        final singleEp = settings.singleOpenEpisodes;
        final expanded = singleEp
          ? (host?._openEpisodePerSeason[season.seasonNumber] == epNum)
          : (host?._openEpisodesMulti[season.seasonNumber]?.contains(epNum) ?? false);
              return _EpisodeTile(
                show: show,
                season: season,
                episodeNumber: epNum,
                line: line,
                isChecked: isChecked,
                enabled: enabled,
                epDateStr: epDateStr,
                expanded: expanded,
                onEpisodeToggle: onEpisodeToggle,
                onExpandToggle: () async {
                  if (host == null) return;
                  final singleEp = SettingsScope.of(context).singleOpenEpisodes;
                  if (singleEp) {
                    final current = host._openEpisodePerSeason[season.seasonNumber];
                    if (current == epNum) {
                      host.setOpenEpisode(season.seasonNumber, null);
                      return;
                    }
                    final hasMeta = host._episodeOverviews[season.seasonNumber]?.containsKey(epNum) ?? false;
                    if (!hasMeta) {
                      await host._ensureEpisodeMeta(season.seasonNumber, epNum);
                    }
                    host.setOpenEpisode(season.seasonNumber, epNum);
                  } else {
                    // Multi-open: toggle membership in set
                    final set = host._openEpisodesMulti.putIfAbsent(season.seasonNumber, () => <int>{});
                    final willOpen = !set.contains(epNum);
                    if (willOpen) {
                      final hasMeta = host._episodeOverviews[season.seasonNumber]?.containsKey(epNum) ?? false;
                      if (!hasMeta) {
                        await host._ensureEpisodeMeta(season.seasonNumber, epNum);
                      }
                      set.add(epNum);
                    } else {
                      set.remove(epNum);
                    }
                    host._rebuild();
                  }
                },
              );
            }),
        ],
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.show,
    required this.season,
    required this.episodeNumber,
    required this.line,
    required this.isChecked,
    required this.enabled,
    required this.epDateStr,
    required this.onEpisodeToggle,
    required this.onExpandToggle,
    required this.expanded,
  });
  final Show show;
  final Season season;
  final int episodeNumber;
  final String line;
  final bool isChecked;
  final bool enabled;
  final String epDateStr;
  final void Function(int episodeNumber, bool newValue) onEpisodeToggle;
  final VoidCallback onExpandToggle;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final host = context.findAncestorStateOfType<_ShowDetailPageState>();
    final overview = host?._episodeOverviews[season.seasonNumber]?[episodeNumber] ?? '';
    final rating = host?._episodeRatings[season.seasonNumber]?[episodeNumber] ?? 0.0;
    final directors = host?._episodeDirectors[season.seasonNumber]?[episodeNumber] ?? const <String>[];
    final hasMeta = overview.isNotEmpty || rating > 0 || directors.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: isChecked,
                onChanged: enabled ? (v) => onEpisodeToggle(episodeNumber, v ?? false) : null,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.standard,
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onExpandToggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
        Text(
          line,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            // Grey out unreleased episodes while keeping them expandable
            color: !enabled
            ? (Theme.of(context).disabledColor)
            : null,
          ),
        ),
                        if (!enabled)
                          Text('Available ${epDateStr.isNotEmpty ? epDateStr : 'T.B.A.'}',
                              style: Theme.of(context).textTheme.bodySmall),
                        if (enabled && epDateStr.isNotEmpty)
                          Text(epDateStr, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                iconSize: 24,
                padding: const EdgeInsets.all(4),
                visualDensity: VisualDensity.compact,
                icon: Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                onPressed: onExpandToggle,
              ),
            ],
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 52, right: 8, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (directors.isNotEmpty)
                  Text('Director${directors.length > 1 ? 's' : ''}: ${directors.join(', ')}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                if (rating > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rate_rounded, size: 16, color: Color(0xFFFFC107)),
                        const SizedBox(width: 4),
                        Text(rating.toStringAsFixed(1), style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),
                if (overview.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(overview, style: Theme.of(context).textTheme.bodySmall),
                  ),
                if (!hasMeta)
                  Text('No details available.', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}
