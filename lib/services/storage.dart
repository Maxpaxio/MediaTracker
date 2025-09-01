import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WatchFlag { none, watchlist, completed }

class Season {
  final int seasonNumber;
  final String name;
  final int episodeCount;
  final int watched;

  const Season({
    required this.seasonNumber,
    required this.name,
    required this.episodeCount,
    this.watched = 0,
  });

  Season copyWith({int? watched}) => Season(
        seasonNumber: seasonNumber,
        name: name,
        episodeCount: episodeCount,
        watched: watched ?? this.watched,
      );

  double get progress => episodeCount == 0 ? 0 : watched / episodeCount;
  bool get complete => episodeCount > 0 && watched >= episodeCount;

  Map<String, dynamic> toJson() => {
        'n': seasonNumber,
        'name': name,
        'cnt': episodeCount,
        'w': watched,
      };

  factory Season.fromJson(Map<String, dynamic> m) => Season(
        seasonNumber: m['n'],
        name: m['name'],
        episodeCount: m['cnt'],
        watched: m['w'],
      );
}

class Show {
  final int id;
  final String title;
  final String overview;
  final String posterUrl;
  final String backdropUrl;
  final String firstAirDate; // YYYY-MM-DD
  final String? lastAirDate;
  final double rating; // 0..10
  final List<String> genres;
  final List<String> providers; // e.g. ["Disney+"]
  final List<Season> seasons;
  final WatchFlag flag;
  final int addedAt; // epoch ms
  final int updatedAt; // epoch ms

  const Show({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterUrl,
    required this.backdropUrl,
    required this.firstAirDate,
    this.lastAirDate,
    required this.rating,
    required this.genres,
    required this.providers,
    required this.seasons,
    this.flag = WatchFlag.none,
  required this.addedAt,
  required this.updatedAt,
  });

