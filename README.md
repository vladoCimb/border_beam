# beam_border

Animated border beam effect for Flutter. A lightweight widget that adds animated border beam effect around any element.

Flutter version of [Border Beam](https://beam.jakubantalik.com) — open the page to preview how the effect looks.

## Features

- **Four effect types** — full border beam, compact beam for small elements,
  bottom-line glow for search bars, and a breathing pulse.
- **Built-in palettes** — colorful (rainbow), mono (grayscale), ocean
  (blue/purple), sunset (warm tones) — or bring your own colors.
- **Theme aware** — tuned presets for dark and light backgrounds, with
  automatic detection.
- **Non-intrusive** — the effect is painted around your widget; it never
  wraps it in extra layout, clips it, or intercepts pointer events.
- **Pure Dart/Flutter** — no dependencies, works on every platform.

## Getting started

Add the dependency:

```yaml
dependencies:
  beam_border: ^1.0.0
```

## Usage

Wrap any widget with `BorderBeam`:

```dart
import 'package:beam_border/beam_border.dart';

BorderBeam(
  child: Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: const Color(0xFF1D1D1D),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Text('Your content here'),
  ),
)
```

Pass a `borderRadius` matching your child's decoration so the beam hugs the
same rounded corners.

### Types

```dart
BorderBeam(type: BorderBeamType.full, ...)       // full border glow (default)
BorderBeam(type: BorderBeamType.compact, ...)    // small buttons, chips
BorderBeam(type: BorderBeamType.line, ...)       // bottom glow for search bars
BorderBeam(type: BorderBeamType.pulseInner, ...) // breathing glow, no travel
```

### Color variants

```dart
BorderBeam(colorVariant: BorderBeamColorVariant.colorful, ...) // default
BorderBeam(colorVariant: BorderBeamColorVariant.mono, ...)
BorderBeam(colorVariant: BorderBeamColorVariant.ocean, ...)
BorderBeam(colorVariant: BorderBeamColorVariant.sunset, ...)
```

### Custom colors

Use your own palette. Colors are distributed cyclically over the gradient
slots of the effect, so any number of colors works, and they are rendered
exactly as supplied (the hue-shift animation of the built-in palettes is
disabled for custom colors):

```dart
BorderBeam(
  colorVariant: BorderBeamColorVariant.custom,
  customColors: const [Colors.cyan, Colors.deepPurple, Colors.pink],
  child: ...,
)
```

### Theme

```dart
BorderBeam(theme: BorderBeamTheme.dark, ...)  // dark backgrounds (default)
BorderBeam(theme: BorderBeamTheme.light, ...) // light backgrounds
BorderBeam(theme: BorderBeamTheme.auto, ...)  // follows Theme.of(context)
```

### Strength

Control the overall intensity without affecting the wrapped content:

```dart
BorderBeam(strength: 0.7, ...) // 70% intensity, 0..1
```

### Play / pause

Toggle the animation with a smooth fade:

```dart
BorderBeam(active: isSearching, ...)
```

## Parameters

| Parameter      | Type                     | Default      | Description                                     |
| -------------- | ------------------------ | ------------ | ----------------------------------------------- |
| `child`        | `Widget`                 | required     | Content to wrap                                 |
| `type`         | `BorderBeamType`         | `full`       | Effect type preset                              |
| `colorVariant` | `BorderBeamColorVariant` | `colorful`   | Color palette                                   |
| `customColors` | `List<Color>?`           | —            | Palette for the `custom` variant                |
| `theme`        | `BorderBeamTheme`        | `dark`       | Background adaptation                           |
| `strength`     | `double`                 | `1`          | Effect opacity (0–1), beam layers only          |
| `duration`     | `Duration?`              | per type     | Animation cycle duration                        |
| `active`       | `bool`                   | `true`       | Whether the animation is playing                |
| `borderRadius` | `double?`                | per type     | Corner radius in logical pixels                 |

## How it works

`BorderBeam` paints three decorative layers above your child, mirroring the

- **stroke** — gradient blobs masked to a 1 px border ring, revealed by a
  rotating conic window;
- **inner glow** — softer gradients framed to the edges of the element;
- **bloom** — a blurred highlight that trails the beam head.

All layers are painted by a `foregroundPainter`, respect the configured
border radius, and return `false` from hit testing, so they never interfere
with taps, focus, or semantics of the wrapped widget.

## License

MIT — see [LICENSE](LICENSE).
