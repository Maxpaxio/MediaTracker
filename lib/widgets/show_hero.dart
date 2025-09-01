import 'dart:typed_data';
import 'dart:ui' as ui show Image, ImageByteFormat, decodeImageFromList;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/storage.dart';

/// Backdrop behavior:
/// - If `fitToHeight: true`, backdrop scales to hero height (top & bottom locked) and auto-centers
///   within the visible band (from poster-center wall to right edge), clamped so it can peek under
///   the poster by `allowUnderPosterPx` at most. `backdropOffsetX` applies as a nudge.
/// - If `fitToHeight: false`, backdrop is drawn at native size (no scaling) and can crop vertically.
/// - A solid background color fills the sides; it is sampled from backdrop edges (mobile & web),
///   with a sideFillColor override if you want to force a specific tone.
/// - NEW: Edge fade — the backdrop softly fades out on the left/right into the side fill color.
class ShowHero extends StatefulWidget {
  const ShowHero({
    super.key,
    required this.show,
    this.height = 220,
    this.posterWidth = 150,
    this.horizontalPadding = 16,
    this.showLeftGradient = false, // your preference
    this.fitToHeight = true, // your preference
    this.backdropOffsetX = -40.0, // your default nudge
    this.allowUnderPosterPx = 44.0, // your default peek under poster
    this.sideFillColor, // optional manual override (esp. for Web)
    this.edgeFadePx = 30.0, // NEW: fade width on each side (logical px)
  });

  final Show show;
  final double height;
  final double posterWidth;
  final double horizontalPadding;
  final bool showLeftGradient;

  /// If true, scales the image to the given `height` (pins top & bottom).
  /// If false, no scaling; image is rendered at native size and vertically cropped if needed.
  final bool fitToHeight;

  /// Horizontal nudge (in logical px). Negative shifts backdrop left; positive right.
  final double backdropOffsetX;

  /// How many pixels left of the poster center we allow the backdrop to show.
  /// 0 keeps a hard wall at the poster center. Increase to let art peek under poster.
  final double allowUnderPosterPx;

  /// Override for the solid side fill color. If null, we sample from the backdrop.
  final Color? sideFillColor;

  /// NEW: how wide (in logical px) the fade should be on each horizontal side of the backdrop.
  final double edgeFadePx;

  @override
  State<ShowHero> createState() => _ShowHeroState();
}

class _ShowHeroState extends State<ShowHero> {
  // Decoded image (used for RawImage) + sampled side color
  ui.Image? _decoded;
  Color? _sideFill;

  // Also keep web bytes (so we don’t fetch twice on web)
  Uint8List? _webBytes;

