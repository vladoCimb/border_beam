/// Animated border beam effect.
/// ```dart
/// BorderBeam(
///   type: BorderBeamType.full,
///   child: Card(...),
/// )
/// ```
///
/// The renderer mirrors the CSS layer structure of the original:
///
/// * `::after`           -> stroke layer (gradients masked to the border ring)
/// * `::before`          -> inner glow layer (edge-framed gradients + shadow)
/// * `[data-beam-bloom]` -> bloom layer (blurred, masked after the blur)
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// The visual type of the beam effect.
enum BorderBeamType {
  /// Traveling beam around the full border. Suited for cards and larger
  /// surfaces. (`md` in the original library.)
  full,

  /// Compact traveling beam for small, button-sized elements.
  /// (`sm` in the original library.)
  compact,

  /// Bottom-only traveling glow with breathe and spike accents. Suited for
  /// search bars and inputs.
  line,

  /// Breathing glow contained within the element's border. No rotation.
  pulseInner,
}

/// Color palette used by the beam.
enum BorderBeamColorVariant {
  /// Full rainbow spectrum (default).
  colorful,

  /// Monochromatic grayscale.
  mono,

  /// Blue and purple tones.
  ocean,

  /// Warm orange, yellow, and red tones.
  sunset,

  /// Colors supplied through [BorderBeam.customColors].
  custom,
}

/// Adapts the beam colors to the background behind the wrapped child.
enum BorderBeamTheme {
  /// Tuned for dark backgrounds (default).
  dark,

  /// Tuned for light backgrounds.
  light,

  /// Follows the ambient [ThemeData.brightness].
  auto,
}

/// Wraps [child] with an animated border beam effect.
///
/// The effect layers are purely decorative: they are painted above (never
/// instead of) the child and don't participate in hit testing.
class BorderBeam extends StatefulWidget {
  /// The widget to wrap with the effect.
  final Widget child;

  /// The visual type of the effect. Defaults to [BorderBeamType.full].
  final BorderBeamType type;

  /// The color palette. Defaults to [BorderBeamColorVariant.colorful].
  final BorderBeamColorVariant colorVariant;

  /// Colors used when [colorVariant] is [BorderBeamColorVariant.custom].
  ///
  /// The colors are distributed cyclically over the gradient slots of the
  /// effect, so any number of colors (one or more) works. Custom colors are
  /// rendered as supplied: the slow hue-shift animation of the built-in
  /// palettes is disabled.
  final List<Color>? customColors;

  /// Background adaptation. Defaults to [BorderBeamTheme.dark].
  final BorderBeamTheme theme;

  /// Overall effect opacity from 0 (invisible) to 1 (full intensity).
  /// Only affects the beam layers, never the child.
  final double strength;

  /// Animation cycle duration. Defaults to 1.96s for [BorderBeamType.full]
  /// and [BorderBeamType.compact], 3.1s for [BorderBeamType.line], and 2.3s
  /// for [BorderBeamType.pulseInner].
  final Duration? duration;

  /// Whether the animation is playing. Toggling animates a smooth fade.
  final bool active;

  /// Border radius of the wrapped child in logical pixels. Defaults to 32
  /// for [BorderBeamType.compact] and 16 otherwise. Values larger than the
  /// child allows are clamped, so `999` produces a stadium/pill shape.
  final double? borderRadius;

  /// Creates a border beam around [child].
  const BorderBeam({
    super.key,
    required this.child,
    this.type = BorderBeamType.full,
    this.colorVariant = BorderBeamColorVariant.colorful,
    this.customColors,
    this.theme = BorderBeamTheme.dark,
    this.strength = 1,
    this.duration,
    this.active = true,
    this.borderRadius,
  }) : assert(
         colorVariant != BorderBeamColorVariant.custom || customColors != null,
         'customColors is required when colorVariant is '
         'BorderBeamColorVariant.custom',
       );

  @override
  State<BorderBeam> createState() => _BorderBeamState();
}

enum _FadePhase { hidden, fadingIn, shown, fadingOut }

class _BorderBeamState extends State<BorderBeam>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  double _t = 0;
  _FadePhase _phase = _FadePhase.hidden;
  double _fadeStart = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.active) {
      _phase = _FadePhase.fadingIn;
      _fadeStart = 0;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    _t = elapsed.inMicroseconds / 1e6;
    if (_phase == _FadePhase.fadingIn && _t - _fadeStart >= 0.6) {
      _phase = _FadePhase.shown;
    } else if (_phase == _FadePhase.fadingOut && _t - _fadeStart >= 0.5) {
      _phase = _FadePhase.hidden;
      _ticker.stop();
    }
    _frame.value++;
  }

  @override
  void didUpdateWidget(covariant BorderBeam oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    if (widget.active) {
      if (!_ticker.isActive) {
        _t = 0;
        _fadeStart = 0;
        _ticker.start();
      } else {
        _fadeStart = _t;
      }
      _phase = _FadePhase.fadingIn;
    } else if (_phase == _FadePhase.fadingIn || _phase == _FadePhase.shown) {
      _phase = _FadePhase.fadingOut;
      _fadeStart = _t;
    }
  }

  double get _fade {
    switch (_phase) {
      case _FadePhase.hidden:
        return 0;
      case _FadePhase.shown:
        return 1;
      case _FadePhase.fadingIn:
        return Curves.ease.transform(((_t - _fadeStart) / 0.6).clamp(0.0, 1.0));
      case _FadePhase.fadingOut:
        return 1 -
            Curves.ease.transform(((_t - _fadeStart) / 0.5).clamp(0.0, 1.0));
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark;
    switch (widget.theme) {
      case BorderBeamTheme.dark:
        isDark = true;
        break;
      case BorderBeamTheme.light:
        isDark = false;
        break;
      case BorderBeamTheme.auto:
        isDark = Theme.of(context).brightness == Brightness.dark;
        break;
    }
    return RepaintBoundary(
      child: CustomPaint(
        foregroundPainter: _BeamPainter(_resolve(isDark), this),
        child: widget.child,
      ),
    );
  }

  _ResolvedBeam _resolve(bool isDark) {
    final type = widget.type;
    final preset = _presetFor(type, isDark);
    final durationSec = widget.duration != null
        ? widget.duration!.inMicroseconds / 1e6
        : switch (type) {
            BorderBeamType.line => 3.1,
            BorderBeamType.pulseInner => 2.3,
            _ => 1.96,
          };
    final isMono = widget.colorVariant == BorderBeamColorVariant.mono;
    return _ResolvedBeam(
      type: type,
      palette: _paletteFor(widget.colorVariant, widget.customColors),
      isMono: isMono,
      isDark: isDark,
      radius: widget.borderRadius ?? (type == BorderBeamType.compact ? 32 : 16),
      borderWidth: 1,
      duration: durationSec,
      strokeOpacity: preset.stroke,
      innerOpacity: preset.inner,
      bloomOpacity: preset.bloom,
      innerShadow: preset.innerShadow,
      brightness: preset.brightness ?? 1.3,
      saturation: preset.saturation,
      hueRange: type == BorderBeamType.line ? 13 : 30,
      // Mono has no hue to shift; custom colors are rendered as supplied.
      staticColors:
          isMono || widget.colorVariant == BorderBeamColorVariant.custom,
      strength: widget.strength.clamp(0.0, 1.0),
    );
  }
}

// ───────────────────────────── resolved config ─────────────────────────────

class _ResolvedBeam {
  final BorderBeamType type;
  final _Palette palette;
  final bool isMono;
  final bool isDark;
  final double radius;
  final double borderWidth;
  final double duration; // seconds
  final double strokeOpacity;
  final double innerOpacity;
  final double bloomOpacity;
  final Color innerShadow;
  final double brightness;
  final double saturation;
  final double hueRange;
  final bool staticColors;
  final double strength;

