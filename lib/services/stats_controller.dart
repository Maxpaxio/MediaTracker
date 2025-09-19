import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'storage.dart';
import 'tmdb_api.dart';

class StatsSnapshot {
  final int totalMinutes;
  final int movieMinutes;
  final int tvMinutes;
  final int completedMovies;
  final int watchedEpisodes;
  final bool usedFallback;
  const StatsSnapshot({
    required this.totalMinutes,
    required this.movieMinutes,
    required this.tvMinutes,
    required this.completedMovies,
    required this.watchedEpisodes,
    required this.usedFallback,
  });
  static const empty = StatsSnapshot(
    totalMinutes: 0,
    movieMinutes: 0,
    tvMinutes: 0,
    completedMovies: 0,
    watchedEpisodes: 0,
    usedFallback: false,
  );
}

/// Computes and caches statistics in the background.
/// - Uses cached movie runtimes and season episode runtimes when available.
/// - Immediately provides a best-effort snapshot (may include fallbacks),
///   then refines it as network results arrive.
class StatsController extends ChangeNotifier {
  StatsController(this.storage);

  final AppStorage storage;
  final TmdbApi _api = TmdbApi();

  // UI fallbacks
  static const int fallbackMovieMinutes = 120;
  static const int fallbackEpisodeMinutes = 45;

  // Debounce scheduling
  Timer? _debounce;
  bool _loading = false;
  bool get loading => _loading;
  bool _updating = false;
  bool get updating => _updating;

  StatsSnapshot _snapshot = StatsSnapshot.empty;
  StatsSnapshot get snapshot => _snapshot;

  late SharedPreferences _prefs;

