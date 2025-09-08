import 'dart:ui' as ui;

/// Try to detect a 2-letter ISO 3166-1 region code from system locales.
String? tryDetectRegionCode() {
  try {
    final dispatcher = ui.PlatformDispatcher.instance;
    final locales = dispatcher.locales;
    if (locales.isNotEmpty) {
      // Prefer a non-English locale's region if present (common case: user language set to English UK but lives in another country like Sweden).
      for (final l in locales) {
        final cc = l.countryCode;
        if (cc != null &&
            cc.length == 2 &&
            l.languageCode.toLowerCase() != 'en') {
          return cc.toUpperCase();
        }
      }
      // If we only saw English variants, gather all distinct country codes and
      // if there's more than one, prefer one that is not GB (heuristic to avoid defaulting to en-GB browser language when user is elsewhere).
      final englishCodes = <String>{};
      for (final l in locales) {
        final cc = l.countryCode;
        if (cc != null &&
            cc.length == 2 &&
            l.languageCode.toLowerCase() == 'en') {
          englishCodes.add(cc.toUpperCase());
        }
      }
      if (englishCodes.length > 1 && englishCodes.contains('GB')) {
        // Pick the first non-GB English region to avoid bias.
        final alt =
            englishCodes.firstWhere((c) => c != 'GB', orElse: () => 'GB');
        if (alt != 'GB') return alt;
      }
      // Fallback to first locale with a valid country code.
      for (final l in locales) {
        final cc = l.countryCode;
        if (cc != null && cc.length == 2) return cc.toUpperCase();
      }
    }
    final single = dispatcher.locale;
    final cc2 = single.countryCode;
    if (cc2 != null && cc2.length == 2) return cc2.toUpperCase();
  } catch (_) {
    // ignore platform issues
  }
  return null;
}

/// Detect a region code, falling back to [fallback] if none auto-detected.
String detectRegionCode({String fallback = 'US'}) =>
    tryDetectRegionCode() ?? fallback.toUpperCase();

/// Resolve a free-form user input (country name, alias, or code) to an
/// ISO 3166-1 alpha-2 region code (uppercase). Returns null if unknown.
String? resolveRegionInput(String input) {
  final raw = input.trim();
  if (raw.isEmpty) return null;

  // Direct 2-letter code
  if (raw.length == 2 && RegExp(r'^[A-Za-z]{2}$').hasMatch(raw)) {
    return raw.toUpperCase();
  }

  final norm = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  const Map<String, String> alias = {
    // United States
    'unitedstates': 'US',
    'unitedstatesofamerica': 'US',
    'usa': 'US',
    'america': 'US',
    'usofa': 'US',
    // United Kingdom / Great Britain
    'unitedkingdom': 'GB',
    'greatbritain': 'GB',
    'britain': 'GB',
    'uk': 'GB',
    'england': 'GB',
    'scotland': 'GB',
    'wales': 'GB',
    'northernireland': 'GB',
    // Sweden
    'sweden': 'SE',
    'sverige': 'SE',
    // Other common markets
    'germany': 'DE',
    'deutschland': 'DE',
    'france': 'FR',
    'italy': 'IT',
    'spain': 'ES',
    'australia': 'AU',
    'canada': 'CA',
    'mexico': 'MX',
    'brazil': 'BR',
    'india': 'IN',
    'japan': 'JP',
    'southkorea': 'KR',
    'korea': 'KR',
    'republicofkorea': 'KR',
    'china': 'CN',
    'hongkong': 'HK',
    'netherlands': 'NL',
    'holland': 'NL',
    'norway': 'NO',
    'denmark': 'DK',
    'finland': 'FI',
    'poland': 'PL',
    'switzerland': 'CH',
    'austria': 'AT',
    'ireland': 'IE',
    'newzealand': 'NZ',
    'zealand': 'NZ',
  };

  final direct = alias[norm];
  if (direct != null) return direct;

  // Unique prefix match across aliases
  final candidates = alias.entries
      .where((e) => e.key.startsWith(norm))
      .map((e) => e.value)
      .toSet()
      .toList();
  if (candidates.length == 1) return candidates.first;
  return null;
}

/// Debug helper: returns a multi-line string describing locale list and chosen code.
String debugRegionDetectionSummary() {
  final dispatcher = ui.PlatformDispatcher.instance;
  final locales = dispatcher.locales;
  final list = locales
      .map((l) =>
          '${l.languageCode}${l.countryCode != null ? '-${l.countryCode}' : ''}')
      .join(', ');
  final detected = tryDetectRegionCode();
  return 'Locales: [$list] -> detected=$detected';
}