  const _ResolvedBeam({
    required this.type,
    required this.palette,
    required this.isMono,
    required this.isDark,
    required this.radius,
    required this.borderWidth,
    required this.duration,
    required this.strokeOpacity,
    required this.innerOpacity,
    required this.bloomOpacity,
    required this.innerShadow,
    required this.brightness,
    required this.saturation,
    required this.hueRange,
    required this.staticColors,
    required this.strength,
  });
}

/// Per-type/theme opacity and filter presets (`sizeThemePresets` upstream).
class _Preset {
  final double stroke, inner, bloom;
  final Color innerShadow;
  final double saturation;
  final double? brightness;

  const _Preset(
    this.stroke,
    this.inner,
    this.bloom,
    this.innerShadow,
    this.saturation, [
    this.brightness,
  ]);
}

_Preset _presetFor(BorderBeamType type, bool isDark) {
  switch (type) {
    case BorderBeamType.compact:
      return isDark
          ? const _Preset(
              0.46,
              0.24,
              0.38,
              Color.fromRGBO(255, 255, 255, 0.3),
              1.2,
            )
          : const _Preset(0.12, 0.30, 0.16, Color.fromRGBO(0, 0, 0, 0.14), 1.8);
    case BorderBeamType.full:
      return isDark
          ? const _Preset(
              0.26,
              0.42,
              0.24,
              Color.fromRGBO(255, 255, 255, 0.27),
              1.2,
            )
          : const _Preset(0.12, 0.26, 0.34, Color.fromRGBO(0, 0, 0, 0.14), 1.5);
    case BorderBeamType.line:
      return isDark
          ? const _Preset(
              1.14,
              0.70,
              0.80,
              Color.fromRGBO(255, 255, 255, 0.1),
              1.2,
            )
          : const _Preset(
              0.16,
              0.32,
              0.30,
              Color.fromRGBO(0, 0, 0, 0.14),
              1.95,
            );
    case BorderBeamType.pulseInner:
      return isDark
          ? const _Preset(1.54, 0.44, 0.66, Color(0x00000000), 1.2, 0.75)
          : const _Preset(0.32, 0.40, 0.80, Color(0x00000000), 0.75, 1.3);
  }
}

// ─────────────────────────────── palettes ──────────────────────────────────
//
// Gradient GEOMETRY (positions, sizes, offsets, alphas) is shared by all
// palettes and lives in the const tables further below. A palette only
// carries COLORS. The color lists differ per effect type because the source
// library tunes them separately for each type (e.g. the compact list is a
// reordered subset of the ring list).

/// A (primary, secondary) color pair.
class _CP {
  final Color a, b;
  const _CP(this.a, this.b);
}

class _Palette {
  /// 9 colors for the border ring of [BorderBeamType.full] and
  /// [BorderBeamType.pulseInner].
  final List<Color> ring;

  /// 8 colors for [BorderBeamType.compact].
  final List<Color> compact;

  /// 9 colors for [BorderBeamType.line] per theme. The line inner-glow layer
  /// always uses the dark list, matching the source library.
  final List<Color> lineDark;
  final List<Color> lineLight;

  /// Line bloom spike colors per theme.
  final _CP spikeDark, spikeLight;

  /// Line bloom gradient color pairs (5 per theme).
  final List<_CP> bloomSpikesDark, bloomSpikesLight;

  const _Palette({
    required this.ring,
    required this.compact,
    required this.lineDark,
    required this.lineLight,
    required this.spikeDark,
    required this.spikeLight,
    required this.bloomSpikesDark,
    required this.bloomSpikesLight,
  });

  /// Builds a palette from user-supplied colors by distributing them
  /// cyclically over the gradient slots.
  factory _Palette.fromColors(List<Color> colors) {
    Color at(int i) => colors[i % colors.length];
    List<Color> gen(int n) => List<Color>.generate(n, at, growable: false);
    final nine = gen(9);
    final spikes = List<_CP>.generate(
      5,
      (i) => _CP(at(i), at(i)),
      growable: false,
    );
    final spike = _CP(at(0), at(1));
    return _Palette(
      ring: nine,
      compact: gen(8),
      lineDark: nine,
      lineLight: nine,
      spikeDark: spike,
      spikeLight: spike,
      bloomSpikesDark: spikes,
      bloomSpikesLight: spikes,
    );
  }
}

_Palette _paletteFor(BorderBeamColorVariant variant, List<Color>? custom) {
  switch (variant) {
    case BorderBeamColorVariant.colorful:
      return _colorfulPalette;
    case BorderBeamColorVariant.mono:
      return _monoPalette;
    case BorderBeamColorVariant.ocean:
      return _oceanPalette;
    case BorderBeamColorVariant.sunset:
      return _sunsetPalette;
    case BorderBeamColorVariant.custom:
      return _Palette.fromColors(custom!);
  }
}

const _colorfulPalette = _Palette(
  ring: [
    Color(0xFFFF3264),
    Color(0xFF288CFF),
    Color(0xFF32C850),
    Color(0xFF1EB9AA),
    Color(0xFF6446FF),
    Color(0xFF288CFF),
    Color(0xFFFF7828),
    Color(0xFFF032B4),
    Color(0xFFB428F0),
  ],
  compact: [
    Color(0xFF32C850),
    Color(0xFF1EB9AA),
    Color(0xFFFF7828),
    Color(0xFF6446FF),
    Color(0xFFF032B4),
    Color(0xFFB428F0),
    Color(0xFF288CFF),
    Color(0xFFFF3264),
  ],
  lineDark: [
    Color(0xFFFF3264),
    Color(0xFF28B4DC),
    Color(0xFF32C850),
    Color(0xFFB428F0),
    Color(0xFFFFA01E),
    Color(0xFF6446FF),
    Color(0xFF288CFF),
    Color(0xFFF032B4),
    Color(0xFF1EB9AA),
  ],
  lineLight: [
    Color(0xFFFF3264),
    Color(0xFF288CFF),
    Color(0xFF32C850),
    Color(0xFFB428F0),
    Color(0xFF1EB9AA),
    Color(0xFF6446FF),
    Color(0xFF288CFF),
    Color(0xFFFF7828),
    Color(0xFFF032B4),
  ],
  spikeDark: _CP(Color(0xFFFF3C50), Color.fromRGBO(40, 190, 180, 0.98)),
  spikeLight: _CP(Color(0xFFC81E3C), Color(0xFF14968C)),
  bloomSpikesDark: [
    _CP(Color(0xFF6446FF), Color(0xFF6446FF)),
    _CP(Color.fromRGBO(255, 170, 40, 0.59), Color.fromRGBO(255, 170, 40, 0.29)),
    _CP(Color(0xFF32C864), Color(0xFF32C864)),
    _CP(Color.fromRGBO(200, 50, 240, 0.91), Color.fromRGBO(200, 50, 240, 0.45)),
    _CP(Color(0xFF288CFF), Color(0xFF288CFF)),
  ],
  bloomSpikesLight: [
    _CP(Color(0xFF5032C8), Color.fromRGBO(80, 50, 200, 0.8)),
    _CP(Color.fromRGBO(210, 130, 0, 0.7), Color.fromRGBO(210, 130, 0, 0.46)),
    _CP(Color(0xFF1EA046), Color.fromRGBO(30, 160, 70, 0.82)),
    _CP(Color(0xFFA01EBE), Color.fromRGBO(160, 30, 190, 0.7)),
    _CP(Color(0xFF1E64C8), Color.fromRGBO(30, 100, 200, 0.78)),
  ],
);