  // Caches
  // movieId -> minutes
  final Map<int, int> _movieRt = <int, int>{};
  // "showId-season" -> [minutes per episode]
  final Map<String, List<int>> _seasonRt = <String, List<int>>{};

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadCaches();
    storage.addListener(_scheduleRecompute);
    // Kick off an initial compute after init
    _scheduleRecompute();
  }

  @override
  void dispose() {
    storage.removeListener(_scheduleRecompute);
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleRecompute() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_compute(backgroundFetch: true));
    });
  }

  // Persist caches to prefs
  void _saveCaches() {
    final moviesJson = jsonEncode(_movieRt.map((k, v) => MapEntry(k.toString(), v)));
    final seasonsJson = jsonEncode(
      _seasonRt.map((k, v) => MapEntry(k, v)),
    );
    _prefs.setString('stats.movieRuntimes', moviesJson);
    _prefs.setString('stats.seasonRuntimes', seasonsJson);
  }

  void _loadCaches() {
    try {
      final moviesJson = _prefs.getString('stats.movieRuntimes');
      if (moviesJson != null && moviesJson.isNotEmpty) {
        final Map<String, dynamic> m = jsonDecode(moviesJson);
        _movieRt
          ..clear()
          ..addAll(m.map((k, v) => MapEntry(int.tryParse(k) ?? 0, (v as num).toInt())))
          ..removeWhere((k, _) => k == 0);
      }
    } catch (_) {}
    try {
      final seasonsJson = _prefs.getString('stats.seasonRuntimes');
      if (seasonsJson != null && seasonsJson.isNotEmpty) {
        final Map<String, dynamic> m = jsonDecode(seasonsJson);
        _seasonRt
          ..clear()
          ..addAll(m.map((k, v) => MapEntry(k, (v as List).map((e) => (e as num).toInt()).toList())));
      }
    } catch (_) {}
  }

  /// Force an immediate recompute and background fetch
  Future<void> refreshNow() async {
    await _compute(backgroundFetch: true);
  }

  Future<void> _compute({required bool backgroundFetch}) async {
  _loading = true;
  notifyListeners();

    int movieMinutes = 0;
    int completedMovies = 0;
    int tvMinutes = 0;
    int watchedEpisodes = 0;
    bool usedFallback = false;

    // Collect fetch work to do after the first snapshot
    final List<Future<void>> fetches = [];

    // Movies: completed only
    final movies = storage.completed.where((s) => s.mediaType == MediaType.movie);
    for (final m in movies) {
      completedMovies++;
      final cached = _movieRt[m.id];
      if (cached != null && cached > 0) {
        movieMinutes += cached;
      } else {
        movieMinutes += fallbackMovieMinutes;
        usedFallback = true;
        if (backgroundFetch) {
          fetches.add(_fetchMovieRuntime(m.id));
        }
      }
    }

    // TV: per season watched episodes
    final tvShows = storage.all.where((s) => s.mediaType == MediaType.tv);
    for (final show in tvShows) {
      for (final season in show.seasons) {
        final w = season.watched.clamp(0, season.episodeCount);
        if (w <= 0) continue;
        watchedEpisodes += w;
        final key = '${show.id}-${season.seasonNumber}';
        final list = _seasonRt[key];
        if (list != null && list.isNotEmpty) {
          int sum = 0;
          for (var i = 0; i < w; i++) {
            final rt = (i < list.length ? list[i] : 0);
            if (rt > 0) sum += rt; else { sum += fallbackEpisodeMinutes; usedFallback = true; }
          }
          tvMinutes += sum;
        } else {
          // Fallback now; fetch in background
          tvMinutes += w * fallbackEpisodeMinutes;
          usedFallback = true;
          if (backgroundFetch) {
            fetches.add(_fetchSeasonRuntimes(show.id, season.seasonNumber));
          }
        }
      }
    }

    // First snapshot (fast, may contain fallbacks)
    _snapshot = StatsSnapshot(
      totalMinutes: movieMinutes + tvMinutes,
      movieMinutes: movieMinutes,
      tvMinutes: tvMinutes,
      completedMovies: completedMovies,
      watchedEpisodes: watchedEpisodes,
      usedFallback: usedFallback,
    );
    _loading = false;
    notifyListeners();

    if (fetches.isEmpty) {
      return;
    }

    // Indicate background updating while fetching precise runtimes
    _updating = true;
    notifyListeners();

    // Fetch everything in parallel; errors ignored.
    try {
      await Future.wait(fetches.map((f) => f.catchError((_) {})));
    } catch (_) {}

    // After fetches, persist caches and recompute for a refined snapshot
  _saveCaches();
  await _recomputeFromCache();
  _updating = false;
  notifyListeners();
  }

  Future<void> _recomputeFromCache() async {
    int movieMinutes = 0;
    int completedMovies = 0;
    int tvMinutes = 0;
    int watchedEpisodes = 0;
    bool usedFallback = false;

    final movies = storage.completed.where((s) => s.mediaType == MediaType.movie);
    for (final m in movies) {
      completedMovies++;
      final cached = _movieRt[m.id];
      if (cached != null && cached > 0) movieMinutes += cached; else { movieMinutes += fallbackMovieMinutes; usedFallback = true; }
    }

    final tvShows = storage.all.where((s) => s.mediaType == MediaType.tv);
    for (final show in tvShows) {
      for (final season in show.seasons) {
        final w = season.watched.clamp(0, season.episodeCount);
        if (w <= 0) continue;
        watchedEpisodes += w;
        final key = '${show.id}-${season.seasonNumber}';
        final list = _seasonRt[key];
        if (list != null && list.isNotEmpty) {
          int sum = 0;
          for (var i = 0; i < w; i++) {
            final rt = (i < list.length ? list[i] : 0);
            if (rt > 0) sum += rt; else { sum += fallbackEpisodeMinutes; usedFallback = true; }
          }
          tvMinutes += sum;
        } else {
          tvMinutes += w * fallbackEpisodeMinutes;
          usedFallback = true;
        }
      }
    }

    _snapshot = StatsSnapshot(
      totalMinutes: movieMinutes + tvMinutes,
      movieMinutes: movieMinutes,
      tvMinutes: tvMinutes,
      completedMovies: completedMovies,
      watchedEpisodes: watchedEpisodes,
      usedFallback: usedFallback,
    );
    notifyListeners();
  }

  Future<void> _fetchMovieRuntime(int movieId) async {
    try {
      final extras = await _api.fetchMovieExtras(movieId);
      final rt = extras.runtime;
      if (rt > 0) {
        _movieRt[movieId] = rt;
      }
    } catch (_) {}
  }

  Future<void> _fetchSeasonRuntimes(int showId, int seasonNumber) async {
    try {
      final list = await _api.fetchSeasonEpisodeRuntimes(showId, seasonNumber);
      if (list.isNotEmpty) {
        _seasonRt['$showId-$seasonNumber'] = list;
      }
    } catch (_) {}
  }
}

class StatsScope extends InheritedNotifier<StatsController> {
  const StatsScope({super.key, required StatsController controller, required super.child})
      : super(notifier: controller);

  static StatsController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StatsScope>()!.notifier!;
}
