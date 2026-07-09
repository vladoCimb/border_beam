# Changelog

## 1.0.1

- Update repository URL in package metadata.

## 1.0.0

Initial release.

- `BorderBeam` widget that wraps any child with an animated border beam
  effect, rendered with a single `CustomPainter` (no extra widgets in the
  tree, no clipping of the child).
- Four effect types:
  - `BorderBeamType.full` — traveling beam around the full border.
  - `BorderBeamType.compact` — compact beam for small, button-sized elements.
  - `BorderBeamType.line` — bottom-only traveling glow with breathe and
    spike accents.
  - `BorderBeamType.pulseInner` — breathing glow contained within the border.
- Four built-in color palettes (`colorful`, `mono`, `ocean`, `sunset`) plus
  fully custom palettes through `BorderBeamColorVariant.custom` and
  `customColors`.
- Dark, light, and automatic theme adaptation.
- `strength`, `duration`, `active` (with smooth fade in/out), and
  `borderRadius` options.