const _monoPalette = _Palette(
  ring: [
    Color(0xFFB4B4B4),
    Color(0xFF8C8C8C),
    Color(0xFFA0A0A0),
    Color(0xFF828282),
    Color(0xFFAAAAAA),
    Color(0xFF969696),
    Color(0xFFBEBEBE),
    Color(0xFF919191),
    Color(0xFFA5A5A5),
  ],
  compact: [
    Color(0xFFA0A0A0),
    Color(0xFF8C8C8C),
    Color(0xFFB4B4B4),
    Color(0xFF969696),
    Color(0xFFAAAAAA),
    Color(0xFF9B9B9B),
    Color(0xFF919191),
    Color(0xFFA5A5A5),
  ],
  lineDark: [
    Color(0xFFC8C8C8),
    Color(0xFFAAAAAA),
    Color(0xFF9B9B9B),
    Color(0xFFB9B9B9),
    Color(0xFFA5A5A5),
    Color(0xFFB4B4B4),
    Color(0xFFA0A0A0),
    Color(0xFFAFAFAF),
    Color(0xFFBEBEBE),
  ],
  lineLight: [
    Color(0xFF646464),
    Color(0xFF505050),
    Color(0xFF5A5A5A),
    Color(0xFF464646),
    Color(0xFF555555),
    Color(0xFF5F5F5F),
    Color(0xFF4B4B4B),
    Color(0xFF696969),
    Color(0xFF414141),
  ],
  spikeDark: _CP(Color(0xFFC8C8C8), Color(0xFFAAAAAA)),
  spikeLight: _CP(Color(0xFF505050), Color(0xFF787878)),
  bloomSpikesDark: [
    _CP(Color(0xFFC8C8C8), Color(0xFFC8C8C8)),
    _CP(
      Color.fromRGBO(180, 180, 180, 0.59),
      Color.fromRGBO(180, 180, 180, 0.29),
    ),
    _CP(Color(0xFFBEBEBE), Color(0xFFBEBEBE)),
    _CP(
      Color.fromRGBO(170, 170, 170, 0.91),
      Color.fromRGBO(170, 170, 170, 0.45),
    ),
    _CP(Color(0xFFB9B9B9), Color(0xFFB9B9B9)),
  ],
  bloomSpikesLight: [
    _CP(Color(0xFF505050), Color.fromRGBO(80, 80, 80, 0.8)),
    _CP(
      Color.fromRGBO(100, 100, 100, 0.7),
      Color.fromRGBO(100, 100, 100, 0.46),
    ),
    _CP(Color(0xFF464646), Color.fromRGBO(70, 70, 70, 0.82)),
    _CP(Color(0xFF5A5A5A), Color.fromRGBO(90, 90, 90, 0.7)),
    _CP(Color(0xFF555555), Color.fromRGBO(85, 85, 85, 0.78)),
  ],
);

const _oceanPalette = _Palette(
  ring: [
    Color(0xFF6450DC),
    Color(0xFF3C78FF),
    Color(0xFF5064C8),
    Color(0xFF328CDC),
    Color(0xFF7850FF),
    Color(0xFF4682FF),
    Color(0xFF8C64F0),
    Color(0xFF5A6EE6),
    Color(0xFF8246FF),
  ],
  compact: [
    Color(0xFF3C8CC8),
    Color(0xFF3278B4),
    Color(0xFF6450DC),
    Color(0xFF5064FF),
    Color(0xFF7846F0),
    Color(0xFF5A50DC),
    Color(0xFF466EFF),
    Color(0xFF6E5AE6),
  ],
  lineDark: [
    Color(0xFF6450DC),
    Color(0xFF3C78FF),
    Color(0xFF5064C8),
    Color(0xFF8246FF),
    Color(0xFF4682FF),
    Color(0xFF7850FF),
    Color(0xFF5A6EE6),
    Color(0xFF6E5AF0),
    Color(0xFF8C64FF),
  ],
  lineLight: [
    Color(0xFF503CC8),
    Color(0xFF3264DC),
    Color(0xFF465ABE),
    Color(0xFF6E3CDC),
    Color(0xFF3C6EE6),
    Color(0xFF6446F0),
    Color(0xFF5064D2),
    Color(0xFF5A50E1),
    Color(0xFF785AF5),
  ],
  spikeDark: _CP(Color(0xFF6478FF), Color.fromRGBO(130, 100, 220, 0.98)),
  spikeLight: _CP(Color(0xFF3C3CB4), Color(0xFF5064C8)),
  bloomSpikesDark: [
    _CP(Color(0xFF6450FF), Color(0xFF6450FF)),
    _CP(Color.fromRGBO(80, 130, 220, 0.59), Color.fromRGBO(80, 130, 220, 0.29)),
    _CP(Color(0xFF3C64FF), Color(0xFF3C64FF)),
    _CP(Color.fromRGBO(90, 120, 200, 0.91), Color.fromRGBO(90, 120, 200, 0.45)),
    _CP(Color(0xFF785AFF), Color(0xFF785AFF)),
  ],
  bloomSpikesLight: [
    _CP(Color(0xFF3228B4), Color.fromRGBO(50, 40, 180, 0.8)),
    _CP(Color.fromRGBO(40, 80, 200, 0.7), Color.fromRGBO(40, 80, 200, 0.46)),
    _CP(Color(0xFF1E32BE), Color.fromRGBO(30, 50, 190, 0.82)),
    _CP(Color(0xFF3C5AB4), Color.fromRGBO(60, 90, 180, 0.7)),
    _CP(Color(0xFF463CC8), Color.fromRGBO(70, 60, 200, 0.78)),
  ],
);

const _sunsetPalette = _Palette(
  ring: [
    Color(0xFFFF5032),
    Color(0xFFFFA028),
    Color(0xFFFF783C),
    Color(0xFFFFC832),
    Color(0xFFFF6450),
    Color(0xFFFFB43C),
    Color(0xFFFF3C3C),
    Color(0xFFFF8C32),
    Color(0xFFFF5A46),
  ],
  compact: [
    Color(0xFFFFB432),
    Color(0xFFFF9628),
    Color(0xFFFF503C),
    Color(0xFFFF6450),
    Color(0xFFFF3C50),
    Color(0xFFFF783C),
    Color(0xFFFFC832),
    Color(0xFFFF5A46),
  ],
  lineDark: [
    Color(0xFFFF643C),
    Color(0xFFFFB432),
    Color(0xFFFF8C46),
    Color(0xFFFF5050),
    Color(0xFFFFC83C),
    Color(0xFFFF7832),
    Color(0xFFFFA050),
    Color(0xFFFF5A3C),
    Color(0xFFFF4646),
  ],
  lineLight: [
    Color(0xFFDC5028),
    Color(0xFFE6961E),
    Color(0xFFD26E32),
    Color(0xFFC83C3C),
    Color(0xFFDCAA28),
    Color(0xFFD2641E),
    Color(0xFFE6823C),
    Color(0xFFBE4632),
    Color(0xFFB43232),
  ],
  spikeDark: _CP(Color(0xFFFF8C50), Color.fromRGBO(255, 100, 60, 0.98)),
  spikeLight: _CP(Color(0xFFC85028), Color(0xFFDC781E)),
  bloomSpikesDark: [
    _CP(Color(0xFFFF6450), Color(0xFFFF6450)),
    _CP(Color.fromRGBO(255, 150, 80, 0.59), Color.fromRGBO(255, 150, 80, 0.29)),
    _CP(Color(0xFFFF503C), Color(0xFFFF503C)),
    _CP(Color.fromRGBO(255, 120, 50, 0.91), Color.fromRGBO(255, 120, 50, 0.45)),
    _CP(Color(0xFFFF8C46), Color(0xFFFF8C46)),
  ],
  bloomSpikesLight: [
    _CP(Color(0xFFC83C1E), Color.fromRGBO(200, 60, 30, 0.8)),
    _CP(Color.fromRGBO(220, 100, 20, 0.7), Color.fromRGBO(220, 100, 20, 0.46)),
    _CP(Color(0xFFB42814), Color.fromRGBO(180, 40, 20, 0.82)),
    _CP(Color(0xFFD2500A), Color.fromRGBO(210, 80, 10, 0.7)),
    _CP(Color(0xFFBE461E), Color.fromRGBO(190, 70, 30, 0.78)),
  ],
);

