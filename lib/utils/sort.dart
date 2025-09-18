import '../services/storage.dart';

enum ShowSortMode {
  lastAdded,
  alphabetical,
  releaseYear,
  franchise, // experimental
}

int _yearOf(Show s) {
  if (s.firstAirDate.isEmpty) return 0;
  final y = int.tryParse(s.firstAirDate.substring(0, 4));
  return y ?? 0;
}

bool _containsAny(String lower, List<String> needles) {
  for (final n in needles) {
    if (lower.contains(n)) return true;
  }
  return false;
}

String _franchiseKey(Show s) {
  final t = s.title.toLowerCase();
  // Very light heuristics and a tiny known mapping; users can expand later.
  if (_containsAny(t, [
    'avengers','iron man','captain america','thor','guardians of the galaxy',
    'ant-man','black panther','doctor strange','spider-man','captain marvel',
    'eternals','shang-chi','hulk','loki','wandavision','falcon and the winter soldier'
  ])) return 'MCU';
  if (_containsAny(t, [
    'justice league','batman','superman','wonder woman','aquaman','shazam',
    'suicide squad','green lantern','the flash','peacemaker'
  ])) return 'DCU';
  if (_containsAny(t, ['indiana jones'])) return 'Indiana Jones';
  if (_containsAny(t, ['karate kid','cobra kai'])) return 'Karate Kid';

  // Fallback: take the base title before separators like ':', '-', '(', which often groups series
  final base = t.split(RegExp(r'[:\-–—(]'))[0].trim();
  // Normalize common leading articles
  final noArticle = base.replaceFirst(RegExp(r'^(the |a |an )'), '');
  return noArticle.isEmpty ? t : noArticle;
}

extension ShowSorting on List<Show> {
  List<Show> sortedBy(ShowSortMode mode, {bool ascending = true}) {
    final list = List<Show>.from(this);
    switch (mode) {
      case ShowSortMode.lastAdded:
        // ascending: oldest added first; descending: newest added first
        list.sort((a, b) {
          final cmp = a.addedAt.compareTo(b.addedAt);
          return ascending ? cmp : -cmp;
        });
        break;
      case ShowSortMode.alphabetical:
        list.sort((a, b) {
          final cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          return ascending ? cmp : -cmp;
        });
        break;
      case ShowSortMode.releaseYear:
        list.sort((a, b) {
          final ya = _yearOf(a);
          final yb = _yearOf(b);
          int cmp;
          if (ya == yb) {
            cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          } else {
            // ascending: oldest first; descending: newest first
            cmp = ya.compareTo(yb);
          }
          return ascending ? cmp : -cmp;
        });
        break;
      case ShowSortMode.franchise:
        list.sort((a, b) {
          final fa = _franchiseKey(a);
          final fb = _franchiseKey(b);
          int c = fa.compareTo(fb);
          if (c != 0) return ascending ? c : -c;
          // within franchise, order by release year then title
          final ya = _yearOf(a);
          final yb = _yearOf(b);
          c = ya.compareTo(yb);
          if (c != 0) return ascending ? c : -c;
          c = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          return ascending ? c : -c;
        });
        break;
    }
    return list;
  }
}

/// Provides the default "ascending" direction for each [ShowSortMode].
///
/// Rationale:
/// - lastAdded: default to newest-first (descending) so users see recent items.
/// - alphabetical: A→Z ascending by default.
/// - releaseYear: oldest→newest ascending by default (per user example).
/// - franchise: A→Z by franchise name ascending by default.
bool defaultAscendingFor(ShowSortMode mode) {
  switch (mode) {
    case ShowSortMode.lastAdded:
      return false; // newest first
    case ShowSortMode.alphabetical:
      return true; // A→Z
    case ShowSortMode.releaseYear:
      return true; // oldest→newest
    case ShowSortMode.franchise:
      return true; // A→Z
  }
}
