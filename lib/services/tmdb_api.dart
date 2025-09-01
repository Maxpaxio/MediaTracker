import 'dart:convert';
import 'package:http/http.dart' as http;

import 'storage.dart'; // storage Show/Season

class TmdbApi {
  static const _base = 'https://api.themoviedb.org/3';
  static const _img = 'https://image.tmdb.org/t/p';
  static const _key = '6f8c0bbf88560ad26d47fcfa5f12cdc4';

  // ---------------- WATCH PROVIDERS (STRICT REGION) ----------------

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

    String _string(dynamic v) => (v ?? '').toString();
    double _double(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    int _int(dynamic v) => (v is num) ? v.toInt() : 0;

    final title = _string(m['name'] ?? m['original_name'] ?? m['title']);
    final overview = _string(m['overview']);
    final posterPath = _string(m['poster_path']);
    final backdropPath = _string(m['backdrop_path']);
    final firstAir = _string(m['first_air_date']);
    final lastAirStr = _string(m['last_air_date']);
    final lastAir = lastAirStr.isEmpty ? null : lastAirStr;
    final vote = _double(m['vote_average']);

    final genres = ((m['genres'] as List?) ?? const [])
        .map((e) => (e as Map?)?['name'])
        .whereType<String>()
        .toList(growable: false);

    final seasons = ((m['seasons'] as List?) ?? const [])
        .map((e) =>
            (e as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{})
        .where((e) => _int(e['season_number']) >= 1)
        .map((e) => Season(
              seasonNumber: _int(e['season_number']),
              name: _string(e['name']), // (en-US gives "Season 1" etc.)
              episodeCount: _int(e['episode_count']),
              watched: 0,
            ))
        .toList(growable: false);

    return Show(
      id: _int(m['id']),
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
}
