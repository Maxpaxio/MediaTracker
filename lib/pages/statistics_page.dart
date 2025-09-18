import 'package:flutter/material.dart';
import '../services/storage.dart';
import '../services/tmdb_api.dart';
import '../widgets/brand_logo.dart';
import 'home_page.dart';
import 'films_page.dart';
import 'sync_connect_page.dart';
import 'settings_page.dart';
import 'search_results_page.dart';

enum TimeBreakdown {
  seconds,
  minutes,
  hoursMinutes,
  daysHoursMinutes,
  monthsDaysHoursMinutes,
  yearsMonthsDaysHoursMinutes,
}

class StatisticsPage extends StatefulWidget {
  static const route = '/stats';
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  // Fallbacks when runtime is missing from API.
  static const int fallbackMovieMinutes = 120; // 2h per completed movie
  static const int fallbackEpisodeMinutes = 45; // 45m per watched TV episode

  static const _prefKey = 'stats.breakdown';
  static const _prefMigratedKey = 'stats.breakdown.migrated';
  TimeBreakdown _breakdown = TimeBreakdown.hoursMinutes;
  bool _loadedPref = false;
  Future<({
    int totalMinutes,
    int movieMinutes,
    int tvMinutes,
    int completedMovies,
    int watchedEpisodes,
    bool usedFallback
  })>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedPref) {
      final storage = StorageScope.of(context);
      final idx = storage.readInt(_prefKey);
      // Migrate from legacy 4-option enum indices to new 6-option enum.
      // Old indices mapping:
      // 0: hoursMinutes -> new 2
      // 1: daysHoursMinutes -> new 3
      // 2: monthsDaysHoursMinutes -> new 4
      // 3: yearsMonthsDaysHoursMinutesSeconds -> new yearsMonthsDaysHoursMinutes (5)
      final migrated = storage.readBool(_prefMigratedKey) ?? false;
      int? useIdx = idx;
      if (!migrated && idx != null && idx >= 0 && idx <= 3) {
        switch (idx) {
          case 0:
            useIdx = TimeBreakdown.hoursMinutes.index; // 2
            break;
          case 1:
            useIdx = TimeBreakdown.daysHoursMinutes.index; // 3
            break;
          case 2:
            useIdx = TimeBreakdown.monthsDaysHoursMinutes.index; // 4
            break;
          case 3:
            useIdx = TimeBreakdown.yearsMonthsDaysHoursMinutes.index; // 5
            break;
        }
        // Persist migrated value.
        storage.writeInt(_prefKey, useIdx!);
        storage.writeBool(_prefMigratedKey, true);
      }
      if (useIdx != null && useIdx >= 0 && useIdx < TimeBreakdown.values.length) {
        _breakdown = TimeBreakdown.values[useIdx];
      }
      _loadedPref = true;
      _future ??= _computeStats(context);
    }
  }

  Future<({
    int totalMinutes,
    int movieMinutes,
    int tvMinutes,
    int completedMovies,
    int watchedEpisodes,
    bool usedFallback
  })> _computeStats(BuildContext context) async {
    final storage = StorageScope.of(context);
    final api = TmdbApi();

    // Movies: use TMDb movie extras runtime per completed movie
    final movies = storage.completed.where((s) => s.mediaType == MediaType.movie);
    int movieMinutes = 0;
    int completedMovies = 0;
    bool usedFallback = false;
    for (final m in movies) {
      completedMovies++;
      try {
        final extras = await api.fetchMovieExtras(m.id);
        final rt = extras.runtime;
        if (rt > 0) {
          movieMinutes += rt;
        } else {
          movieMinutes += fallbackMovieMinutes;
          usedFallback = true;
        }
      } catch (_) {
        movieMinutes += fallbackMovieMinutes;
        usedFallback = true;
      }
    }

    // TV: sum per-episode runtimes for watched episodes only.
    int tvMinutes = 0;
    int watchedEpisodes = 0;
    final tvShows = storage.all.where((s) => s.mediaType == MediaType.tv);
    for (final show in tvShows) {
      for (final season in show.seasons) {
        final w = season.watched.clamp(0, season.episodeCount);
        if (w <= 0) continue;
        watchedEpisodes += w;
        try {
          final rts = await api.fetchSeasonEpisodeRuntimes(show.id, season.seasonNumber);
          int sum = 0;
          for (var i = 0; i < w; i++) {
            final int rt = (i < rts.length ? (rts[i] as int) : 0);
            if (rt > 0) {
              sum += rt;
            } else {
              sum += fallbackEpisodeMinutes;
              usedFallback = true;
            }
          }
          tvMinutes += sum;
        } catch (_) {
          tvMinutes += w * fallbackEpisodeMinutes;
          usedFallback = true;
        }
      }
    }

    return (
      totalMinutes: movieMinutes + tvMinutes,
      movieMinutes: movieMinutes,
      tvMinutes: tvMinutes,
      completedMovies: completedMovies,
      watchedEpisodes: watchedEpisodes,
      usedFallback: usedFallback,
    );
  }

  String _formatByBreakdown(int minutes) {
    // Convert minutes to total seconds for precise breakdowns including seconds.
    final totalSeconds = minutes * 60;
    // Approximations for months/years.
    const int secondsPerMinute = 60;
    const int secondsPerHour = 60 * secondsPerMinute;
    const int secondsPerDay = 24 * secondsPerHour;
    const int secondsPerMonth = 30 * secondsPerDay; // ~30-day month
    const int secondsPerYear = 365 * secondsPerDay; // 365-day year

    int rem = totalSeconds;
    String joinNonZero(List<(int, String)> parts) {
      final buf = <String>[];
      for (final (v, label) in parts) {
        if (v > 0) buf.add('$v $label');
      }
      return buf.isEmpty ? '0 minutes' : buf.join(', ');
    }

    switch (_breakdown) {
      case TimeBreakdown.seconds:
        final s = rem; // already seconds
        return '${s}s';
      case TimeBreakdown.minutes:
        final m = rem ~/ secondsPerMinute;
        return '${m}m';
      case TimeBreakdown.hoursMinutes:
        final h = rem ~/ secondsPerHour;
        rem %= secondsPerHour;
        final m = rem ~/ secondsPerMinute;
        if (h == 0) return '${m}m';
        if (m == 0) return '${h}h';
        return '${h}h ${m}m';
      case TimeBreakdown.daysHoursMinutes:
        final d = rem ~/ secondsPerDay; rem %= secondsPerDay;
        final h = rem ~/ secondsPerHour; rem %= secondsPerHour;
        final m = rem ~/ secondsPerMinute;
        return joinNonZero([
          (d, 'days'),
          (h, 'hours'),
          (m, 'minutes'),
        ]);
      case TimeBreakdown.monthsDaysHoursMinutes:
        final mo = rem ~/ secondsPerMonth; rem %= secondsPerMonth;
        final d = rem ~/ secondsPerDay; rem %= secondsPerDay;
        final h = rem ~/ secondsPerHour; rem %= secondsPerHour;
        final m = rem ~/ secondsPerMinute;
        return joinNonZero([
          (mo, 'months'),
          (d, 'days'),
          (h, 'hours'),
          (m, 'minutes'),
        ]);
      case TimeBreakdown.yearsMonthsDaysHoursMinutes:
        final y = rem ~/ secondsPerYear; rem %= secondsPerYear;
        final mo = rem ~/ secondsPerMonth; rem %= secondsPerMonth;
        final d = rem ~/ secondsPerDay; rem %= secondsPerDay;
        final h = rem ~/ secondsPerHour; rem %= secondsPerHour;
        final m = rem ~/ secondsPerMinute; rem %= secondsPerMinute;
        return joinNonZero([
          (y, 'years'),
          (mo, 'months'),
          (d, 'days'),
          (h, 'hours'),
          (m, 'minutes'),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = StorageScope.of(context);
    Future<void> setBreakdown(TimeBreakdown b) async {
      if (b == _breakdown) return;
      setState(() => _breakdown = b);
      await storage.writeInt(_prefKey, b.index);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        leadingWidth: 96,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.home),
              tooltip: 'Home',
              onPressed: () => Navigator.pushReplacementNamed(context, '/'),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<TimeBreakdown>(
            tooltip: 'Time format',
            initialValue: _breakdown,
            icon: const Icon(Icons.schedule),
            onSelected: setBreakdown,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: TimeBreakdown.seconds,
                child: Text('Seconds'),
              ),
              PopupMenuItem(
                value: TimeBreakdown.minutes,
                child: Text('Minutes'),
              ),
              PopupMenuItem(
                value: TimeBreakdown.hoursMinutes,
                child: Text('Hours, Minutes'),
              ),
              PopupMenuItem(
                value: TimeBreakdown.daysHoursMinutes,
                child: Text('Days, Hours, Minutes'),
              ),
              PopupMenuItem(
                value: TimeBreakdown.monthsDaysHoursMinutes,
                child: Text('Months, Days, Hours, Minutes'),
              ),
              PopupMenuItem(
                value: TimeBreakdown.yearsMonthsDaysHoursMinutes,
                child: Text('Years, Months, Days, Hours, Minutes'),
              ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    BrandLogo(height: 72),
                    SizedBox(height: 12),
                    Text(
                      'MediaTracker',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Search'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, SearchResultsPage.route);
                },
              ),
              ListTile(
                leading: const Icon(Icons.live_tv),
                title: const Text('TV'),
                onTap: () => Navigator.pushReplacementNamed(context, HomePage.route),
              ),
              ListTile(
                leading: const Icon(Icons.movie),
                title: const Text('Films'),
                onTap: () => Navigator.pushReplacementNamed(context, FilmsPage.route),
              ),
              ListTile(
                leading: const Icon(Icons.insights),
                title: const Text('Statistics'),
                onTap: () => Navigator.pop(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud),
                title: const Text('Cloud storage'),
                onTap: () => Navigator.pushNamed(context, SyncConnectPage.route),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () => Navigator.pushNamed(context, SettingsPage.route),
              ),
            ],
          ),
        ),
      ),
      body: FutureBuilder<({
        int totalMinutes,
        int movieMinutes,
        int tvMinutes,
        int completedMovies,
        int watchedEpisodes,
        bool usedFallback
      })>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData) {
            return const Center(child: Text('No data'));
          }
          final data = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total time watched',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatByBreakdown(data.totalMinutes),
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data.usedFallback
                            ? 'Includes fallbacks for missing runtimes (films ${fallbackMovieMinutes}m, TV ${fallbackEpisodeMinutes}m)'
                            : 'Using real runtimes from TMDb',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.movie),
                  title: const Text('Films'),
                  subtitle: Text('${data.completedMovies} completed'),
                  trailing: Text(_formatByBreakdown(data.movieMinutes)),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.live_tv),
                  title: const Text('TV'),
                  subtitle: Text('${data.watchedEpisodes} episodes watched'),
                  trailing: Text(_formatByBreakdown(data.tvMinutes)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
