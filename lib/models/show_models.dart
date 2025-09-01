// lib/models/show_models.dart

/// Lightweight episode used in season lists.
class EpisodeLite {
  final int number;
  final String name;

  const EpisodeLite({
    required this.number,
    required this.name,
  });

  EpisodeLite copyWith({int? number, String? name}) =>
      EpisodeLite(number: number ?? this.number, name: name ?? this.name);
}

/// A single TV season with progress.
class Season {
  final int seasonNumber;
  final String name;
  final int episodeCount;
  final int watched; // number of episodes marked watched (0..episodeCount)

  const Season({
    required this.seasonNumber,
    required this.name,
    required this.episodeCount,
    required this.watched,
  });

  double get progress =>
      episodeCount == 0 ? 0.0 : (watched.clamp(0, episodeCount) / episodeCount);

  Season copyWith({
    int? seasonNumber,
    String? name,
    int? episodeCount,
    int? watched,
  }) {
    return Season(
      seasonNumber: seasonNumber ?? this.seasonNumber,
      name: name ?? this.name,
      episodeCount: episodeCount ?? this.episodeCount,
      watched: watched ?? this.watched,
    );
  }
}

/// Main show entity as used across the app.
/// Includes optional hero metadata and computed totals.
class Show {
  final int id;
  final String title;
  final String overview;
  final String posterUrl;
  final String backdropUrl;
  final List<Season> seasons;

  // Optional metadata for hero / info pages:
  final String? firstAirDate; // e.g., "2016-07-15"
  final String? lastAirDate; // e.g., "2024-11-10"
  final List<String> genres; // e.g., ["Drama", "Sci-Fi & Fantasy"]
  final double? rating; // TMDB vote_average (0..10)

  // Tracking flags.
  final bool isWatchlist;
  final bool isCompleted;

  const Show({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterUrl,
    required this.backdropUrl,
    required this.seasons,
    this.firstAirDate,
    this.lastAirDate,
    this.genres = const [],
    this.rating,
    this.isWatchlist = false,
    this.isCompleted = false,
  });

  /// Total episodes across all seasons.
  int get totalEpisodes =>
      seasons.fold<int>(0, (sum, s) => sum + s.episodeCount);

  /// Total watched episodes across all seasons.
  int get watchedEpisodes => seasons.fold<int>(
      0, (sum, s) => sum + s.watched.clamp(0, s.episodeCount));

  /// Overall progress 0.0–1.0 (safe if total is 0).
  double get progress =>
      totalEpisodes == 0 ? 0.0 : (watchedEpisodes / totalEpisodes);

  Show copyWith({
    int? id,
    String? title,
    String? overview,
    String? posterUrl,
    String? backdropUrl,
    List<Season>? seasons,
    String? firstAirDate,
    String? lastAirDate,
    List<String>? genres,
    double? rating,
    bool? isWatchlist,
    bool? isCompleted,
  }) {
    return Show(
      id: id ?? this.id,
      title: title ?? this.title,
      overview: overview ?? this.overview,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      seasons: seasons ?? this.seasons,
      firstAirDate: firstAirDate ?? this.firstAirDate,
      lastAirDate: lastAirDate ?? this.lastAirDate,
      genres: genres ?? this.genres,
      rating: rating ?? this.rating,
      isWatchlist: isWatchlist ?? this.isWatchlist,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