  Show copyWith({
    String? title,
    String? overview,
    String? posterUrl,
    String? backdropUrl,
    String? firstAirDate,
    String? lastAirDate,
    double? rating,
    List<String>? genres,
    List<String>? providers,
    List<Season>? seasons,
    WatchFlag? flag,
    int? addedAt,
    int? updatedAt,
  }) {
    return Show(
      id: id,
      title: title ?? this.title,
      overview: overview ?? this.overview,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      firstAirDate: firstAirDate ?? this.firstAirDate,
      lastAirDate: lastAirDate ?? this.lastAirDate,
      rating: rating ?? this.rating,
      genres: genres ?? this.genres,
      providers: providers ?? this.providers,
      seasons: seasons ?? this.seasons,
      flag: flag ?? this.flag,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get totalEpisodes => seasons.fold(0, (a, s) => a + s.episodeCount);
  int get watchedEpisodes => seasons.fold(0, (a, s) => a + s.watched);
  double get progress =>
      totalEpisodes == 0 ? 0 : watchedEpisodes / totalEpisodes;

  bool get isCompleted => flag == WatchFlag.completed;
  bool get isWatchlist => flag == WatchFlag.watchlist;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'overview': overview,
        'poster': posterUrl,
        'backdrop': backdropUrl,
        'fa': firstAirDate,
        'la': lastAirDate,
        'rating': rating,
        'genres': genres,
        'providers': providers,
        'flag': flag.index,
        'seasons': seasons.map((e) => e.toJson()).toList(),
  'addedAt': addedAt,
  'updatedAt': updatedAt,
      };

  factory Show.fromJson(Map<String, dynamic> m) => Show(
        id: m['id'],
        title: m['title'],
        overview: m['overview'],
        posterUrl: m['poster'],
        backdropUrl: m['backdrop'],
        firstAirDate: m['fa'],
        lastAirDate: m['la'],
        rating: (m['rating'] as num).toDouble(),
        genres: (m['genres'] as List).cast<String>(),
        providers: (m['providers'] as List).cast<String>(),
        flag: WatchFlag.values[m['flag']],
        seasons: (m['seasons'] as List).map((e) => Season.fromJson(e)).toList(),
  addedAt: (m['addedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
  updatedAt: (m['updatedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      );
}

class AppStorage extends ChangeNotifier {
  late SharedPreferences _prefs;
  final List<Show> _shows = [];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _load();
  }

// READS
  List<Show> get ongoing => _shows
      .where(
        (s) =>
            !s.isCompleted &&
            !s.isWatchlist &&
            s.watchedEpisodes > 0, // ← only if some progress exists
      )
      .toList();

  List<Show> get completed => _shows.where((s) => s.isCompleted).toList();

  List<Show> get watchlist =>
      _shows.where((s) => s.isWatchlist && !s.isCompleted).toList();

  /// All shows (unordered). Use display-time ordering in UI.
  List<Show> get all => List.unmodifiable(_shows);

  Show byId(int id) => _shows.firstWhere((e) => e.id == id);
  Show? tryGet(int id) =>
      _shows.where((e) => e.id == id).cast<Show?>().firstOrNull;
  bool exists(int id) => _shows.any((s) => s.id == id);

  // MUTATIONS (with global rules baked in)

  /// Insert if missing (no rule side-effects).
  void ensureShow(Show show) {
    final idx = _shows.indexWhere((s) => s.id == show.id);
    if (idx != -1) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final withTs = show.copyWith(
      addedAt: show.addedAt,
      updatedAt: now,
    );
    // If addedAt was not set meaningfully (e.g., 0), default to now.
    final normalized = withTs.addedAt > 0 ? withTs : withTs.copyWith(addedAt: now);
    _shows.add(normalized);
    _persist();
    notifyListeners();
  }

  /// Replace an existing show in place (preserves list order).
  /// If the show doesn't exist yet, it will be appended.
  void updateShow(Show show) {
    final idx = _shows.indexWhere((s) => s.id == show.id);
    if (idx == -1) {
      _shows.add(show);
    } else {
      _shows[idx] = show;
    }
    _persist();
    notifyListeners();
  }

  /// Toggle Watchlist with rules:
  /// - When turning ON: reset all progress to 0 and set flag=watchlist (removes completed).
  /// - When turning OFF: set flag=none (keep current progress as-is, typically 0).
  void toggleWatchlist(Show show) {
    final idx = _shows.indexWhere((s) => s.id == show.id);
    if (idx == -1) {
      // Not stored yet: add with reset progress & watchlist flag
      final reset = show.copyWith(
        flag: WatchFlag.watchlist,
        seasons: [for (final s in show.seasons) s.copyWith(watched: 0)],
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      _shows.add(reset);
    } else {
      final current = _shows[idx];
      if (current.isWatchlist) {
        // Turn OFF watchlist
        _shows[idx] = current.copyWith(
          flag: WatchFlag.none,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
      } else {
        // Turn ON watchlist → reset progress + set flag watchlist
        final reset = current.copyWith(
          flag: WatchFlag.watchlist,
          seasons: [for (final s in current.seasons) s.copyWith(watched: 0)],
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        _shows[idx] = reset;
      }
    }
    _persist();
    notifyListeners();
  }

  /// Mark Completed with rules:
  /// - Set flag=completed and mark ALL episodes watched.
  /// - Implicitly removes watchlist (since flag is now completed).
  void markCompleted(Show show) {
    final idx = _shows.indexWhere((s) => s.id == show.id);
    final base = idx == -1 ? show : _shows[idx];

    final allDone =
        base.seasons.map((s) => s.copyWith(watched: s.episodeCount)).toList();

    final newShow = base.copyWith(
      seasons: allDone,
      flag: WatchFlag.completed,
  updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    if (idx == -1) {
      _shows.add(newShow);
    } else {
      _shows[idx] = newShow;
    }
    _persist();
    notifyListeners();
  }

  /// Completely forget a show ("unsee").
  void removeShow(int showId) {
    _shows.removeWhere((s) => s.id == showId);
    _persist();
    notifyListeners();
  }

  /// Remove from watchlist → flag: none (progress unchanged).
  void removeFromWatchlist(int showId) {
    final idx = _shows.indexWhere((s) => s.id == showId);
    if (idx == -1) return;
    _shows[idx] = _shows[idx].copyWith(
      flag: WatchFlag.none,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _persist();
    notifyListeners();
  }

  /// Removing from completed should *unsee* the show by default.
  /// (UI can override by re-adding with a reset, if desired.)
  void removeFromCompleted(int showId) {
    removeShow(showId);
  }

  /// Update a season's watched count.
  /// Rule: if any progress exists, remove watchlist (flag -> none).
  void updateSeasonProgress(int showId, int seasonNumber, int watched) {
    final idx = _shows.indexWhere((s) => s.id == showId);
    if (idx == -1) return;
    final show = _shows[idx];

    final newSeasons = [
      for (final s in show.seasons)
        if (s.seasonNumber == seasonNumber) s.copyWith(watched: watched) else s,
    ];

    var updated = show.copyWith(
      seasons: newSeasons,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    // If there is now any progress, clear watchlist.
    if (updated.isWatchlist && updated.watchedEpisodes > 0) {
      updated = updated.copyWith(flag: WatchFlag.none);
    }

    _shows[idx] = updated;
    _persist();
    notifyListeners();
  }

  // PERSISTENCE
  void _persist() {
    final data = jsonEncode(_shows.map((e) => e.toJson()).toList());
    _prefs.setString('shows', data);
  }

  void _load() {
    final saved = _prefs.getString('shows');
    if (saved != null) {
      final list = (jsonDecode(saved) as List).cast<Map<String, dynamic>>();
      _shows
        ..clear()
        ..addAll(list.map(Show.fromJson));
      return;
    }
    // Seed demo so UI looks right on first run
  final now = DateTime.now().millisecondsSinceEpoch;
  _shows.addAll([
      Show(
        id: 1,
        title: 'Bluey',
        overview:
            'Bluey is an inexhaustible six-year-old Blue Heeler who loves to play and turns everyday family life into extraordinary adventures.',
        posterUrl:
            'https://image.tmdb.org/t/p/w342/5qS3d1vZEBtcHTulrHfXESyqSeW.jpg',
        backdropUrl:
            'https://image.tmdb.org/t/p/w780/o1lGHBX9nuSUXGMWzME2YkdE590.jpg',
        firstAirDate: '2018-10-01',
        lastAirDate: '2024-04-21',
        rating: 8.6,
        genres: ['Animation', 'Kids', 'Comedy'],
        providers: ['Disney+'],
        seasons: const [
          Season(seasonNumber: 1, name: 'Season 1', episodeCount: 52),
          Season(seasonNumber: 2, name: 'Season 2', episodeCount: 52),
          Season(seasonNumber: 3, name: 'Season 3', episodeCount: 49),
        ],
        flag: WatchFlag.watchlist,
    addedAt: now,
    updatedAt: now,
      ),
    ]);
    _persist();
  }
}

extension AppStorageAdmin on AppStorage {
  /// Replace all shows with the provided list; persists and notifies.
  void replaceAll(List<Show> items) {
    _shows
      ..clear()
      ..addAll(items);
    _persist();
    notifyListeners();
  }
}

// Small utility for firstOrNull without importing collection pkg.
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// Inherited widget to access storage anywhere without extra packages.
class StorageScope extends InheritedNotifier<AppStorage> {
  const StorageScope({
    super.key,
    required AppStorage storage,
    required super.child,
  }) : super(notifier: storage);

  static AppStorage of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StorageScope>()!.notifier!;
}