// ───────────────────────────── gradient geometry ───────────────────────────
//
// Shared by every palette. Positions are fractions of the painted box,
// radii/offsets are logical pixels — copied 1:1 from the source library.

/// Radial-gradient blob anchored at a fraction of the box.
class _Geom {
  final double fx, fy, w, h;
  const _Geom(this.fx, this.fy, this.w, this.h);
}

/// Ring blobs for [BorderBeamType.full] and [BorderBeamType.pulseInner].
const List<_Geom> _ringGeometry = [
  _Geom(0.33, -0.074, 70, 40),
  _Geom(0.12, -0.05, 60, 35),
  _Geom(0.021, 0.683, 40, 70),
  _Geom(0.021, 0.683, 20, 35),
  _Geom(0.744, 1.0, 180, 32),
  _Geom(0.55, 1.0, 85, 26),
  _Geom(0.939, 0.0, 74, 32),
  _Geom(1.0, 0.271, 26, 42),
  _Geom(1.0, 0.271, 52, 48),
];

/// Blobs for [BorderBeamType.compact].
const List<_Geom> _compactGeometry = [
  _Geom(0.02, 0.68, 9, 18),
  _Geom(0.02, 0.68, 4, 8),
  _Geom(0.72, -0.03, 59, 9),
  _Geom(0.74, 1.0, 42, 7),
  _Geom(1.0, 0.27, 10, 17),
  _Geom(1.0, 0.27, 10, 18),
  _Geom(1.0, 0.27, 5, 10),
  _Geom(1.0, 0.27, 11, 12),
];

/// Inner-glow alphas of the compact blobs (mono halves these).
const List<double> _compactInnerAlpha = [
  0.5,
  0.45,
  0.35,
  0.35,
  0.3,
  0.4,
  0.3,
  0.3,
];

/// Line blob: size in px (scaled by the beam-w/beam-h oscillators), offsets
/// in px from the traveling x-position / bottom edge.
class _LineGeom {
  final double w, h, dx, dy;
  const _LineGeom(this.w, this.h, this.dx, this.dy);
}

const List<_LineGeom> _lineGeometryDark = [
  _LineGeom(36, 36, 0, 2),
  _LineGeom(30, 32, 39, 0),
  _LineGeom(33, 28, -36, 2),
  _LineGeom(29, 34, -54, 0),
  _LineGeom(27, 30, 51, -1),
  _LineGeom(36, 24, 21, 1),
  _LineGeom(30, 22, -21, 0),
  _LineGeom(25, 28, 66, 1),
  _LineGeom(23, 30, -66, -1),
];

const List<_LineGeom> _lineGeometryLight = [
  _LineGeom(45, 36, 0, 2),
  _LineGeom(35, 32, 65, 0),
  _LineGeom(40, 28, -60, 2),
  _LineGeom(35, 34, -90, 0),
  _LineGeom(38, 30, 85, -1),
  _LineGeom(50, 24, 35, 1),
  _LineGeom(40, 22, -35, 0),
  _LineGeom(35, 28, 110, 1),
  _LineGeom(30, 30, -110, -1),
];

/// Line inner-glow geometry; colors come from the palette's dark line list.
const List<_LineGeom> _lineInnerGeometry = [
  _LineGeom(33, 30, 0, 0),
  _LineGeom(24, 26, 39, -3),
  _LineGeom(27, 24, -36, 0),
  _LineGeom(23, 28, -54, -2),
  _LineGeom(24, 24, 51, -1),
  _LineGeom(30, 20, 21, 0),
  _LineGeom(25, 18, -21, -2),
  _LineGeom(21, 24, 66, 0),
  _LineGeom(18, 26, -66, -1),
];

const List<double> _lineInnerAlpha = [
  0.48,
  0.42,
  0.48,
  0.42,
  0.50,
  0.45,
  0.40,
  0.45,
  0.52,
];

// ── pulse tables ──

// Quadrants: 0=tl, 1=tr, 2=bl, 3=br. Regions: 0..2.
const List<int> _pulseRingRegion = [0, 1, 2, 0, 1, 2, 0, 1, 2];
const List<int> _pulseRingQuad = [0, 0, 2, 2, 3, 3, 1, 1, 1];

const List<List<double>> _pulseInnerSizes = [
  [65, 35],
  [55, 30],
  [35, 65],
  [15, 30],
  [173, 28],
  [80, 22],
  [69, 28],
  [22, 38],
  [47, 44],
];

/// Bloom blob referencing a ring color index plus its own size.
class _PulseDef {
  final int ci, region, quad;
  final double w, h;
  const _PulseDef(this.ci, this.region, this.quad, this.w, this.h);
}

const List<_PulseDef> _pulseInnerBloom = [
  _PulseDef(0, 0, 0, 84, 48),
  _PulseDef(1, 1, 0, 72, 42),
  _PulseDef(2, 2, 2, 48, 84),
  _PulseDef(4, 1, 3, 216, 38),
  _PulseDef(5, 2, 3, 102, 31),
  _PulseDef(6, 0, 1, 89, 38),
  _PulseDef(8, 2, 1, 62, 58),
];

class _PulseParams {
  final double sp, dr, op, gh, bs, ss, ghs, huePeriod;
  const _PulseParams(
    this.sp,
    this.dr,
    this.op,
    this.gh,
    this.bs,
    this.ss,
    this.ghs,
    this.huePeriod,
  );
}

_PulseParams _pulseParams(bool isDark, double duration) {
  final durScale = duration / 2.3;
  return _PulseParams(
    0.28,
    isDark ? 33 : 40,
    isDark ? 0.48 : 0.45,
    isDark ? 0.34 : 0.22,
    (isDark ? 1.9 : 2.6) * durScale,
    (isDark ? 2.6 : 4.6) * durScale,
    (isDark ? 2.4 : 5.5) * durScale,
    16,
  );
}

class _PulseVals {
  final List<double> bw, bh, bx, by; // per region 0..2
  final double bgh;
  final List<double> bop; // tl, tr, bl, br
  const _PulseVals(this.bw, this.bh, this.bx, this.by, this.bgh, this.bop);
}

double _pingPong(double phase) => (1 - math.cos(2 * math.pi * phase)) / 2;

double _osc(double t, double a, double b, double period, [double delay = 0]) =>
    a + (b - a) * _pingPong((t - delay) / period);

/// Evaluates the 17 breathing oscillators of the pulse effect at time [t].
_PulseVals _pulseVals(_PulseParams p, double t) {
  final sp = p.sp, dr = p.dr, op = p.op, gh = p.gh;
  final bs = p.bs, ss = p.ss, ghs = p.ghs;
  return _PulseVals(
    [
      _osc(t, 1 - sp, 1 + sp * 1.1, ss * 0.9),
      _osc(t, 1 + sp, 1 - sp * 0.85, ss * 1.1),
      _osc(t, 1 - sp * 0.6, 1 + sp * 1.15, ss * 0.98),
    ],
    [
      _osc(t, 1 + sp * 0.9, 1 - sp * 0.85, ss * 1.26),
      _osc(t, 1 - sp * 0.8, 1 + sp * 1.05, ss * 0.81),
      _osc(t, 1 + sp * 0.75, 1 - sp, ss * 1.4),
    ],
    [
      _osc(t, -dr, dr * 0.9, bs * 1.6),
      _osc(t, dr * 0.8, -dr * 0.9, bs * 1.88),
      _osc(t, -dr * 0.6, dr, bs * 1.45),
    ],
    [
      _osc(t, dr * 0.55, -dr * 0.7, bs * 1.6),
      _osc(t, -dr, dr * 0.65, bs * 1.88),
      _osc(t, -dr * 0.85, dr * 0.45, bs * 1.45),
    ],
    _osc(t, 1 - gh, 1 + gh, ghs),
    [
      _osc(t, 1 - op, 1, bs),
      _osc(t, 1 - op, 1, bs * 1.32, bs * 0.28),
      _osc(t, 1 - op, 1, bs * 0.84, bs * 0.55),
      _osc(t, 1 - op, 1, bs * 1.58, bs * 0.83),
    ],
  );
}

