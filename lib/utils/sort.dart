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
  List<Show> sortedBy(ShowSortMode mode) {
    final list = List<Show>.from(this);
    switch (mode) {
      case ShowSortMode.lastAdded:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case ShowSortMode.alphabetical:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case ShowSortMode.releaseYear:
        list.sort((a, b) {
          final ya = _yearOf(a);
          final yb = _yearOf(b);
          if (ya == yb) return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          // Descending (newer first). Change to ascending by swapping a/b.
          return yb.compareTo(ya);
        });
        break;
      case ShowSortMode.franchise:
        list.sort((a, b) {
          final fa = _franchiseKey(a);
          final fb = _franchiseKey(b);
          final c = fa.compareTo(fb);
          if (c != 0) return c;
          // within franchise, order by release year then title
          final ya = _yearOf(a);
          final yb = _yearOf(b);
          final yc = ya.compareTo(yb);
          if (yc != 0) return yc;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
    }
    return list;
  }
}
