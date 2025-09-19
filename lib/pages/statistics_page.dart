import 'package:flutter/material.dart';
import '../services/storage.dart';
// import '../services/tmdb_api.dart';
import '../services/stats_controller.dart';
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
  // No longer compute on-demand; we use StatsScope snapshot.

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
      // No-op here; StatsController runs in background.
    }
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
          Builder(builder: (context) {
            final stats = StatsScope.of(context);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: stats.updating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const SizedBox(width: 18, height: 18),
            );
          }),
          IconButton(
            tooltip: 'Refresh statistics',
            onPressed: () async {
              final stats = StatsScope.of(context);
              await stats.refreshNow();
            },
            icon: const Icon(Icons.refresh),
          ),
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
      body: Builder(builder: (context) {
        final stats = StatsScope.of(context);
        final data = stats.snapshot;
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
                          // Make the big number adapt to narrow screens
                          Expanded(
                            child: Text(
                              _formatByBreakdown(data.totalMinutes),
                              maxLines: 2,
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                              ),
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
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      _formatByBreakdown(data.movieMinutes),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.live_tv),
                  title: const Text('TV'),
                  subtitle: Text('${data.watchedEpisodes} episodes watched'),
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      _formatByBreakdown(data.tvMinutes),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ),
            ],
          );
      }),
    );
  }
}
