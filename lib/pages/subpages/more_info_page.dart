import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/storage.dart';
import '../../services/tmdb_api.dart';
import '../show_detail_page.dart';
import '../../widgets/provider_corner_grid.dart';

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
  bool _didInitDeps = false;
  Show? _show;
  double _rating = 0;
  List<String> _genres = const [];
  // TV-only
  List<int> _runtimes = const [];
  String _firstAir = '';
  List<String> _creators = const [];
  // Movie-only
  int _runtimeMovie = 0;
  String _releaseDate = '';
  List<({String name, String logoPath})> _companies = const [];
  List<Map<String, dynamic>> _cast = const [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitDeps) {
      _didInitDeps = true;
      // Kick off loading after the first frame to ensure inherited widgets are available.
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
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
    MediaType mt = s?.mediaType ?? MediaType.tv;

    double rating = 0;
    List<String> genres = const [];
    List<({String name, String logoPath})> companies = const [];
    List<Map<String, dynamic>> cast = const [];
    List<int> tvRun = const [];
    String tvFirst = '';
    List<String> tvCreators = const [];
    int movieRt = 0;
    String movieRel = '';

    try {
      if (mt == MediaType.movie) {
        final extras = await _api.fetchMovieExtras(widget.showId);
        rating = extras.rating;
        genres = extras.genres;
        companies = extras.companies;
        movieRt = extras.runtime;
        movieRel = extras.releaseDate;
        cast = await _api.fetchMovieCast(widget.showId);
      } else {
        final extras = await _api.fetchShowExtras(widget.showId);
        rating = extras.rating;
        genres = extras.genres;
        companies = extras.companies;
        tvRun = extras.episodeRunTimes;
        tvFirst = extras.firstAirDate;
        tvCreators = extras.creators;
        cast = await _api.fetchAggregateCast(widget.showId);
      }
    } catch (_) {
      // swallow network errors
    }

    if (!mounted) return;
    setState(() {
      _show = s;
      _rating = rating;
      _genres = genres;
      _runtimes = tvRun;
      _firstAir = tvFirst;
      _creators = tvCreators;
      _companies = companies;
      _runtimeMovie = movieRt;
      _releaseDate = movieRel;
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

    final isMovie = s.mediaType == MediaType.movie;
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
          if (!isMovie)
            _Section(
                title: 'Average Episode Runtime',
                child: Text(_avgRuntimeText())),
          if (!isMovie)
            _Section(
              title: 'Air Dates',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'First air date: ${_firstAir.isNotEmpty ? _firstAir : '—'}'),
                  Text('Last air date: ${s.lastAirDate ?? '—'}'),
                ],
              ),
            ),
          if (isMovie)
            _Section(
              title: 'Runtime',
              child: Text(_runtimeMovie > 0 ? '$_runtimeMovie min' : '—'),
            ),
          if (isMovie)
            _Section(
              title: 'Release Date',
              child: Text(_releaseDate.isNotEmpty ? _releaseDate : '—'),
            ),
          if (!isMovie)
            _Section(
              title: 'Creator(s)',
              child: _creators.isEmpty
                  ? const Text('—')
                  : Wrap(
                      spacing: 8,
                      children:
                          _creators.map((c) => Chip(label: Text(c))).toList(),
                    ),
            ),
          _Section(
            title: 'Production Companies',
            child: _CompanyWrap(companies: _companies.take(3).toList()),
          ),
          _Section(
            title: 'Top Cast',
            child: _CastWrap(cast: _cast, isMovie: isMovie),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final url = isMovie
                    ? Uri.parse('https://www.themoviedb.org/movie/${s.id}')
                    : Uri.parse('https://www.themoviedb.org/tv/${s.id}/cast');
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
    required this.personId,
    required this.name,
    required this.role,
    required this.episodes,
    required this.profilePath,
  });
  final int personId;
  final String name;
  final String role;
  final int episodes;
  final String profilePath;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        PersonCreditsPage.route,
        arguments: personId,
      ),
      child: SizedBox(
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
            if (episodes > 0)
              Text(
                '$episodes eps',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
          ],
        ),
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
  const _CastWrap({required this.cast, required this.isMovie});
  final List<Map<String, dynamic>> cast;
  final bool isMovie;

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty) return const Text('—');
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: cast
          .map((m) => _CastBubble(
                personId: (m['id'] as int?) ?? 0,
                name: (m['name'] as String?) ?? '',
                role: (m['character'] as String?) ?? '',
                episodes: isMovie ? 0 : (m['episodes'] as int?) ?? 0,
                profilePath: (m['profile_path'] as String?) ?? '',
              ))
          .toList(),
    );
  }
}

