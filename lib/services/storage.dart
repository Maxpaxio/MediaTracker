import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/show_models.dart';

class Storage {
  static const _key = 'trackedShows';

  static Future<List<Show>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((m) => Show.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<Show> shows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(shows.map((s) => s.toJson()).toList()),
    );
  }
}
