import 'dart:convert';
import 'package:http/http.dart' as http;

import 'storage.dart'; // storage Show/Season

class TmdbApi {
  static const _base = 'https://api.themoviedb.org/3';
  static const _img = 'https://image.tmdb.org/t/p';
  static const _key = '6f8c0bbf88560ad26d47fcfa5f12cdc4';

  // ---------------- WATCH PROVIDERS (STRICT REGION) ----------------
  /// Fetch raw provider regions available for a show (TV or movie).
  Future<List<String>> fetchAvailableProviderRegions(int id,
      {required bool isMovie}) async {
    final path = isMovie ? 'movie' : 'tv';
    final uri = Uri.parse('$_base/$path/$id/watch/providers')
        .replace(queryParameters: {'api_key': _key});
    final res = await http.get(uri);
    if (res.statusCode != 200) return const [];
    final root =
        (json.decode(res.body) as Map?)?.cast<String, dynamic>() ?? const {};
    final results =
        (root['results'] as Map?)?.cast<String, dynamic>() ?? const {};
    final codes = results.keys
        .map((e) => e.toString().toUpperCase())
        .where((e) => e.length == 2)
        .toList();
    codes.sort();
    return codes;
  }

  /// Like [fetchAvailableProviderRegions] but also returns a count of unique providers
  /// (streaming + rent/buy) per region for quick UI hinting.
  Future<List<({String code, int count})>>
      fetchAvailableProviderRegionsWithCounts(int id,
          {required bool isMovie}) async {
    final path = isMovie ? 'movie' : 'tv';
    final uri = Uri.parse('$_base/$path/$id/watch/providers')
        .replace(queryParameters: {'api_key': _key});
    final res = await http.get(uri);
    if (res.statusCode != 200) return const [];
    final root =
        (json.decode(res.body) as Map?)?.cast<String, dynamic>() ?? const {};
    final results =
        (root['results'] as Map?)?.cast<String, dynamic>() ?? const {};
    final out = <({String code, int count})>[];
    for (final entry in results.entries) {
      final code = entry.key.toUpperCase();
      final picked = (entry.value as Map?)?.cast<String, dynamic>();
      if (picked == null) continue;
      List<Map<String, dynamic>> norm(String key) {
        final list = (picked[key] as List?) ?? const [];
        return list
            .map<Map<String, dynamic>>(
                (e) => (e as Map?)?.cast<String, dynamic>() ?? const {})
            .toList();
      }

      final flatrate = norm('flatrate');
      final free = norm('free');
      final ads = norm('ads');
      final rent = norm('rent');
      final buy = norm('buy');
      final uniq = <int>{};
      void add(List<Map<String, dynamic>> l) {
        for (final m in l) {
          final id = (m['provider_id'] as num?)?.toInt() ?? -1;
          if (id > 0) uniq.add(id);
        }
      }

      add(flatrate);
      add(free);
      add(ads);
      add(rent);
      add(buy);
      out.add((code: code, count: uniq.length));
    }
    out.sort((a, b) => a.code.compareTo(b.code));
    return out;
  }