// Person credits page
class PersonCreditsPage extends StatefulWidget {
  static const route = '/person-credits';
  const PersonCreditsPage({super.key, required this.personId});
  final int personId;

  @override
  State<PersonCreditsPage> createState() => _PersonCreditsPageState();
}

class _PersonCreditsPageState extends State<PersonCreditsPage> {
  final _api = TmdbApi();
  bool _loading = true;
  String _name = '';
  String _profile = '';
  String _bio = '';
  List<Map<String, dynamic>> _credits = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final person = await _api.fetchPerson(widget.personId);
    final credits = await _api.fetchPersonCombinedCredits(widget.personId);
    if (!mounted) return;
    setState(() {
      _name = person.name;
      _profile = person.profilePath;
      _bio = person.biography;
      _credits = credits;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final tvCredits = _credits
        .where((c) => (c['media_type'] as String?) == 'tv')
        .toList(growable: false);
    final movieCredits = _credits
        .where((c) => (c['media_type'] as String?) == 'movie')
        .toList(growable: false);

    Widget buildRow(String label, List<Map<String, dynamic>> items) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 235, // allow two text lines + metadata without overflow
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (ctx, i) {
                final c = items[i];
                final mediaType = (c['media_type'] as String?) ?? '';
                final poster = (c['poster_path'] as String?) ?? '';
                // TMDB combined credits sometimes have 'name' for TV and 'title' for movie
                final title =
                    (c['title'] as String?) ?? (c['name'] as String?) ?? '';
                final role = (c['character'] as String?) ?? '';
                final year = (c['year'] as String?) ?? '';
                final id = (c['id'] as int?) ?? 0;
                return InkWell(
                  onTap: () async {
                    if (id <= 0) return;
                    final storage = StorageScope.of(context);
                    final existing = storage.tryGet(id);
                    try {
                      if (mediaType == 'movie') {
                        if (existing == null ||
                            existing.mediaType != MediaType.movie) {
                          final detail = await _api.fetchMovieDetailStorage(id);
                          storage.ensureShow(detail);
                        }
                      } else if (mediaType == 'tv') {
                        if (existing == null ||
                            existing.mediaType != MediaType.tv) {
                          final detail = await _api.fetchShowDetailStorage(id);
                          storage.ensureShow(detail);
                        }
                      }
                    } catch (_) {}
                    if (!mounted) return;
                    Navigator.pushNamed(
                      context,
                      ShowDetailPage.route,
                      arguments: ShowDetailArgs(showId: id),
                    );
                  },
                  child: SizedBox(
                    width: 116,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AspectRatio(
                                aspectRatio: 2 / 3,
                                child: poster.isNotEmpty
                                    ? Image.network(
                                        'https://image.tmdb.org/t/p/w185$poster',
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: const Color(0xFF2C2C32),
                                        child: const Icon(Icons.broken_image),
                                      ),
                              ),
                            ),
                            if (i <
                                8) // limit overlays to first 8 to avoid mass network calls
                              Positioned(
                                top: 4,
                                left: 4,
                                child: ProviderCornerGrid(
                                  showId: id,
                                  mediaType: mediaType == 'movie'
                                      ? MediaType.movie
                                      : MediaType.tv,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [if (year.isNotEmpty) year, if (role.isNotEmpty) role]
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_name.isEmpty ? 'Person' : _name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Constrain width so AspectRatio has bounded dimension (prevents layout crash on web)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 140, // ~ standard poster width
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: _profile.isNotEmpty
                        ? Image.network(
                            'https://image.tmdb.org/t/p/w185$_profile',
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: const Color(0xFF2C2C32),
                            alignment: Alignment.center,
                            child: const Icon(Icons.person, size: 48),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _bio.isNotEmpty ? _bio : 'No biography available.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          buildRow('TV Shows', tvCredits),
          buildRow('Movies', movieCredits),
          if (tvCredits.isEmpty && movieCredits.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(child: Text('No credits found.')),
            ),
        ],
      ),
    );
  }
}
