class Show {
  int tmdbId;
  String title;
  List<Season> seasons;
  String? posterUrl;
  String? platformLogoUrl;
  bool isWatchlisted;

  Show({
    required this.tmdbId,
    required this.title,
    required this.seasons,
    this.posterUrl,
    this.platformLogoUrl,
    this.isWatchlisted = false,
  });

  // Empty placeholder used when no existing show is found
  factory Show.empty() => Show(tmdbId: -1, title: "", seasons: []);

  /// ✅ All episodes watched?
  bool get allWatched =>
      seasons.isNotEmpty &&
      seasons.every((s) => s.episodes.every((e) => e.watched));

  /// ✅ Any episode watched?
  bool get anyWatched =>
      seasons.any((s) => s.episodes.any((e) => e.watched));

  /// ✅ Progress as fraction [0.0–1.0]
  double get progress {
    final totalEpisodes = seasons.fold<int>(
        0, (sum, season) => sum + season.episodes.length);
    if (totalEpisodes == 0) return 0.0;

    final watchedEpisodes = seasons.fold<int>(
        0,
        (sum, season) =>
            sum + season.episodes.where((e) => e.watched).length);
    return watchedEpisodes / totalEpisodes;
  }

  /// ✅ Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'tmdbId': tmdbId,
      'title': title,
      'posterUrl': posterUrl,
      'platformLogoUrl': platformLogoUrl,
      'isWatchlisted': isWatchlisted,
      'seasons': seasons.map((s) => s.toJson()).toList(),
    };
  }

  /// ✅ Deserialize from JSON
  factory Show.fromJson(Map<String, dynamic> json) {
    return Show(
      tmdbId: json['tmdbId'] ?? -1,
      title: json['title'] ?? "",
      posterUrl: json['posterUrl'],
      platformLogoUrl: json['platformLogoUrl'],
      isWatchlisted: json['isWatchlisted'] ?? false,
      seasons: (json['seasons'] as List<dynamic>? ?? [])
          .map((s) => Season.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Season {
  int number;
  List<Episode> episodes;

  Season({required this.number, required this.episodes});

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'episodes': episodes.map((e) => e.toJson()).toList(),
    };
  }

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      number: json['number'] ?? 0,
      episodes: (json['episodes'] as List<dynamic>? ?? [])
          .map((e) => Episode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Episode {
  int number;
  String title;
  bool watched;

  Episode({
    required this.number,
    required this.title,
    this.watched = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'title': title,
      'watched': watched,
    };
  }

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      number: json['number'] ?? 0,
      title: json['title'] ?? "",
      watched: json['watched'] ?? false,
    );
  }
}