  /// Streaming-only (flatrate+free+ads) region counts. Excludes regions that only
  /// have rent/buy options.
  Future<List<({String code, int count})>> fetchStreamingRegionCounts(int id,
      {required bool isMovie}) async {
    final path = isMovie ? 'movie' : 'tv';
    final uri = Uri.parse('$_base/$path/$id/watch/providers')
        .replace(queryParameters: {'api_key': _key});
    final res = await http.get(uri);
    if (res.statusCode != 200) return const [];
    final root =
        (json.decode(res.body) as Map?)?.cast<String, dynamic>() ?? const {};
    final results =
        (root['results'] as Map?)?.cast<String, dynamic>() ?? const {};
    final out = <({String code, int count})>[];
    for (final entry in results.entries) {
      final code = entry.key.toUpperCase();
      final picked = (entry.value as Map?)?.cast<String, dynamic>();
      if (picked == null) continue;
      List<Map<String, dynamic>> norm(String key) {
        final list = (picked[key] as List?) ?? const [];
        return list
            .map<Map<String, dynamic>>(
                (e) => (e as Map?)?.cast<String, dynamic>() ?? const {})
            .toList();
      }

      final flatrate = norm('flatrate');
      final free = norm('free');
      final ads = norm('ads');
      final streaming = <int>{};
      void add(List<Map<String, dynamic>> l) {
        for (final m in l) {
          final id = (m['provider_id'] as num?)?.toInt() ?? -1;
          if (id > 0) streaming.add(id);
        }
      }

      add(flatrate);
      add(free);
      add(ads);
      if (streaming.isEmpty) continue; // skip rent/buy-only regions
      out.add((code: code, count: streaming.length));
    }
    out.sort((a, b) => a.code.compareTo(b.code));
    return out;
  }

  /// Region-specific watch providers for a TV show.
  ///
  /// Returns two lists of provider maps for the EXACT [region] (e.g. "SE").
  /// If the region is not present, both lists are empty (no fallback).
  Future<
      ({
        List<Map<String, dynamic>> streaming,
        List<Map<String, dynamic>> rentBuy
      })> fetchWatchProviders(int showId, {required String region}) async {
    final uri = Uri.parse('$_base/tv/$showId/watch/providers')
        .replace(queryParameters: {'api_key': _key});
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      return (
        streaming: <Map<String, dynamic>>[],
        rentBuy: <Map<String, dynamic>>[]
      );
    }