// ───────────────────────── conic gradient stop tables ──────────────────────

// Rotating window mask (stroke layer of full/compact).
const _winStops = [0.0, 0.30, 0.36, 0.44, 0.52, 0.80, 0.86, 0.92, 0.95, 1.0];
const _winAlphas = [0.0, 0.0, 0.1, 0.35, 1.0, 1.0, 0.35, 0.1, 0.0, 0.0];

// Wider window mask for the compact inner-glow layer.
const _compactWinStops = [
  0.0,
  0.22,
  0.28,
  0.36,
  0.46,
  0.82,
  0.88,
  0.94,
  0.97,
  1.0,
];
const _compactWinAlphas = [0.0, 0.0, 0.12, 0.4, 1.0, 1.0, 0.4, 0.12, 0.0, 0.0];

// White traveling beam highlight.
const _beamStops = [
  0.0,
  0.54,
  0.57,
  0.60,
  0.63,
  0.66,
  0.69,
  0.72,
  0.75,
  0.78,
  1.0,
];
const _beamAlphasDark = [
  0.0,
  0.0,
  0.1,
  0.3,
  0.6,
  0.75,
  0.6,
  0.3,
  0.1,
  0.0,
  0.0,
];
const _beamAlphasLight = [
  0.0,
  0.0,
  0.08,
  0.2,
  0.4,
  0.55,
  0.4,
  0.2,
  0.08,
  0.0,
  0.0,
];

// Bloom conic (sharp head at ~70%).
const _bloomStops = [
  0.0,
  0.58,
  0.62,
  0.65,
  0.67,
  0.69,
  0.70,
  0.705,
  0.715,
  0.73,
  0.75,
  0.78,
  0.82,
  1.0,
];
const _bloomAlphasDark = [
  0.0,
  0.0,
  0.03,
  0.08,
  0.2,
  0.45,
  0.85,
  0.85,
  0.45,
  0.2,
  0.08,
  0.03,
  0.0,
  0.0,
];
const _bloomAlphasLight = [
  0.0,
  0.0,
  0.02,
  0.08,
  0.2,
  0.4,
  0.6,
  0.6,
  0.4,
  0.2,
  0.08,
  0.02,
  0.0,
  0.0,
];

// ───────────────────────────── color filter math ───────────────────────────

List<double> _mulMatrix(List<double> a, List<double> b) {
  final out = List<double>.filled(20, 0);
  for (var i = 0; i < 4; i++) {
    for (var j = 0; j < 5; j++) {
      var v = 0.0;
      for (var k = 0; k < 4; k++) {
        v += a[i * 5 + k] * b[k * 5 + j];
      }
      if (j == 4) v += a[i * 5 + 4];
      out[i * 5 + j] = v;
    }
  }
  return out;
}