  // Non-web stream (for decoding once)
  ImageStream? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initImage();
  }

  @override
  void didUpdateWidget(covariant ShowHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.show.backdropUrl != widget.show.backdropUrl) {
      _disposeImage();
      _initImage();
    }
  }

  void _initImage() {
    final url = widget.show.backdropUrl;
    if (url.isEmpty) return;

    if (kIsWeb) {
      _loadWebBytes(url);
    } else {
      _subscribeStream(url);
    }
  }

  // ───────────────────────────── Web path ─────────────────────────────
  Future<void> _loadWebBytes(String url) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final bytes = res.bodyBytes;
        _webBytes = bytes;

        // Decode via callback-style API (returns void)
        ui.decodeImageFromList(bytes, (ui.Image img) async {
          if (!mounted) return;
          _decoded = img;

          // Sample edge colors from decoded image (now allowed)
          final c = await _sampleEdgeColor(img);
          if (mounted)
            setState(() {
              _sideFill = c;
            });
        });

        // Rebuild once bytes are present (even if decode callback lands a tick later)
        if (mounted) setState(() {});
      }
    } catch (_) {
      // network error; ignore and keep fallback color
    }
  }

  // ─────────────────────── Non-web (ImageStream) path ───────────────────────
  void _subscribeStream(String url) {
    final provider = NetworkImage(url);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    _stream = stream;
    stream.addListener(ImageStreamListener((info, _) async {
      if (!mounted) return;
      // Use the already-decoded raster directly (no provider flicker)
      _decoded = info.image;

      // Sample edge color from the raster
      final c = await _sampleEdgeColor(info.image);
      if (mounted)
        setState(() {
          _sideFill = c;
        });
    }, onError: (_, __) {
      if (!mounted) return;
      setState(() {
        _decoded = null;
        _sideFill = null;
      });
    }));
  }

  void _disposeImage() {
    _stream = null;
    _decoded = null;
    _webBytes = null;
    _sideFill = null;
  }

  @override
  void dispose() {
    _disposeImage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;

    // Base left boundary = poster center inside padding
    final posterCenter = widget.horizontalPadding + (widget.posterWidth / 2);
    // Relax wall by allowUnderPosterPx (let artwork peek under poster)
    final leftBoundary =
        (posterCenter - widget.allowUnderPosterPx).clamp(0.0, double.infinity);

    // Logical image size (if decoded)
    final double? imgW = _decoded != null ? _decoded!.width / dpr : null;
    final double? imgH = _decoded != null ? _decoded!.height / dpr : null;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: [
          // Solid side fill — use override first, then sampled color, then fallback.
          Positioned.fill(
            child: Container(
                color: widget.sideFillColor ??
                    _sideFill ??
                    const Color(0xFF111112)),
          ),

          // Backdrop band: only shows from leftBoundary to the right edge.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(left: leftBoundary),
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bandW = constraints.maxWidth; // width of visible band
                    final bandH = widget.height;

                    // Backdrop image widget (RawImage avoids provider-induced flicker)
                    Widget rawBackdrop = _rawBackdropImage();
                    if (rawBackdrop is SizedBox) {
                      // Not ready yet
                      return const SizedBox.shrink();
                    }

                    if (widget.fitToHeight) {
                      // ── Fit-to-height mode: scale to height, lock top & bottom ──
                      if (imgW == null ||
                          imgH == null ||
                          imgW == 0 ||
                          imgH == 0) {
                        // If we don't yet know image dimensions, simple left-align + nudge
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: RepaintBoundary(
                            child: Transform.translate(
                              offset: Offset(widget.backdropOffsetX, 0),
                              child: SizedBox(
                                width: bandW,
                                height: bandH,
                                child: _edgeFade(
                                  child: FittedBox(
                                    fit: BoxFit.fitHeight,
                                    alignment: Alignment.centerLeft,
                                    child: rawBackdrop,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      // We know the image size; compute the scaled width at this height.
                      final scale = bandH / imgH; // fit-to-height scale
                      final scaledW = imgW * scale;

                      // Ideal global left = center the scaled image within the band, then nudge.
                      final idealLeftGlobal = leftBoundary +
                          (bandW - scaledW) / 2 +
                          widget.backdropOffsetX;

                      // Hard wall at the original poster center - allowUnderPosterPx
                      final minLeftGlobal =
                          posterCenter - widget.allowUnderPosterPx;

                      // Clamp so it never goes past the wall on the left
                      final clampedLeftGlobal = idealLeftGlobal < minLeftGlobal
                          ? minLeftGlobal
                          : idealLeftGlobal;

                      // Convert to band-local dx
                      final dx = clampedLeftGlobal - leftBoundary;

                      return RepaintBoundary(
                        child: Stack(
                          children: [
                            // Place a sized box equal to the scaled image, offset by dx
                            Positioned(
                              left: dx,
                              top: 0,
                              width: scaledW,
                              height: bandH,
                              child: _edgeFade(
                                child: FittedBox(
                                  fit: BoxFit.fitHeight,
                                  alignment: Alignment.centerLeft,
                                  child: rawBackdrop,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // ── No-scaling mode: native size, vertical crop if needed ──
                    if (imgW == null ||
                        imgH == null ||
                        imgW == 0 ||
                        imgH == 0) {
                      return const SizedBox.shrink();
                    }

                    // Center within band, then apply nudge, but never cross the poster center wall.
                    final idealLeftGlobal = leftBoundary +
                        (bandW - imgW) / 2 +
                        widget.backdropOffsetX;
                    final minLeftGlobal =
                        posterCenter - widget.allowUnderPosterPx;
                    final clampedLeftGlobal = idealLeftGlobal < minLeftGlobal
                        ? minLeftGlobal
                        : idealLeftGlobal;

                    final leftInBand = clampedLeftGlobal - leftBoundary;
                    final topInBand = (bandH - imgH) / 2;

                    return RepaintBoundary(
                      child: Stack(
                        children: [
                          Positioned(
                            left: leftInBand,
                            top: topInBand,
                            child: SizedBox(
                              width: imgW,
                              height: imgH,
                              child: _edgeFade(
                                child: FittedBox(
                                  fit: BoxFit.none, // no scaling
                                  child: rawBackdrop,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Optional gradient near poster for readability (off by default per your setting)
          if (widget.showLeftGradient)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0x99000000),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Foreground: poster on the left
          Positioned.fill(
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: widget.posterWidth,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 2 / 3,
                        child: Image.network(
                          widget.show.posterUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF2C2C32),
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Stable, non-provider image widget to prevent flicker.
  Widget _rawBackdropImage() {
    final img = _decoded;
    if (img == null) return const SizedBox.shrink();
    return RawImage(
      image: img,
      isAntiAlias: true,
      filterQuality: FilterQuality.medium,
    );
  }

  /// Apply a horizontal edge fade using a shader mask.
  /// Fades from transparent → opaque → opaque → transparent,
  /// with fade width controlled by `widget.edgeFadePx`.
  Widget _edgeFade({required Widget child}) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect rect) {
        final w = rect.width <= 0 ? 1.0 : rect.width;
        final f = (widget.edgeFadePx / w).clamp(0.0, 0.5); // avoid overlap
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0.0, f, 1 - f, 1.0],
        ).createShader(rect);
      },
      child: child,
    );
  }

  /// Sample average color from the left and right edge columns of the image.
  Future<Color> _sampleEdgeColor(ui.Image img) async {
    try {
      final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return const Color(0xFF111112);

      final w = img.width;
      final h = img.height;
      int r = 0, g = 0, b = 0, count = 0;

      void addColumn(int x) {
        final base = x * 4;
        for (int y = 0; y < h; y++) {
          final offset = y * w * 4 + base;
          r += byteData.getUint8(offset);
          g += byteData.getUint8(offset + 1);
          b += byteData.getUint8(offset + 2);
          count++;
        }
      }

      // Sample far left and far right columns.
      addColumn(0);
      if (w > 1) addColumn(w - 1);

      if (count == 0) return const Color(0xFF111112);
      return Color.fromARGB(255, r ~/ count, g ~/ count, b ~/ count);
    } catch (_) {
      return const Color(0xFF111112);
    }
  }
}
