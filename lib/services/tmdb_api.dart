import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/show_models.dart';

class TmdbApi {
  TmdbApi(this.apiKey, {this.region = "SE"});
  final String apiKey;
  final String region;

  Future<List<dynamic>> searchShows(String query) async {
    final url =
        "https://api.themoviedb.org/3/search/tv?api_key=$apiKey&query=${Uri.encodeComponent(query)}";
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body);
    return (data["results"] as List<dynamic>? ?? [])
        .where((r) => r["name"] != null)
        .toList();
  }

  Future<Map<String, dynamic>?> getShowDetail(int showId) async {
    final url =
        "https://api.themoviedb.org/3/tv/$showId?api_key=$apiKey&append_to_response=watch/providers";
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) return null;
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<List<Season>> buildSeasonsWithEpisodeTitles(
      int tvId, List<dynamic> baseSeasons) async {
    final futures = baseSeasons.map((s) async {
      final snum = s["season_number"] ?? 0;
      final sUrl =
          "https://api.themoviedb.org/3/tv/$tvId/season/$snum?api_key=$apiKey";
      final sResp = await http.get(Uri.parse(sUrl));

      List<Episode> eps = [];
      if (sResp.statusCode == 200) {
        final sData = jsonDecode(sResp.body);
        final epList = sData["episodes"] as List<dynamic>? ?? [];
        eps = epList
            .map((e) => Episode(
                  number: e["episode_number"] ?? 0,
                  title: (e["name"] ?? "").toString().isNotEmpty
                      ? e["name"]
                      : "Episode ${e["episode_number"] ?? ''}",
                ))
            .toList();
      } else {
        final fallback = s["episode_count"] ?? 0;
        eps = List.generate(
            fallback, (i) => Episode(number: i + 1, title: "Episode ${i + 1}"));
      }
      return Season(number: snum, episodes: eps);
    }).toList();

    final built = await Future.wait(futures);
    built.sort((a, b) => a.number.compareTo(b.number));
    return built;
  }

  String? providerLogoFromDetail(Map<String, dynamic> detail) {
    final providers = detail["watch/providers"]?["results"]?[region];
    if (providers != null &&
        providers["flatrate"] != null &&
        providers["flatrate"].isNotEmpty) {
      return "https://image.tmdb.org/t/p/w45${providers["flatrate"][0]["logo_path"]}";
    }
    return null;
  }

  String? posterUrlSmallFromDetail(Map<String, dynamic> detail) =>
      detail["poster_path"] != null
          ? "https://image.tmdb.org/t/p/w154${detail["poster_path"]}"
          : null;

  String? posterUrlLargeFromDetail(Map<String, dynamic> detail) =>
      detail["poster_path"] != null
          ? "https://image.tmdb.org/t/p/w342${detail["poster_path"]}"
          : null;
}