List<double> _hueMatrix(double deg) {
  final r = deg * math.pi / 180;
  final c = math.cos(r), s = math.sin(r);
  return [
    0.213 + c * 0.787 - s * 0.213,
    0.715 - c * 0.715 - s * 0.715,
    0.072 - c * 0.072 + s * 0.928,
    0,
    0,
    0.213 - c * 0.213 + s * 0.143,
    0.715 + c * 0.285 + s * 0.140,
    0.072 - c * 0.072 - s * 0.283,
    0,
    0,
    0.213 - c * 0.213 - s * 0.787,
    0.715 - c * 0.715 + s * 0.715,
    0.072 + c * 0.928 + s * 0.072,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _saturateMatrix(double s) {
  return [
    0.213 + 0.787 * s,
    0.715 - 0.715 * s,
    0.072 - 0.072 * s,
    0,
    0,
    0.213 - 0.213 * s,
    0.715 + 0.285 * s,
    0.072 - 0.072 * s,
    0,
    0,
    0.213 - 0.213 * s,
    0.715 - 0.715 * s,
    0.072 + 0.928 * s,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _brightnessMatrix(double b) {
  return [b, 0, 0, 0, 0, 0, b, 0, 0, 0, 0, 0, b, 0, 0, 0, 0, 0, 1, 0];
}

/// CSS `filter: hue-rotate(h) brightness(b) saturate(s)` (applied in order).
List<double> _filterMatrix(double hueDeg, double b, double s) {
  var m = _hueMatrix(hueDeg);
  m = _mulMatrix(_brightnessMatrix(b), m);
  m = _mulMatrix(_saturateMatrix(s), m);
  return m;
}

// ─────────────────────────────── painter ───────────────────────────────────

class _BeamPainter extends CustomPainter {
  final _ResolvedBeam cfg;
  final _BorderBeamState state;

  _BeamPainter(this.cfg, this.state) : super(repaint: state._frame);

  @override
  void paint(Canvas canvas, Size size) {
    final fade = state._fade;
    if (fade <= 0 || cfg.strength <= 0) return;
    if (size.width <= 0 || size.height <= 0) return;
    _BeamRenderer(cfg, state._t, fade).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _BeamPainter oldDelegate) => true;

  // The effect is purely decorative and must never intercept pointer events.
  @override
  bool? hitTest(Offset position) => false;
}

class _BeamRenderer {
  final _ResolvedBeam cfg;
  final double t;
  final double fade;

  _BeamRenderer(this.cfg, this.t, this.fade);

  /// CSS clamps oversized border radii to the box; RRect does not, so clamp.
  RRect _rrect(Size size) => RRect.fromRectAndRadius(
    Offset.zero & size,
    Radius.circular(math.min(cfg.radius, size.shortestSide / 2)),
  );

  void paint(Canvas canvas, Size size) {
    switch (cfg.type) {
      case BorderBeamType.full:
      case BorderBeamType.compact:
        _paintRotate(canvas, size);
        break;
      case BorderBeamType.line:
        _paintLine(canvas, size);
        break;
      case BorderBeamType.pulseInner:
        _paintPulseInner(canvas, size);
        break;
    }
  }

  // ── shared drawing helpers ──

  /// One effect layer: opacity + (filter) + content, then mask AFTER the
  /// filter (matching the CSS pipeline: filter -> clip -> mask).
  void _layer(
    Canvas canvas,
    Rect bounds, {
    required double opacity,
    List<double>? colorMatrix,
    double blurSigma = 0,
    required void Function(Canvas) content,
    void Function(Canvas)? mask,
  }) {
    final o = opacity.clamp(0.0, 1.0);
    if (o <= 0) return;
    canvas.saveLayer(bounds, Paint()..color = Color.fromRGBO(0, 0, 0, o));
    if (colorMatrix != null || blurSigma > 0) {
      final p = Paint();
      if (colorMatrix != null) p.colorFilter = ColorFilter.matrix(colorMatrix);
      if (blurSigma > 0) {
        p.imageFilter = ui.ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
          tileMode: TileMode.decal,
        );
      }
      canvas.saveLayer(bounds, p);
      content(canvas);
      canvas.restore();
    } else {
      content(canvas);
    }
    if (mask != null) {
      canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.dstIn);
      mask(canvas);
      canvas.restore();
    }
    canvas.restore();
  }

  void _maskGroup(Canvas canvas, Rect bounds, void Function(Canvas) draw) {
    canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.dstIn);
    draw(canvas);
    canvas.restore();
  }

  /// radial-gradient(ellipse RXpx RYpx at (cx, cy), ...stops).
  void _ellipse(
    Canvas canvas,
    Rect fill, {
    required double cx,
    required double cy,
    required double rx,
    required double ry,
    Color? color,
    List<Color>? colors,
    List<double>? stops,
  }) {
    if (rx <= 0 || ry <= 0) return;
    final m = Matrix4.identity()
      ..translateByDouble(cx, cy, 0, 1)
      ..scaleByDouble(rx, ry, 1, 1);
    final cs = colors ?? [color!, color.withValues(alpha: 0)];
    final ss = stops ?? const [0.0, 1.0];
    final shader = ui.Gradient.radial(
      Offset.zero,
      1.0,
      cs,
      ss,
      TileMode.clamp,
      m.storage,
    );
    canvas.drawRect(fill, Paint()..shader = shader);
  }

  /// conic-gradient(from angleDeg at center) — CSS 0deg at top, clockwise.
  void _conic(
    Canvas canvas,
    Rect fill,
    Rect box,
    Color base,
    List<double> alphas,
    List<double> stops,
    double angleDeg,
  ) {
    final c = box.center;
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..rotateZ((angleDeg - 90) * math.pi / 180)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    final colors = [
      for (final a in alphas) base.withValues(alpha: a.clamp(0.0, 1.0)),
    ];
    final shader = ui.Gradient.sweep(
      c,
      colors,
      stops,
      TileMode.clamp,
      0,
      math.pi * 2,
      m.storage,
    );
    canvas.drawRect(fill, Paint()..shader = shader);
  }

  /// The 1px border ring (mask xor content-box in CSS).
  Path _ringPath(RRect outer, double width) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(outer)
      ..addRRect(outer.deflate(width));
  }

  /// linear-gradient(white, transparent 28px, transparent 100%-28px, white)
  /// vertical + `to right` horizontal, composited with `add` (union).
  void _edgeFrameMask(Canvas canvas, Rect fill, Rect box) {
    const inset = 28.0;
    void draw(Offset from, Offset to, double len) {
      final f = (inset / len).clamp(0.0, 0.5);
      final shader = ui.Gradient.linear(
        from,
        to,
        [
          Colors.white,
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0),
          Colors.white,
        ],
        [0.0, f, 1.0 - f, 1.0],
      );
      canvas.drawRect(fill, Paint()..shader = shader);
    }

    draw(box.topLeft, box.bottomLeft, box.height);
    draw(box.topLeft, box.topRight, box.width);
  }

  /// CSS `box-shadow: inset 0 0 {blur}px {spread}px {color}`.
  void _innerShadow(
    Canvas canvas,
    RRect rrect,
    Color color,
    double blur,
    double spread,
  ) {
    if (color.a == 0) return;
    canvas.save();
    canvas.clipRRect(rrect);
    final w = blur + spread * 2;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2);
    canvas.drawRRect(rrect.inflate(w / 2 - spread), p);
    canvas.restore();
  }

  /// Piecewise-keyframe interpolation (CSS @keyframes).
  double _kf(
    double phase,
    List<double> keys,
    List<double> vals, {
    bool easeInOut = false,
  }) {
    final p = phase.clamp(0.0, 1.0);
    for (var i = 0; i < keys.length - 1; i++) {
      if (p <= keys[i + 1]) {
        final span = keys[i + 1] - keys[i];
        var u = span <= 0 ? 1.0 : (p - keys[i]) / span;
        if (easeInOut) u = Curves.easeInOut.transform(u.clamp(0.0, 1.0));
        return vals[i] + (vals[i + 1] - vals[i]) * u;
      }
    }
    return vals.last;
  }

  double get _monoMul => cfg.isMono ? 0.5 : 1.0;

  // ── rotate family (full / compact) ──

  void _paintRotate(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = _rrect(size);
    final isCompact = cfg.type == BorderBeamType.compact;
    final angle = (t / cfg.duration % 1) * 360;
    final palette = cfg.palette;

    // 12s ease-in-out hue ping-pong.
    final List<double>? matrix = cfg.staticColors
        ? null
        : _filterMatrix(
            _osc(t, -cfg.hueRange, cfg.hueRange, 12),
            cfg.brightness,
            cfg.saturation,
          );
    final bloomMatrix = _filterMatrix(0, cfg.brightness, cfg.saturation);

    canvas.save();
    canvas.clipRRect(rrect); // wrapper overflow: hidden

    final geometry = isCompact ? _compactGeometry : _ringGeometry;
    final colors = isCompact ? palette.compact : palette.ring;

    // Inner glow layer.
    _layer(
      canvas,
      rect,
      opacity: fade * cfg.innerOpacity * _monoMul * cfg.strength,
      colorMatrix: matrix,
      content: (c) {
        if (isCompact) {
          for (var i = geometry.length - 1; i >= 0; i--) {
            final g = geometry[i];
            _ellipse(
              c,
              rect,
              cx: g.fx * size.width,
              cy: g.fy * size.height,
              rx: g.w,
              ry: g.h,
              color: colors[i].withValues(
                alpha: _compactInnerAlpha[i] * _monoMul,
              ),
            );
          }
          _innerShadow(c, rrect, cfg.innerShadow, 5, 1);
        } else {
          final alpha = 0.45 * _monoMul;
          for (var i = geometry.length - 1; i >= 0; i--) {
            final g = geometry[i];
            _ellipse(
              c,
              rect,
              cx: g.fx * size.width,
              cy: g.fy * size.height,
              rx: (g.w * 0.9).roundToDouble(),
              ry: (g.h * 0.9).roundToDouble(),
              color: colors[i].withValues(alpha: alpha),
            );
          }
          _innerShadow(c, rrect, cfg.innerShadow, 9, 1);
        }
      },
      mask: (c) {
        if (isCompact) {
          _conic(
            c,
            rect,
            rect,
            Colors.white,
            _compactWinAlphas,
            _compactWinStops,
            angle,
          );
        } else {
          _edgeFrameMask(c, rect, rect);
          _maskGroup(c, rect, (c2) {
            _conic(c2, rect, rect, Colors.white, _winAlphas, _winStops, angle);
          });
        }
      },
    );

    // Beam stroke on the 1px border ring.
    _layer(
      canvas,
      rect,
      opacity: fade * cfg.strokeOpacity * _monoMul * cfg.strength,
      colorMatrix: matrix,
      content: (c) {
        c.save();
        c.clipPath(_ringPath(rrect, cfg.borderWidth));
        for (var i = geometry.length - 1; i >= 0; i--) {
          final g = geometry[i];
          _ellipse(
            c,
            rect,
            cx: g.fx * size.width,
            cy: g.fy * size.height,
            rx: g.w,
            ry: g.h,
            color: colors[i],
          );
        }
        _conic(
          c,
          rect,
          rect,
          cfg.isDark ? Colors.white : Colors.black,
          cfg.isDark ? _beamAlphasDark : _beamAlphasLight,
          _beamStops,
          angle,
        );
        c.restore();
      },
      mask: (c) {
        _conic(c, rect, rect, Colors.white, _winAlphas, _winStops, angle);
      },
    );

    // Bloom: blurred conic, masked to the ring AFTER the blur.
    _layer(
      canvas,
      rect,
      opacity: fade * cfg.bloomOpacity * _monoMul * cfg.strength,
      colorMatrix: bloomMatrix,
      blurSigma: 8,
      content: (c) {
        _conic(
          c,
          rect,
          rect,
          cfg.isDark ? Colors.white : Colors.black,
          cfg.isDark ? _bloomAlphasDark : _bloomAlphasLight,
          _bloomStops,
          angle,
        );
      },
      mask: (c) {
        c.drawPath(
          _ringPath(rrect, cfg.borderWidth),
          Paint()..color = Colors.white,
        );
      },
    );

    canvas.restore();
  }

  // ── line type ──

  void _paintLine(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = _rrect(size);
    final w0 = size.width, h0 = size.height;
    final dur = cfg.duration;
    final isMono = cfg.isMono;
    final palette = cfg.palette;

    // Keyframed custom properties.
    final travel = (t / dur) % 1;
    final x = _kf(
      travel,
      const [0, .1, .2, .3, .4, .5, .6, .7, .8, .9, 1],
      const [.06, .15, .25, .35, .44, .5, .56, .65, .75, .85, .94],
    );
    final bw = _kf(
      travel,
      const [0, .1, .2, .3, .4, .5, .6, .7, .8, .9, 1],
      const [.5, .8, 1.1, 1.3, 1.45, 1.5, 1.45, 1.3, 1.1, .8, .5],
    );
    final edge = _kf(
      travel,
      const [0, .125, .325, .675, .875, 1],
      const [0, 0, 1, 1, 0, 0],
    );
    final bh = _kf(
      (t / (dur * 1.3)) % 1,
      const [0, .25, .55, .80, 1],
      const [.8, 1.25, .85, 1.3, .8],
      easeInOut: true,
    );
    final spike = _kf(
      (t / (dur * 1.33)) % 1,
      const [0, .25, .5, .75, 1],
      const [.8, 1.3, .9, 1.4, .8],
      easeInOut: true,
    );
    final spike2 = _kf(
      (t / (dur * 1.7)) % 1,
      const [0, .25, .5, .75, 1],
      const [1.2, .7, 1.4, .8, 1.2],
      easeInOut: true,
    );

    final beamX = x * w0;

    final List<double>? matrix = cfg.staticColors
        ? null
        : _filterMatrix(
            _osc(t, -cfg.hueRange, cfg.hueRange, 12),
            cfg.brightness,
            cfg.saturation,
          );
    // Bloom hue-shift: blur(8) + hue ±(range+10) over 8s.
    final List<double>? bloomMatrix = cfg.staticColors
        ? null
        : _filterMatrix(
            _osc(t, -(cfg.hueRange + 10), cfg.hueRange + 10, 8),
            cfg.brightness,
            cfg.saturation,
          );

    void radialMask(
      Canvas c,
      double rx,
      double ry,
      double midAlpha,
      double midStop,
    ) {
      _ellipse(
        c,
        rect,
        cx: beamX,
        cy: h0,
        rx: rx,
        ry: ry,
        colors: [
          Colors.white,
          Colors.white.withValues(alpha: midAlpha),
          Colors.white.withValues(alpha: 0),
        ],
        stops: [0, midStop, 1],
      );
    }

    canvas.save();
    canvas.clipRRect(rrect);

    // Inner glow layer.
    _layer(
      canvas,
      rect,
      opacity: fade * edge * cfg.innerOpacity * cfg.strength,
      colorMatrix: matrix,
      content: (c) {
        for (var i = _lineInnerGeometry.length - 1; i >= 0; i--) {
          final g = _lineInnerGeometry[i];
          _ellipse(
            c,
            rect,
            cx: beamX + g.dx,
            cy: h0 - g.dy.abs(),
            rx: g.w * bw,
            ry: g.h * bh,
            color: palette.lineDark[i].withValues(alpha: _lineInnerAlpha[i]),
          );
        }
        _innerShadow(c, rrect, cfg.innerShadow, 9, 1);
      },
      mask: (c) {
        _edgeFrameMask(c, rect, rect);
        _maskGroup(
          c,
          rect,
          (c2) => radialMask(c2, 78 * bw, 60 * bh, 0.5, 0.45),
        );
      },
    );

    // Beam stroke on the border ring.
    final lineGeometry = cfg.isDark ? _lineGeometryDark : _lineGeometryLight;
    final lineColors = cfg.isDark ? palette.lineDark : palette.lineLight;
    _layer(
      canvas,
      rect,
      opacity: fade * edge * cfg.strokeOpacity * cfg.strength,
      colorMatrix: matrix,
      content: (c) {
        c.save();
        c.clipPath(_ringPath(rrect, cfg.borderWidth));
        for (var i = lineGeometry.length - 1; i >= 0; i--) {
          final g = lineGeometry[i];
          _ellipse(
            c,
            rect,
            cx: beamX + g.dx,
            cy: h0 + g.dy,
            rx: g.w * bw,
            ry: g.h * bh,
            color: lineColors[i],
          );
        }
        // White traveling highlight.
        if (cfg.isDark) {
          _ellipse(
            c,
            rect,
            cx: beamX,
            cy: h0 + 2,
            rx: 24 * bw,
            ry: 28 * bh,
            colors: [
              Colors.white.withValues(alpha: 0.38),
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0, 0.30, 0.65],
          );
        } else {
          _ellipse(
            c,
            rect,
            cx: beamX,
            cy: h0 + 2,
            rx: 35 * bw,
            ry: 28 * bh,
            colors: [
              Colors.black.withValues(alpha: 0.6),
              Colors.black.withValues(alpha: 0.25),
              Colors.black.withValues(alpha: 0),
            ],
            stops: const [0, 0.35, 0.70],
          );
        }
        c.restore();
      },
      mask: (c) => radialMask(c, 78 * bw, 60 * bh, 0.5, 0.45),
    );

    // Bloom: spikes + traveling dot, masked after the blur.
    _layer(
      canvas,
      rect,
      opacity: fade * edge * cfg.bloomOpacity * cfg.strength,
      colorMatrix: bloomMatrix,
      blurSigma: cfg.staticColors ? (isMono ? 6 : 0) : 8,
      content: (c) =>
          _paintLineBloom(c, rect, w0, h0, beamX, bw, bh, spike, spike2),
      mask: (c) => radialMask(c, 84 * bw, 110 * bh, 0.5, 0.35),
    );

    canvas.restore();
  }

  void _paintLineBloom(
    Canvas c,
    Rect rect,
    double w0,
    double h0,
    double beamX,
    double bw,
    double bh,
    double spike,
    double spike2,
  ) {
    final isMono = cfg.isMono;
    final isDark = cfg.isDark;
    final sc = isDark ? cfg.palette.spikeDark : cfg.palette.spikeLight;

    Color att(Color color, double f) =>
        color.withValues(alpha: (color.a * f).clamp(0.0, 1.0));

    final sc1 = isMono ? att(sc.a, 0.14) : sc.a;
    final sc1Mid = isMono
        ? att(sc.a, 0.09)
        : (isDark ? sc.a : sc.a.withValues(alpha: 0.85));
    final sc2 = isMono ? att(sc.b, 0.12) : sc.b;
    final sc2Mid = isMono
        ? sc.b.withValues(alpha: 0.06)
        : (isDark ? sc.b.withValues(alpha: 0.49) : sc.b.withValues(alpha: 0.7));

    final rawSpikes = isDark
        ? cfg.palette.bloomSpikesDark
        : cfg.palette.bloomSpikesLight;
    final spikes = isMono
        ? [for (final s in rawSpikes) _CP(att(s.a, 0.14), att(s.b, 0.14 * 0.7))]
        : rawSpikes;

    final thinW1 = isMono ? 12.0 : 0.8;
    final thinW2 = isMono ? 14.0 : 2.0;
    final thinW3 = isMono ? 12.0 : 1.2;
    final thinW4 = isMono ? 10.0 : 0.6;
    final thinH1 = isMono ? 42.0 : 92.0;
    final thinH2 = isMono ? 38.0 : 72.0;
    final thinH3 = isMono ? 40.0 : 85.0;
    final thinH4 = isMono ? 32.0 : 60.0;
    final thinLW = isMono ? 12.0 : 1.0;

    void spikeGrad(
      double fx,
      double dy,
      double rx,
      double ry,
      Color c1,
      Color c2,
      double midStop,
      double endStop,
    ) {
      _ellipse(
        c,
        rect,
        cx: fx * w0,
        cy: h0 - dy,
        rx: rx,
        ry: ry,
        colors: [c1, c2, c2.withValues(alpha: 0)],
        stops: [0, midStop, endStop],
      );
    }

    // Painted bottom-up (CSS multiple backgrounds: first listed is topmost).
    if (isDark) {
      // Ambient white glow.
      _ellipse(
        c,
        rect,
        cx: beamX,
        cy: h0,
        rx: 42 * bw,
        ry: 40 * bh,
        colors: [
          Colors.white.withValues(alpha: isMono ? 0.15 : 0.3),
          Colors.white.withValues(alpha: isMono ? 0.06 : 0.12),
          Colors.white.withValues(alpha: isMono ? 0.015 : 0.03),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, 0.25, 0.55, 0.80],
      );
      // Center dot.
      _ellipse(
        c,
        rect,
        cx: beamX,
        cy: h0 + 1,
        rx: 21 * spike,
        ry: 15 * spike2,
        colors: [
          Colors.white.withValues(alpha: isMono ? 0.5 : 1.0),
          Colors.white.withValues(alpha: isMono ? 0.45 : 0.9),
          Colors.white.withValues(alpha: isMono ? 0.25 : 0.5),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, 0.2, 0.5, 1.0],
      );
      spikeGrad(
        0.92,
        3,
        thinW4 * (2 - spike),
        thinH4 * bh,
        spikes[4].a,
        spikes[4].b,
        0.42,
        0.91,
      );
      spikeGrad(
        0.78,
        2,
        7 * spike,
        45 * bh,
        spikes[3].a,
        spikes[3].b,
        0.48,
        0.94,
      );
      spikeGrad(
        0.64,
        4,
        thinW3 * (2 - spike2),
        thinH3 * bh,
        spikes[2].a,
        spikes[2].b,
        0.35,
        0.89,
      );
      spikeGrad(
        0.50,
        2,
        14 * spike2,
        28 * bh,
        spikes[1].a,
        spikes[1].b,
        0.55,
        0.96,
      );
      spikeGrad(
        0.36,
        3,
        thinW2 * (2 - spike),
        thinH2 * bh,
        spikes[0].a,
        spikes[0].b,
        0.40,
        0.90,
      );
      spikeGrad(0.22, 4, 10 * spike2, 35 * bh, sc2, sc2Mid, 0.50, 0.95);
      spikeGrad(0.08, 2, thinW1 * spike, thinH1 * bh, sc1, sc1Mid, 0.30, 0.88);
    } else {
      // Light theme: bottom shadow instead of white ambient.
      _ellipse(
        c,
        rect,
        cx: beamX,
        cy: h0,
        rx: 50 * bw,
        ry: 32 * bh,
        colors: [
          Colors.black.withValues(alpha: 0.5),
          Colors.black.withValues(alpha: 0.18),
          Colors.black.withValues(alpha: 0.03),
          Colors.black.withValues(alpha: 0),
        ],
        stops: const [0, 0.30, 0.60, 0.85],
      );
      spikeGrad(
        0.92,
        3,
        thinLW * (2 - spike),
        thinH4 * bh,
        spikes[4].a,
        spikes[4].b,
        0.42,
        0.91,
      );
      spikeGrad(
        0.78,
        2,
        7 * spike,
        45 * bh,
        spikes[3].a,
        spikes[3].b,
        0.48,
        0.94,
      );
      spikeGrad(
        0.64,
        4,
        thinW3 * (2 - spike2),
        thinH3 * bh,
        spikes[2].a,
        spikes[2].b,
        0.35,
        0.89,
      );
      spikeGrad(
        0.50,
        2,
        14 * spike2,
        28 * bh,
        spikes[1].a,
        spikes[1].b,
        0.55,
        0.96,
      );
      spikeGrad(
        0.36,
        3,
        thinW2 * (2 - spike),
        thinH2 * bh,
        spikes[0].a,
        spikes[0].b,
        0.40,
        0.90,
      );
      spikeGrad(0.22, 4, 10 * spike2, 35 * bh, sc2, sc2Mid, 0.50, 0.95);
      spikeGrad(0.08, 2, thinW1 * spike, thinH1 * bh, sc1, sc1Mid, 0.30, 0.88);
    }
  }

  // ── pulse type ──

  void _pulseBlob(
    Canvas c,
    Rect fill,
    Rect posBox,
    Color color,
    double fx,
    double fy,
    double w,
    double h,
    int region,
    int quad,
    _PulseVals v,
  ) {
    _ellipse(
      c,
      fill,
      cx: posBox.left + fx * posBox.width + v.bx[region],
      cy: posBox.top + fy * posBox.height + v.by[region],
      rx: w * v.bw[region],
      ry: h * v.bh[region] * v.bgh,
      color: color.withValues(alpha: v.bop[quad].clamp(0.0, 1.0)),
    );
  }

  void _paintPulseInner(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = _rrect(size);
    final p = _pulseParams(cfg.isDark, cfg.duration);
    final v = _pulseVals(p, t);
    final palette = cfg.palette.ring;
    // The upstream library spins the pulse hue through a full 360° circle,
    // which pushes themed palettes (ocean, sunset) through foreign colors.
    // Use the same gentle ping-pong drift as the other types instead, so
    // every palette keeps its identity.
    final hue = cfg.staticColors
        ? 0.0
        : _osc(t, -cfg.hueRange, cfg.hueRange, p.huePeriod);
    final matrix = _filterMatrix(hue, cfg.brightness, cfg.saturation);

    canvas.save();
    canvas.clipRRect(rrect);

    // Perimeter ring.
    _layer(
      canvas,
      rect,
      opacity: fade * cfg.strokeOpacity * _monoMul * cfg.strength,
      colorMatrix: matrix,
      content: (c) {
        c.save();
        c.clipPath(_ringPath(rrect, cfg.borderWidth));
        for (var i = palette.length - 1; i >= 0; i--) {
          final g = _ringGeometry[i];
          _pulseBlob(
            c,
            rect,
            rect,
            palette[i],
            g.fx,
            g.fy,
            g.w,
            g.h,
            _pulseRingRegion[i],
            _pulseRingQuad[i],
            v,
          );
        }
        c.restore();
      },
    );

    // Inner perimeter + corner accents.
    _layer(
      canvas,
      rect,
      opacity: fade * cfg.innerOpacity * _monoMul * cfg.strength,
      colorMatrix: matrix,
      content: (c) {
        final cornerColor = cfg.isDark ? Colors.white : Colors.black;
        final cornerAlpha = cfg.isDark ? 0.18 : 0.08;
        const corners = [
          (0.0, 0.0, 0),
          (1.0, 0.0, 1),
          (0.0, 1.0, 2),
          (1.0, 1.0, 3),
        ];
        for (final (fx, fy, q) in corners.reversed) {
          _ellipse(
            c,
            rect,
            cx: fx * size.width,
            cy: fy * size.height,
            rx: 60,
            ry: 60,
            colors: [
              cornerColor.withValues(
                alpha: (cornerAlpha * v.bop[q]).clamp(0.0, 1.0),
              ),
              cornerColor.withValues(alpha: 0),
            ],
            stops: const [0, 0.7],
          );
        }
        for (var i = palette.length - 1; i >= 0; i--) {
          final g = _ringGeometry[i];
          _pulseBlob(
            c,
            rect,
            rect,
            palette[i],
            g.fx,
            g.fy,
            _pulseInnerSizes[i][0],
            _pulseInnerSizes[i][1],
            _pulseRingRegion[i],
            _pulseRingQuad[i],
            v,
          );
        }
      },
      mask: (c) => _edgeFrameMask(c, rect, rect),
    );

    // Bloom: frozen-alpha gradients, blurred, masked to the ring.
    final frozen = 1 - p.op * 0.5;
    _layer(
      canvas,
      rect,
      opacity: fade * cfg.bloomOpacity * _monoMul * cfg.strength,
      colorMatrix: matrix,
      blurSigma: 8,
      content: (c) {
        for (final d in _pulseInnerBloom.reversed) {
          final g = _ringGeometry[d.ci];
          _ellipse(
            c,
            rect,
            cx: g.fx * size.width,
            cy: g.fy * size.height,
            rx: d.w,
            ry: d.h,
            color: palette[d.ci].withValues(alpha: frozen),
          );
        }
      },
      mask: (c) {
        c.drawPath(
          _ringPath(rrect, cfg.borderWidth),
          Paint()..color = Colors.white,
        );
      },
    );

    canvas.restore();
  }
}
