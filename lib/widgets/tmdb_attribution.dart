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
    this.height = 16,
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
    // Always prefer this specific mark
    const candidates = <String>[
      // Prefer filename without spaces for web asset fetch stability
      'assets/logos/tmdb_1.svg',
      'assets/logos/TMDB 1.svg',
      // Fallbacks if the preferred asset is missing
      'assets/logos/TMDB 2.svg',
  'assets/logos/tmdb-color.svg',
    ];

    for (final path in candidates) {
      try {
        await rootBundle.load(path); // existence check
        return path;
      } catch (_) {
        // continue to next candidate
      }
    }
    return null;
  }

  // Removed color detection; we now explicitly prefer 'TMDB 1.svg'.

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
  // TMDb green retained for reference (not used when rendering native SVG colors).
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
