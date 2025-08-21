import 'package:flutter/material.dart';
import '../models/show_models.dart';
import '../widgets/completed_poster.dart';

class AllCompletedPage extends StatelessWidget {
  final List<Show> completedShows;
  final String apiKey;
  final String region;
  final List<Show> trackedShows;
  final VoidCallback onTrackedShowsChanged;

  const AllCompletedPage({
    super.key,
    required this.completedShows,
    required this.apiKey,
    required this.region,
    required this.trackedShows,
    required this.onTrackedShowsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("All Completed Shows")),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: completedShows.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2 / 3,
        ),
        itemBuilder: (context, i) {
          final show = completedShows[i];
          return CompletedPoster(
            show: show,
            apiKey: apiKey,
            region: region,
            trackedShows: trackedShows,
            onTrackedShowsChanged: onTrackedShowsChanged,
          );
        },
      ),
    );
  }
}
