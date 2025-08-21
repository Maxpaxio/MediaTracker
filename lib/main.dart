import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/show_models.dart';
import 'pages/home_page.dart';
import 'theme.dart';
import 'dart:convert';

void main() {
  runApp(const TvTrackerApp());
}

class TvTrackerApp extends StatefulWidget {
  const TvTrackerApp({super.key});
  @override
  State<TvTrackerApp> createState() => _TvTrackerAppState();
}

class _TvTrackerAppState extends State<TvTrackerApp> {
  final List<Show> trackedShows = [];
  int? expandedShowId;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadTrackedShows();
  }

  Future<void> _loadTrackedShows() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('trackedShows');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List<dynamic>)
            .map((m) => Show.fromJson(m as Map<String, dynamic>))
            .toList();
        trackedShows
          ..clear()
          ..addAll(list);
      } catch (_) {}
    }
    setState(() => _loaded = true);
  }

  Future<void> _saveTrackedShows() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = trackedShows.map((s) => s.toJson()).toList();
    await prefs.setString('trackedShows', jsonEncode(jsonList));
  }

  void _onTrackedShowsChanged() {
    setState(() {});
    _saveTrackedShows();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TV Tracker',
      theme: lightTheme,
      darkTheme: darkTheme,        // dark gray theme
      themeMode: ThemeMode.dark,   // force dark mode (change to system if you prefer)
      home: _loaded
          ? HomePage(
              trackedShows: trackedShows,
              expandedShowId: expandedShowId,
              onExpandedChanged: (id) {
                setState(() {
                  expandedShowId = (expandedShowId == id) ? null : id;
                });
                _saveTrackedShows();
              },
              onTrackedShowsChanged: _onTrackedShowsChanged,
            )
          : const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
    );
  }
}
