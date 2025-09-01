import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'storage.dart'; // Use THIS Show everywhere (UI + storage)

/// Debounced TMDB search that maps results into your storage.Show
/// to avoid "two different Show" type errors.
///
/// Class name is **ShowsSearchController** to match home_page.dart.
class ShowsSearchController extends ChangeNotifier {
  ShowsSearchController();

  static const _apiKey = '6f8c0bbf88560ad26d47fcfa5f12cdc4';
  static const _base = 'https://api.themoviedb.org/3';

  /// Public state
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

  /// Hook this to TextField.onChanged and onSubmitted
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
      final uri = Uri.parse('$_base/search/tv').replace(queryParameters: {
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

      // Map TMDB result → your Storage.Show (fill ALL required named params)
      results = list.map<Show>((m) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final id = (m['id'] as num?)?.toInt() ?? 0;
        final title =
            (m['name'] ?? m['original_name'] ?? m['title'] ?? '').toString();
        final posterPath = (m['poster_path'] as String?) ?? '';
        final firstAir = (m['first_air_date'] as String?) ?? '';
        final backdropPath = (m['backdrop_path'] as String?) ?? '';
        final vote = (m['vote_average'] as num?)?.toDouble() ?? 0.0;

        return Show(
          id: id,
          title: title,
          posterUrl: posterPath.isNotEmpty
              ? 'https://image.tmdb.org/t/p/w342$posterPath'
              : '',
          firstAirDate: firstAir,

          // Required-by-your-model fields (safe defaults for search cards)
          overview: '',
          backdropUrl: backdropPath.isNotEmpty
              ? 'https://image.tmdb.org/t/p/w780$backdropPath'
              : '',
          rating: vote,
          genres: const <String>[],
          providers: const <String>[], // your model wants List<String>
          seasons: const <Season>[],
          addedAt: now,
          updatedAt: now,
        );
      }).toList(growable: false);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('search error: $e');
      }
      results = const [];
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  /// Ensure we have a show in storage before we mutate it elsewhere.
  /// If already exists, return id. Otherwise, add the lite show so pills/actions work.
  Future<int> ensureDetailInStorage(AppStorage storage, Show lite) async {
    if (storage.exists(lite.id)) return lite.id;
    storage.ensureShow(lite); // << correct API from your storage.dart
    return lite.id;
    // (Your details page can later replace it with a fully-detailed Show if needed.)
  }
}
