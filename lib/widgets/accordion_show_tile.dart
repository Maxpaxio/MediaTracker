import 'package:flutter/material.dart';
import '../services/storage.dart';
import '../pages/show_detail_page.dart';

class AccordionShowTile extends StatelessWidget {
  const AccordionShowTile({super.key, required this.show, this.trailing});
  final Show show;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(
          context,
          ShowDetailPage.route,
          arguments: ShowDetailArgs(showId: show.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  show.posterUrl,
                  height: 80,
                  width: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    width: 56,
                    color: const Color(0xFF2C2C32),
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: show.progress),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Watched ${show.watchedEpisodes} / ${show.totalEpisodes}  (${(show.progress * 100).round()}%)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
