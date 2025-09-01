import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/storage.dart';
import '../../services/tmdb_api.dart';

class MoreInfoPage extends StatefulWidget {
  static const route = '/more-info';
  const MoreInfoPage({super.key, required this.showId});

  final int showId;

  @override
  State<MoreInfoPage> createState() => _MoreInfoPageState();
}

class _MoreInfoPageState extends State<MoreInfoPage> {
  final _api = TmdbApi();

  bool _loading = true;
  Show? _show;
  double _rating = 0;
  List<String> _genres = const [];
  List<int> _runtimes = const [];
  String _firstAir = '';
  List<String> _creators = const [];
  List<({String name, String logoPath})> _companies = const [];
  List<Map<String, dynamic>> _cast = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MoreInfoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showId != widget.showId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final storage = StorageScope.of(context);
    final s = storage.tryGet(widget.showId);

    final extras = await _api.fetchShowExtras(widget.showId);
    final cast = await _api.fetchAggregateCast(widget.showId);

    if (!mounted) return;
    setState(() {
      _show = s;
      _rating = extras.rating;
      _genres = extras.genres;
      _runtimes = extras.episodeRunTimes;
      _firstAir = extras.firstAirDate;
      _creators = extras.creators;
      _companies = extras.companies;
      _cast = cast;
      _loading = false;
    });
  }

  String _avgRuntimeText() {
    if (_runtimes.isEmpty) return '—';
    final avg = _runtimes.reduce((a, b) => a + b) / _runtimes.length;
    return '${avg.round()} min';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_show == null) {
      return const Scaffold(body: Center(child: Text('Show not found')));
    }

    final s = _show!;

    return Scaffold(
      appBar: AppBar(title: Text('${s.title} – More info')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _Section(
            title: 'Rating',
            child: Row(
              children: [
                const Icon(Icons.star, color: Color(0xFFFFD166)),
                const SizedBox(width: 6),
                Text('${_rating.toStringAsFixed(1)} / 10'),
              ],
            ),
          ),
          _Section(
            title: 'Genres',
            child: _genres.isEmpty
                ? const Text('—')
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _genres.map((g) => Chip(label: Text(g))).toList(),
                  ),
          ),
          _Section(title: 'Average Episode Runtime', child: Text(_avgRuntimeText())),
          _Section(
            title: 'Air Dates',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('First air date: ${_firstAir.isNotEmpty ? _firstAir : '—'}'),
                Text('Last air date: ${s.lastAirDate ?? '—'}'),
              ],
            ),
          ),
          _Section(
            title: 'Creator(s)',
            child: _creators.isEmpty
                ? const Text('—')
                : Wrap(
                    spacing: 8,
                    children: _creators.map((c) => Chip(label: Text(c))).toList(),
                  ),
          ),
          _Section(
            title: 'Production Companies',
            child: _CompanyWrap(companies: _companies.take(3).toList()),
          ),
          _Section(
            title: 'Top Cast',
            child: _CastWrap(cast: _cast),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final url = Uri.parse('https://www.themoviedb.org/tv/${s.id}/cast');
                try {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } catch (_) {}
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('More on TMDb'),
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
  const _CompanyBox({required this.name, required this.logoPath});
  final String name;
  final String logoPath;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 48,
            width: 64,
            color: const Color(0xFF2C2C32),
            child: logoPath.isNotEmpty
                ? Image.network(
                    'https://image.tmdb.org/t/p/w154$logoPath',
                    fit: BoxFit.contain,
                  )
                : const Icon(Icons.domain),
          ),
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
  const _CastBubble({
    required this.name,
    required this.role,
    required this.episodes,
    required this.profilePath,
  });
  final String name;
  final String role;
  final int episodes;
  final String profilePath;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF2C2C32),
            backgroundImage: profilePath.isNotEmpty
                ? NetworkImage('https://image.tmdb.org/t/p/w185$profilePath')
                : null,
            child: profilePath.isEmpty ? const Icon(Icons.person) : null,
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            role,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            '$episodes eps',
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CompanyWrap extends StatelessWidget {
  const _CompanyWrap({required this.companies});
  final List<({String name, String logoPath})> companies;

  @override
  Widget build(BuildContext context) {
    if (companies.isEmpty) return const Text('—');
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: companies
          .map((c) => _CompanyBox(name: c.name, logoPath: c.logoPath))
          .toList(),
    );
  }
}

class _CastWrap extends StatelessWidget {
  const _CastWrap({required this.cast});
  final List<Map<String, dynamic>> cast;

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty) return const Text('—');
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: cast
          .map((m) => _CastBubble(
                name: (m['name'] as String?) ?? '',
                role: (m['character'] as String?) ?? '',
                episodes: (m['episodes'] as int?) ?? 0,
                profilePath: (m['profile_path'] as String?) ?? '',
              ))
          .toList(),
    );
  }
}