    final root = (json.decode(res.body) as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final results = (root['results'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    final picked =
        (results[region.toUpperCase()] as Map?)?.cast<String, dynamic>();
    if (picked == null) {
      return (
        streaming: <Map<String, dynamic>>[],
        rentBuy: <Map<String, dynamic>>[]
      );
    }

    List<Map<String, dynamic>> normalize(String key) {
      final link = (picked['link'] as String?) ?? '';
      final raw = (picked[key] as List?) ?? const [];
      return raw.map<Map<String, dynamic>>((e) {
        final m =
            (e as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
        return {
          'provider_id': (m['provider_id'] as num?)?.toInt() ?? 0,
          'provider_name': (m['provider_name'] as String?) ?? 'Unknown',
          'logo_path': (m['logo_path'] as String?) ?? '',
          'link': link,
        };
      }).toList(growable: false);
    }

    Map<int, Map<String, dynamic>> dedupe(List<Map<String, dynamic>> list) {
      final out = <int, Map<String, dynamic>>{};
      for (final m in list) {
        final id = (m['provider_id'] as int?) ?? 0;
        out.putIfAbsent(id, () => m);
      }
      return out;
    }

    final flatrate = normalize('flatrate');
    final free = normalize('free');
    final ads = normalize('ads');
    final rent = normalize('rent');
    final buy = normalize('buy');

    final streaming =
        dedupe(<Map<String, dynamic>>[...flatrate, ...free, ...ads])
            .values
            .toList(growable: false);
    final rentBuy = dedupe(<Map<String, dynamic>>[...rent, ...buy])
        .values
        .toList(growable: false);

    return (streaming: streaming, rentBuy: rentBuy);
  }

  /// Region-specific watch providers for a Movie (same shape as TV version).
  Future<
          ({
            List<Map<String, dynamic>> streaming,
            List<Map<String, dynamic>> rentBuy
          })>
      fetchMovieWatchProviders(int movieId, {required String region}) async {
    final uri = Uri.parse('$_base/movie/$movieId/watch/providers')
        .replace(queryParameters: {'api_key': _key});
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      return (
        streaming: <Map<String, dynamic>>[],
        rentBuy: <Map<String, dynamic>>[]
      );
    }

    final root = (json.decode(res.body) as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final results = (root['results'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    final picked =
        (results[region.toUpperCase()] as Map?)?.cast<String, dynamic>();
    if (picked == null) {
      return (
        streaming: <Map<String, dynamic>>[],
        rentBuy: <Map<String, dynamic>>[]
      );
    }

    List<Map<String, dynamic>> normalize(String key) {
      final link = (picked['link'] as String?) ?? '';
      final raw = (picked[key] as List?) ?? const [];
      return raw.map<Map<String, dynamic>>((e) {
        final m =
            (e as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
        return {
          'provider_id': (m['provider_id'] as num?)?.toInt() ?? 0,
          'provider_name': (m['provider_name'] as String?) ?? 'Unknown',
          'logo_path': (m['logo_path'] as String?) ?? '',
          'link': link,
        };
      }).toList(growable: false);
    }

    Map<int, Map<String, dynamic>> dedupe(List<Map<String, dynamic>> list) {
      final out = <int, Map<String, dynamic>>{};
      for (final m in list) {
        final id = (m['provider_id'] as int?) ?? 0;
        out.putIfAbsent(id, () => m);
      }
      return out;
    }

    final flatrate = normalize('flatrate');
    final free = normalize('free');
    final ads = normalize('ads');
    final rent = normalize('rent');
    final buy = normalize('buy');

    final streaming =
        dedupe(<Map<String, dynamic>>[...flatrate, ...free, ...ads])
            .values
            .toList(growable: false);
    final rentBuy = dedupe(<Map<String, dynamic>>[...rent, ...buy])
        .values
        .toList(growable: false);

    return (streaming: streaming, rentBuy: rentBuy);
  }

  // ---------------- SHOW DETAIL → storage model ----------------

  /// Fetch full TMDB TV detail and map into your **storage** Show with Seasons.
  /// Uses `language=en-US` so season labels are "Season".
  Future<Show> fetchShowDetailStorage(int showId) async {
    final uri = Uri.parse('$_base/tv/$showId')
        .replace(queryParameters: {'api_key': _key, 'language': 'en-US'});
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('TMDB detail failed ${res.statusCode}');
    }
    final m = (json.decode(res.body) as Map).cast<String, dynamic>();

    String asStr(dynamic v) => (v ?? '').toString();
    double asDouble(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    int asInt(dynamic v) => (v is num) ? v.toInt() : 0;

    final title = asStr(m['name'] ?? m['original_name'] ?? m['title']);
    final overview = asStr(m['overview']);
    final posterPath = asStr(m['poster_path']);
    final backdropPath = asStr(m['backdrop_path']);
    final firstAir = asStr(m['first_air_date']);
    final lastAirStr = asStr(m['last_air_date']);
    final lastAir = lastAirStr.isEmpty ? null : lastAirStr;
    final vote = asDouble(m['vote_average']);

    final genres = ((m['genres'] as List?) ?? const [])
        .map((e) => (e as Map?)?['name'])
        .whereType<String>()
        .toList(growable: false);

    final seasons = ((m['seasons'] as List?) ?? const [])
        .map((e) =>
            (e as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{})
        .where((e) => asInt(e['season_number']) >= 1)
        .map((e) => Season(
              seasonNumber: asInt(e['season_number']),
              name: asStr(e['name']), // (en-US gives "Season 1" etc.)
              episodeCount: asInt(e['episode_count']),
              watched: 0,
            ))
        .toList(growable: false);

    final now = DateTime.now().millisecondsSinceEpoch;
    return Show(
      id: asInt(m['id']),
      title: title,
      overview: overview,
      posterUrl: posterPath.isNotEmpty ? '$_img/w342$posterPath' : '',
      backdropUrl: backdropPath.isNotEmpty ? '$_img/w780$backdropPath' : '',
      firstAirDate: firstAir,
      lastAirDate: lastAir,
      rating: vote,
      genres: genres,
      providers: const <String>[],
      seasons: seasons,
      mediaType: MediaType.tv,
      addedAt: now,
      updatedAt: now,
    );
  }

  /// Fetch TMDB Movie details and map into storage.Show with mediaType=movie.
  Future<Show> fetchMovieDetailStorage(int movieId) async {
    final uri = Uri.parse('$_base/movie/$movieId')
        .replace(queryParameters: {'api_key': _key, 'language': 'en-US'});
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('TMDB movie detail failed ${res.statusCode}');
    }
    final m = (json.decode(res.body) as Map).cast<String, dynamic>();

    String asStr2(dynamic v) => (v ?? '').toString();
    double asDouble2(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    int asInt2(dynamic v) => (v is num) ? v.toInt() : 0;

    final title = asStr2(m['title'] ?? m['original_title']);
    final overview = asStr2(m['overview']);
    final posterPath = asStr2(m['poster_path']);
    final backdropPath = asStr2(m['backdrop_path']);
    final releaseDate = asStr2(m['release_date']);
    final vote = asDouble2(m['vote_average']);

    final genres = ((m['genres'] as List?) ?? const [])
        .map((e) => (e as Map?)?['name'])
        .whereType<String>()
        .toList(growable: false);

    final now = DateTime.now().millisecondsSinceEpoch;
    return Show(
      id: asInt2(m['id']),
      title: title,
      overview: overview,
      posterUrl: posterPath.isNotEmpty ? '$_img/w342$posterPath' : '',
      backdropUrl: backdropPath.isNotEmpty ? '$_img/w780$backdropPath' : '',
      firstAirDate: releaseDate,
      lastAirDate: null,
      rating: vote,
      genres: genres,
      providers: const <String>[],
      seasons: const <Season>[],
      mediaType: MediaType.movie,
      addedAt: now,
      updatedAt: now,
    );
  }

  // ---------------- EPISODE TITLES (per season) ----------------

  /// Fetch episode titles for a season (language en-US).
  /// Returns a list of titles indexed by (episodeNumber - 1).
  Future<List<String>> fetchSeasonEpisodeTitles(
      int showId, int seasonNumber) async {
    final uri = Uri.parse('$_base/tv/$showId/season/$seasonNumber')
        .replace(queryParameters: {'api_key': _key, 'language': 'en-US'});
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      return const <String>[];
    }
    final m = (json.decode(res.body) as Map).cast<String, dynamic>();
    final eps = (m['episodes'] as List?) ?? const [];
    return eps.map<String>((e) {
      final em =
          (e as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      final name = (em['name'] as String?) ?? '';
      return name;
    }).toList(growable: false);
  }

  // ---------------- MORE INFO (creators/companies/runtime) ----------------

  /// Fetch extra details for the More Info page: creators, companies, runtimes, etc.
  Future<
      ({
        List<String> creators,
        List<({String name, String logoPath})> companies,
        List<int> episodeRunTimes,
        String firstAirDate,
        double rating,
        List<String> genres,
      })> fetchShowExtras(int showId) async {
    final uri = Uri.parse('$_base/tv/$showId').replace(
      queryParameters: {
        'api_key': _key,
        'language': 'en-US',
      },
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      return (
        creators: const <String>[],
        companies: const <({String name, String logoPath})>[],
        episodeRunTimes: const <int>[],
        firstAirDate: '',
        rating: 0.0,
        genres: const <String>[],
      );
    }

    final m = (json.decode(res.body) as Map).cast<String, dynamic>();
    List<String> creators = ((m['created_by'] as List?) ?? const [])
        .map((e) => (e as Map?)?['name'])
        .whereType<String>()
        .toList(growable: false);
    final companies = ((m['production_companies'] as List?) ?? const [])
        .map((e) => (e as Map?)?.cast<String, dynamic>() ?? const {})
        .map<({String name, String logoPath})>((mm) => (
              name: (mm['name'] as String?) ?? '—',
              logoPath: (mm['logo_path'] as String?) ?? '',
            ))
        .toList(growable: false);
    final runTimes = ((m['episode_run_time'] as List?) ?? const [])
        .whereType<num>()
        .map((n) => n.toInt())
        .toList(growable: false);
    final firstAir = (m['first_air_date'] as String?) ?? '';
    final rating = (m['vote_average'] as num?)?.toDouble() ?? 0.0;
    final genres = ((m['genres'] as List?) ?? const [])
        .map((e) => (e as Map?)?['name'])
        .whereType<String>()
        .toList(growable: false);

    return (
      creators: creators,
      companies: companies,
      episodeRunTimes: runTimes,
      firstAirDate: firstAir,
      rating: rating,
      genres: genres,
    );
  }

  /// Movie extras for More Info: companies, runtime, release date, rating, genres.
  Future<
      ({
        List<({String name, String logoPath})> companies,
        int runtime,
        String releaseDate,
        double rating,
        List<String> genres,
      })> fetchMovieExtras(int movieId) async {
    final uri = Uri.parse('$_base/movie/$movieId').replace(
      queryParameters: {
        'api_key': _key,
        'language': 'en-US',
      },
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      return (
        companies: const <({String name, String logoPath})>[],
        runtime: 0,
        releaseDate: '',
        rating: 0.0,
        genres: const <String>[],
      );
    }

    final m = (json.decode(res.body) as Map).cast<String, dynamic>();
    final companies = ((m['production_companies'] as List?) ?? const [])
        .map((e) => (e as Map?)?.cast<String, dynamic>() ?? const {})
        .map<({String name, String logoPath})>((mm) => (
              name: (mm['name'] as String?) ?? '—',
              logoPath: (mm['logo_path'] as String?) ?? '',
            ))
        .toList(growable: false);
    final runtime = (m['runtime'] as num?)?.toInt() ?? 0;
    final release = (m['release_date'] as String?) ?? '';
    final rating = (m['vote_average'] as num?)?.toDouble() ?? 0.0;
    final genres = ((m['genres'] as List?) ?? const [])
        .map((e) => (e as Map?)?['name'])
        .whereType<String>()
        .toList(growable: false);

    return (
      companies: companies,
      runtime: runtime,
      releaseDate: release,
      rating: rating,
      genres: genres,
    );
  }

  /// Fetch top aggregate cast (with episode counts and character names).
  Future<List<Map<String, dynamic>>> fetchAggregateCast(int showId) async {
    final uri = Uri.parse('$_base/tv/$showId/aggregate_credits').replace(
      queryParameters: {
        'api_key': _key,
        'language': 'en-US',
      },
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return const <Map<String, dynamic>>[];
    final m = (json.decode(res.body) as Map).cast<String, dynamic>();
    final cast = (m['cast'] as List?) ?? const [];

    List<Map<String, dynamic>> list = cast.map<Map<String, dynamic>>((e) {
      final mm = (e as Map?)?.cast<String, dynamic>() ?? const {};
      final pid = (mm['id'] as num?)?.toInt() ?? 0;
      final name = (mm['name'] as String?) ?? '';
      final profilePath = (mm['profile_path'] as String?) ?? '';
      final roles = (mm['roles'] as List?) ?? const [];
      int episodes = 0;
      String character = '';
      for (final r in roles) {
        final rm = (r as Map?)?.cast<String, dynamic>() ?? const {};
        episodes += (rm['episode_count'] as num?)?.toInt() ?? 0;
        if (character.isEmpty) {
          final c = (rm['character'] as String?) ?? '';
          if (c.isNotEmpty) character = c;
        }
      }
      return {
        'id': pid,
        'name': name,
        'profile_path': profilePath,
        'character': character,
        'episodes': episodes,
      };
    }).toList();

    // Sort by episodes desc and take top 10
    list.sort((a, b) => (b['episodes'] as int).compareTo(a['episodes'] as int));
    if (list.length > 10) list = list.sublist(0, 10);
    return list;
  }

  /// Movie cast (top 10 by order) with character names when available.
  Future<List<Map<String, dynamic>>> fetchMovieCast(int movieId) async {
    final uri = Uri.parse('$_base/movie/$movieId/credits').replace(
      queryParameters: {
        'api_key': _key,
        'language': 'en-US',
      },
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return const <Map<String, dynamic>>[];
    final m = (json.decode(res.body) as Map).cast<String, dynamic>();
    final cast = (m['cast'] as List?) ?? const [];

    List<Map<String, dynamic>> list = cast.map<Map<String, dynamic>>((e) {
      final mm = (e as Map?)?.cast<String, dynamic>() ?? const {};
      final pid = (mm['id'] as num?)?.toInt() ?? 0;
      final name = (mm['name'] as String?) ?? '';
      final profilePath = (mm['profile_path'] as String?) ?? '';
      final character = (mm['character'] as String?) ?? '';
      final order = (mm['order'] as num?)?.toInt() ?? 9999;
      return {
        'id': pid,
        'name': name,
        'profile_path': profilePath,
        'character': character,
        'order': order,
      };
    }).toList();

    list.sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
    if (list.length > 10) list = list.sublist(0, 10);
    return list;
  }

  // ---------------- PERSON DETAILS & CREDITS ----------------

  /// Basic person details (name, profile path, biography snippet).
  Future<({String name, String profilePath, String biography})> fetchPerson(
      int personId) async {
    final uri = Uri.parse('$_base/person/$personId')
        .replace(queryParameters: {'api_key': _key, 'language': 'en-US'});
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      return (name: 'Unknown', profilePath: '', biography: '');
    }
    final m = (json.decode(res.body) as Map).cast<String, dynamic>();
    return (
      name: (m['name'] as String?) ?? 'Unknown',
      profilePath: (m['profile_path'] as String?) ?? '',
      biography: (m['biography'] as String?) ?? '',
    );
  }

  /// Combined credits (movies + TV) for a person. Each map contains:
  /// id, media_type (movie|tv), title, character, poster_path, year, vote.
  Future<List<Map<String, dynamic>>> fetchPersonCombinedCredits(
      int personId) async {
    final uri = Uri.parse('$_base/person/$personId/combined_credits')
        .replace(queryParameters: {'api_key': _key, 'language': 'en-US'});
    final res = await http.get(uri);
    if (res.statusCode != 200) return const [];
    final m = (json.decode(res.body) as Map).cast<String, dynamic>();
    final cast = (m['cast'] as List?) ?? const [];
    final list = cast.map<Map<String, dynamic>>((e) {
      final mm = (e as Map?)?.cast<String, dynamic>() ?? const {};
      final mediaType = (mm['media_type'] as String?) ?? '';
      final id = (mm['id'] as num?)?.toInt() ?? 0;
      final title = (mediaType == 'movie')
          ? (mm['title'] as String?) ?? (mm['original_title'] as String?) ?? ''
          : (mm['name'] as String?) ?? (mm['original_name'] as String?) ?? '';
      final role = (mm['character'] as String?) ?? '';
      final poster = (mm['poster_path'] as String?) ?? '';
      final date = (mediaType == 'movie')
          ? (mm['release_date'] as String?) ?? ''
          : (mm['first_air_date'] as String?) ?? '';
      final year = date.length >= 4 ? date.substring(0, 4) : '';
      final vote = (mm['vote_average'] as num?)?.toDouble() ?? 0.0;
      return {
        'id': id,
        'media_type': mediaType,
        'title': title,
        'character': role,
        'poster_path': poster,
        'year': year,
        'vote': vote,
      };
    }).toList();
    // Sort credits by year desc then vote desc.
    list.sort((a, b) {
      final ya = int.tryParse((a['year'] as String?) ?? '') ?? 0;
      final yb = int.tryParse((b['year'] as String?) ?? '') ?? 0;
      final cmpYear = yb.compareTo(ya);
      if (cmpYear != 0) return cmpYear;
      return (b['vote'] as double).compareTo(a['vote'] as double);
    });
    return list;
  }
}
