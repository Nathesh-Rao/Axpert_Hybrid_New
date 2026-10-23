import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'connection_style.dart';

/// Round logo badge for project headers, lists, and dialogs.
///
/// Works with any dynamic logo:
/// * Sits on a white circle, so dark or colourful logos stay readable.
/// * Measures the logo and scales it to the largest size that still fits
///   inside the circle (no cropping, no stretching), whatever its shape.
/// * Shows a round placeholder while loading, so the layout never jumps.
/// * Falls back to [ConnectionMark] when the URL is empty or fails to load.
/// * Detects light-only logos (for example white on transparent) and switches
///   to a frosted dark circle automatically. Pass [darkPlate] to force it.
class ProjectLogo extends StatefulWidget {
  const ProjectLogo({
    super.key,
    required this.url,
    this.projectName = '',
    this.size = 84,
    this.darkPlate,
  });

  final String url;
  final String projectName;
  final double size;

  /// null = decide automatically from the logo pixels.
  final bool? darkPlate;

  @override
  State<ProjectLogo> createState() => _ProjectLogoState();
}

class _ProjectLogoState extends State<ProjectLogo> {
  ImageProvider? _provider;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _natural;
  bool _failed = false;
  bool _light = false;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProjectLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.projectName != widget.projectName) {
      _load();
    }
  }

  @override
  void dispose() {
    _token++;
    _unlisten();
    super.dispose();
  }

  void _unlisten() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  void _load() {
    _unlisten();
    final token = ++_token;
    _natural = null;
    _failed = false;
    _light = false;

    final url = widget.url.trim();
    if (url.isEmpty) {
      _provider = null;
      _failed = true;
      return;
    }

    final provider = NetworkImage(url);
    _provider = provider;
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, synchronous) {
        if (!mounted || token != _token) {
          info.dispose();
          return;
        }
        final size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        if (synchronous) {
          _natural = size;
        } else if (mounted) {
          setState(() => _natural = size);
        }
        // Own the image while asynchronous pixel inspection is running.
        _detectLight(info.image.clone(), token);
        info.dispose();
      },
      onError: (Object error, StackTrace? stack) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || token != _token) return;
          setState(() => _failed = true);
        });
      },
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  Future<void> _detectLight(ui.Image image, int token) async {
    var light = false;
    try {
      light = await _isLightLogo(image);
      await _trimLogo(image, token);
    } catch (_) {
      // Decoding failures retain the default white plate.
    } finally {
      image.dispose();
    }
    if (!mounted || token != _token || light == _light) return;
    setState(() => _light = light);
  }

  // Remove empty margins embedded in the file, so sizing follows the artwork
  // rather than a large transparent or plain white canvas.
  Future<void> _trimLogo(ui.Image image, int token) async {
    final pixels = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (pixels == null) return;
    bool white(int x, int y) {
      final i = (y * image.width + x) * 4;
      return pixels.getUint8(i + 3) > 240 &&
          pixels.getUint8(i) > 245 &&
          pixels.getUint8(i + 1) > 245 &&
          pixels.getUint8(i + 2) > 245;
    }

    final whiteBackground =
        white(0, 0) &&
        white(image.width - 1, 0) &&
        white(0, image.height - 1) &&
        white(image.width - 1, image.height - 1);
    var left = image.width, top = image.height, right = -1, bottom = -1;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final i = (y * image.width + x) * 4;
        if (pixels.getUint8(i + 3) < 40 || (whiteBackground && white(x, y))) {
          continue;
        }
        left = math.min(left, x);
        top = math.min(top, y);
        right = math.max(right, x);
        bottom = math.max(bottom, y);
      }
    }
    if (right < left ||
        bottom < top ||
        (left == 0 &&
            top == 0 &&
            right == image.width - 1 &&
            bottom == image.height - 1)) {
      return;
    }
    final width = right - left + 1, height = bottom - top + 1;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(
        left.toDouble(),
        top.toDouble(),
        width.toDouble(),
        height.toDouble(),
      ),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint(),
    );
    final picture = recorder.endRecording();
    final trimmed = await picture.toImage(width, height);
    picture.dispose();
    final bytes = await trimmed.toByteData(format: ui.ImageByteFormat.png);
    trimmed.dispose();
    if (!mounted || token != _token || bytes == null) return;
    setState(() {
      _provider = MemoryImage(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      _natural = Size(width.toDouble(), height.toDouble());
    });
  }

  /// True when the logo is mostly light and has a transparent background,
  /// meaning it would disappear on a white circle.
  Future<bool> _isLightLogo(ui.Image image) async {
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (data == null) return false;
    final total = image.width * image.height;
    if (total <= 0) return false;
    final step = math.max(1, total ~/ 4000);
    var counted = 0;
    var opaque = 0;
    var luminance = 0.0;
    for (var i = 0; i < total; i += step) {
      final o = i * 4;
      counted++;
      if (data.getUint8(o + 3) < 40) continue;
      opaque++;
      luminance +=
          (0.2126 * data.getUint8(o) +
              0.7152 * data.getUint8(o + 1) +
              0.0722 * data.getUint8(o + 2)) /
          255;
    }
    // A filled rectangle (for example a JPG with a white background) is not a
    // light-only logo, so keep the white circle for it.
    if (opaque == 0 || opaque / counted > 0.9) return false;
    return luminance / opaque > 0.82;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.size;
    final dark = widget.darkPlate ?? _light;
    // Usable radius inside the circle, leaving a little air around the logo.
    final radius = d * .49;

    final Widget content;
    if (_failed || _provider == null) {
      content = KeyedSubtree(
        key: const ValueKey('fallback'),
        child: ConnectionMark(size: d * .88),
      );
    } else if (_natural == null) {
      content = KeyedSubtree(
        key: const ValueKey('loading'),
        child: SizedBox(
          width: d * .42,
          height: d * .42,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark ? Colors.white24 : const Color(0xffE6EAF5),
            ),
          ),
        ),
      );
    } else {
      final natural = _natural!;
      final aspect = natural.height <= 0 ? 1.0 : natural.width / natural.height;
      // Largest box with this aspect ratio whose corners stay inside the circle.
      final h = (2 * radius) / math.sqrt(aspect * aspect + 1);
      final w = h * aspect;
      content = KeyedSubtree(
        key: ValueKey((widget.url, widget.projectName)),
        child: Image(
          image: _provider!,
          width: w,
          height: h,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, error, stack) => ConnectionMark(size: d * .88),
        ),
      );
    }

    return Semantics(
      image: true,
      label: widget.projectName.isEmpty
          ? 'Project logo'
          : '${widget.projectName} logo',
      child: Container(
        width: d,
        height: d,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dark
              ? const Color(0xff16275C).withValues(alpha: .94)
              : Colors.white,
          border: dark ? Border.all(color: Colors.white24) : null,
          boxShadow: dark
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x80050C28),
                    blurRadius: 24,
                    spreadRadius: -8,
                    offset: Offset(0, 10),
                  ),
                ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: content,
        ),
      ),
    );
  }
}
