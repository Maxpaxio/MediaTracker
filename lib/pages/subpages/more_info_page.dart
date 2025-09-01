import 'package:flutter/material.dart';
import '../../services/storage.dart';

class MoreInfoPage extends StatelessWidget {
  static const route = '/more-info';
  const MoreInfoPage({super.key, required this.showId});

  final int showId;

  @override
  Widget build(BuildContext context) {
    final s = StorageScope.of(context).tryGet(showId);

    if (s == null) {
      return const Scaffold(
        body: Center(child: Text('Show not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('More info')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _Section(
            title: 'Rating',
            child: Row(
              children: [
                const Icon(Icons.star, color: Color(0xFFFFD166)),
                const SizedBox(width: 6),
                Text('${s.rating.toStringAsFixed(1) ?? '—'} / 10'),
              ],
            ),
          ),
          _Section(
            title: 'Genres',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: s.genres.map((g) => Chip(label: Text(g))).toList(),
            ),
          ),
          const _Section(title: 'Episode Runtime', child: Text('7 min')),
          _Section(
            title: 'Air Dates',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('First air date: ${s.firstAirDate ?? '—'}'),
                Text('Last air date: ${s.lastAirDate ?? '—'}'),
              ],
            ),
          ),
          const _Section(
            title: 'Creator(s)',
            child: Wrap(spacing: 8, children: [Chip(label: Text('Joe Brumm'))]),
          ),
          const _Section(
            title: 'Production Companies',
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _CompanyBox(name: 'Ludo Studio'),
                _CompanyBox(name: 'Australian Broadcasting C…'),
                _CompanyBox(name: 'Screen Australia'),
                _CompanyBox(name: 'Screen Queensland'),
                _CompanyBox(name: 'CBeebies'),
                _CompanyBox(name: 'BBC Worldwide'),
              ],
            ),
          ),
          const _Section(
            title: 'Top Cast',
            child: Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                _CastBubble(
                  name: 'Dave McCormack',
                  role: 'Bandit Heeler (voice)',
                ),
                _CastBubble(
                  name: 'Melanie Zanetti',
                  role: 'Chilli Heeler (voice)',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: style),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _CompanyBox extends StatelessWidget {
  const _CompanyBox({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 48,
          width: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C32),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.domain),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 120,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _CastBubble extends StatelessWidget {
  const _CastBubble({required this.name, required this.role});
  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        children: [
          const CircleAvatar(radius: 26, child: Icon(Icons.person)),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            role,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
