import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'storage.dart';

enum MultiKind { tv, movie, person }

class MultiSearchItem {
  final MultiKind kind;
  final Show? show; // for tv/movie
  final int? personId; // for person
  final String? personName;
  final String? personProfileUrl;
  final List<String>? knownForTitles;

  const MultiSearchItem.tv(this.show)
      : kind = MultiKind.tv,
        personId = null,
        personName = null,
        personProfileUrl = null,
        knownForTitles = null;
  const MultiSearchItem.movie(this.show)
      : kind = MultiKind.movie,
        personId = null,
        personName = null,
        personProfileUrl = null,
        knownForTitles = null;
  const MultiSearchItem.person({
    required this.personId,
    required this.personName,
    required this.personProfileUrl,
    required this.knownForTitles,
  })  : kind = MultiKind.person,
        show = null;
}

class MultiSearchController extends ChangeNotifier {
  static const _apiKey = '6f8c0bbf88560ad26d47fcfa5f12cdc4';
  static const _base = 'https://api.themoviedb.org/3';

  final TextEditingController text = TextEditingController();
  bool searching = false;
  List<MultiSearchItem> results = const [];

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    text.dispose();
    super.dispose();
  }

  void onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _performSearch(q);
    });
  }

  void clear() {
    text.clear();
    results = const [];
    searching = false;
    notifyListeners();
  }

  Future<void> _performSearch(String q) async {
    final query = q.trim();
    if (query.isEmpty) {
      results = const [];
      searching = false;
      notifyListeners();
      return;
    }

    searching = true;
    notifyListeners();

    try {
      final uri = Uri.parse('$_base/search/multi').replace(queryParameters: {
        'api_key': _apiKey,
        'language': 'en-US',
        'query': query,
        'page': '1',
        'include_adult': 'false',
      });
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        results = const [];
        return;
      }
      final root = (json.decode(res.body) as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final list = (root['results'] as List? ?? const [])
          .cast<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();

      const img = 'https://image.tmdb.org/t/p';
      final now = DateTime.now().millisecondsSinceEpoch;

      final out = <MultiSearchItem>[];
      for (final m in list) {
        final mediaType = (m['media_type'] as String?) ?? '';
        if (mediaType == 'tv') {
          final id = (m['id'] as num?)?.toInt() ?? 0;
          final title = (m['name'] ?? m['original_name'] ?? '').toString();
          final posterPath = (m['poster_path'] as String?) ?? '';
          final backdropPath = (m['backdrop_path'] as String?) ?? '';
          final firstAir = (m['first_air_date'] as String?) ?? '';
          final vote = (m['vote_average'] as num?)?.toDouble() ?? 0.0;
          final show = Show(
            id: id,
            title: title,
            overview: '',
            posterUrl: posterPath.isNotEmpty ? '$img/w342$posterPath' : '',
            backdropUrl: backdropPath.isNotEmpty ? '$img/w780$backdropPath' : '',
            firstAirDate: firstAir,
            lastAirDate: null,
            rating: vote,
            genres: const <String>[],
            providers: const <String>[],
            seasons: const <Season>[],
            mediaType: MediaType.tv,
            addedAt: now,
            updatedAt: now,
          );
          out.add(MultiSearchItem.tv(show));
        } else if (mediaType == 'movie') {
          final id = (m['id'] as num?)?.toInt() ?? 0;
          final title = (m['title'] ?? m['original_title'] ?? '').toString();
          final posterPath = (m['poster_path'] as String?) ?? '';
          final backdropPath = (m['backdrop_path'] as String?) ?? '';
          final release = (m['release_date'] as String?) ?? '';
          final vote = (m['vote_average'] as num?)?.toDouble() ?? 0.0;
          final show = Show(
            id: id,
            title: title,
            overview: '',
            posterUrl: posterPath.isNotEmpty ? '$img/w342$posterPath' : '',
            backdropUrl: backdropPath.isNotEmpty ? '$img/w780$backdropPath' : '',
            firstAirDate: release,
            lastAirDate: null,
            rating: vote,
            genres: const <String>[],
            providers: const <String>[],
            seasons: const <Season>[],
            mediaType: MediaType.movie,
            addedAt: now,
            updatedAt: now,
          );
          out.add(MultiSearchItem.movie(show));
        } else if (mediaType == 'person') {
          final id = (m['id'] as num?)?.toInt() ?? 0;
          final name = (m['name'] as String?) ?? '';
          final profilePath = (m['profile_path'] as String?) ?? '';
          final knownFor = (m['known_for'] as List? ?? const [])
              .cast<Map?>()
              .map((e) => (e ?? const {}) as Map)
              .map((mm) => (mm['title'] ?? mm['name'] ?? '').toString())
              .where((t) => t.trim().isNotEmpty)
              .cast<String>()
              .toList();
          out.add(MultiSearchItem.person(
            personId: id,
            personName: name,
            personProfileUrl:
                profilePath.isNotEmpty ? '$img/w185$profilePath' : null,
            knownForTitles: knownFor,
          ));
        }
      }

      results = out;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('multi search error: $e');
      }
      results = const [];
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  Future<int> ensureDetailInStorage(AppStorage storage, Show lite) async {
    if (storage.exists(lite.id)) return lite.id;
    storage.ensureShow(lite);
    return lite.id;
  }
}
