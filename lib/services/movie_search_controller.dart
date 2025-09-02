import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'storage.dart';

class MoviesSearchController extends ChangeNotifier {
  MoviesSearchController();

  static const _apiKey = '6f8c0bbf88560ad26d47fcfa5f12cdc4';
  static const _base = 'https://api.themoviedb.org/3';

  final TextEditingController text = TextEditingController();
  bool searching = false;
  List<Show> results = const [];

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
      final uri = Uri.parse('$_base/search/movie').replace(queryParameters: {
        'api_key': _apiKey,
        'language': 'en-US',
        'query': query,
        'page': '1',
        'include_adult': 'false',
      });

      final res = await http.get(uri);
      if (res.statusCode != 200) {
        results = const [];
        searching = false;
        notifyListeners();
        return;
      }

      final map = (json.decode(res.body) as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final list =
          (map['results'] as List? ?? const []).cast<Map<String, dynamic>>();

      results = list.map<Show>((m) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final id = (m['id'] as num?)?.toInt() ?? 0;
        final title = (m['title'] ?? m['original_title'] ?? '').toString();
        final posterPath = (m['poster_path'] as String?) ?? '';
        final releaseDate = (m['release_date'] as String?) ?? '';
        final backdropPath = (m['backdrop_path'] as String?) ?? '';
        final vote = (m['vote_average'] as num?)?.toDouble() ?? 0.0;

        return Show(
          id: id,
          title: title,
          posterUrl:
              posterPath.isNotEmpty ? 'https://image.tmdb.org/t/p/w342$posterPath' : '',
          firstAirDate: releaseDate,
          overview: (m['overview'] as String?) ?? '',
          backdropUrl:
              backdropPath.isNotEmpty ? 'https://image.tmdb.org/t/p/w780$backdropPath' : '',
          rating: vote,
          genres: const <String>[],
          providers: const <String>[],
          seasons: const <Season>[],
          mediaType: MediaType.movie,
          addedAt: now,
          updatedAt: now,
        );
      }).toList(growable: false);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('movie search error: $e');
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
