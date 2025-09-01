import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.onSeeAll});
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (onSeeAll != null)
            InkWell(
              onTap: onSeeAll,
              child: Row(
                children: const [
                  Text('See all'),
                  SizedBox(width: 6),
                  Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
