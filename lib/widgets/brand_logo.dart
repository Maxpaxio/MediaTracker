import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

class BrandLogo extends StatefulWidget {
  const BrandLogo({super.key, this.height = 72, this.semanticLabel = 'MediaTracker logo'});
  final double height;
  final String semanticLabel;

  @override
  State<BrandLogo> createState() => _BrandLogoState();
}

class _BrandLogoState extends State<BrandLogo> {
  late Future<_AssetChoice?> _choice;

  @override
  void initState() {
    super.initState();
    _choice = _resolveAsset();
  }

  Future<_AssetChoice?> _resolveAsset() async {
    const candidates = <String>[
      // Prefer the new transparent PNG provided by the user
      'assets/logos/MediaTrackerLogo.png',
      // Then the SVG the user added
      'assets/logos/MediaTrackerLogo.svg',
      // Legacy/alternative names kept as fallbacks
      'assets/logos/mediatracker_logo.svg',
      'assets/logos/mediatracker_logo.png',
      'assets/logos/mediatracker_logo.jpg',
      'assets/logos/mediatracker_logo.jpeg',
      'assets/logos/mediatracker_logo.webp',
    ];
    for (final path in candidates) {
      try {
        await rootBundle.load(path);
        final isSvg = path.toLowerCase().endsWith('.svg');
        return _AssetChoice(path: path, isSvg: isSvg);
      } catch (_) {
        // try next
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AssetChoice?>(
      future: _choice,
      builder: (context, snap) {
        final choice = snap.data;
        if (choice == null) {
          // Simple fallback: app initial + check icon
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: widget.height * 0.5, color: const Color(0xFFB48CFF)),
              const SizedBox(width: 8),
              Text('MediaTracker', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          );
        }
        if (choice.isSvg) {
          return SvgPicture.asset(
            choice.path,
            height: widget.height,
            semanticsLabel: widget.semanticLabel,
          );
        }
        return Image.asset(
          choice.path,
          height: widget.height,
          semanticLabel: widget.semanticLabel,
        );
      },
    );
  }
}

class _AssetChoice {
  final String path;
  final bool isSvg;
  const _AssetChoice({required this.path, required this.isSvg});
}
