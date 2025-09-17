import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

/// Small footer showing the TMDb logo with attribution.
///
/// Tries multiple possible asset filenames under assets/logos/ and falls back to text if none exist.
class TmdbAttribution extends StatefulWidget {
  const TmdbAttribution({
    super.key,
    this.center = true,
    this.height = 20,
    this.textAbove = false,
  });
  final bool center;
  final double height;
  final bool textAbove;

  @override
  State<TmdbAttribution> createState() => _TmdbAttributionState();
}

class _TmdbAttributionState extends State<TmdbAttribution> {
  Future<String?>? _assetPathFuture;

  @override
  void initState() {
    super.initState();
    _assetPathFuture = _resolveAssetPath();
  }

  /// Return the first existing TMDb logo asset path, else null.
  Future<String?> _resolveAssetPath() async {
    const candidates = <String>[
  // Explicit colored fallback name if provided
  'assets/logos/tmdb-color.svg',
      // Prefer full brand lockups first if present
      'assets/logos/The Movie DB 1.svg',
      'assets/logos/The Movie DB.svg',
      // Then the shorter marks
      'assets/logos/TMDB 2.svg',
      'assets/logos/TMDB 1.svg',
    ];

    final existing = <String>[];
    for (final path in candidates) {
      try {
        await rootBundle.load(path); // existence check
        existing.add(path);
      } catch (_) {
        // continue
      }
    }
    if (existing.isEmpty) return null;

    // Prefer a colored SVG among the existing ones
    for (final path in existing) {
      try {
        final data = await rootBundle.loadString(path);
        if (_isColoredSvg(data)) return path;
      } catch (_) {
        // ignore and continue
      }
    }
    // Fallback: first existing
    return existing.first;
  }

  bool _isColoredSvg(String data) {
    final s = data.toLowerCase();
    if (s.contains('lineargradient') || s.contains('radialgradient')) {
      return true;
    }
    // Look for non-black/white color literals in fill or stroke
    // Accepts hex like #01d277 or named colors other than white/black/currentColor
    final colorAttrs = RegExp(r'(fill|stroke)\s*=\s*"([^"]+)"');
    for (final m in colorAttrs.allMatches(s)) {
      final v = m.group(2)?.trim() ?? '';
      if (v.isEmpty) continue;
      if (v == 'none') continue;
      if (v == 'currentcolor') continue;
      if (v == '#000' || v == '#000000') continue;
      if (v == '#fff' || v == '#ffffff') continue;
      if (v == 'black' || v == 'white') continue;
      return true; // found a color that isn't black/white/current
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: Colors.white70);

    final child = FutureBuilder<String?>(
      future: _assetPathFuture,
      builder: (context, snap) {
  final hasLogo = (snap.data != null && snap.data!.isNotEmpty);
  const tmdbGreen = Color(0xFF01D277);
        assert(() {
          // Debug which asset was picked in debug/profile builds
          // (won't execute in release mode).
          if (hasLogo) {
            // ignore: avoid_print
            print('TmdbAttribution using asset: ${snap.data}');
          } else {
            // ignore: avoid_print
            print('TmdbAttribution no SVG asset found, using fallback text/icon');
          }
          return true;
        }());
        final logo = hasLogo
            ? SvgPicture.asset(
                snap.data!,
                height: widget.height,
    theme: const SvgTheme(currentColor: tmdbGreen),
                semanticsLabel: 'TMDb',
              )
            : Icon(Icons.movie, size: widget.height - 2, color: Colors.white70);

        final text = Text(
          'This product uses TMDb as the source of information.',
          style: textStyle,
          textAlign: widget.center ? TextAlign.center : TextAlign.start,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        );

        final content = widget.textAbove
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: widget.center
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  text,
                  const SizedBox(height: 8),
                  logo,
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: widget.center
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  logo,
                  const SizedBox(width: 8),
                  Flexible(child: text),
                ],
              );

        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => launchUrl(Uri.parse('https://www.themoviedb.org/')),
          child: content,
        );
      },
    );

    // Keep height minimal so it doesn't take over the whole Scaffold when used
    // in bottomNavigationBar. Center horizontally using a Row to avoid
    // unconstrained height expansion caused by Center/Align.
    final wrapped = widget.center
        ? Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [child],
          )
        : child;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: wrapped,
    );
  }
}
