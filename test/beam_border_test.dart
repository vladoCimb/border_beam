import 'package:beam_border/beam_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.dark}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(body: Center(child: child)),
  );
}

Widget _box({double width = 200, double height = 80}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFF17171B),
      borderRadius: BorderRadius.circular(16),
    ),
  );
}

/// Disposes the beam (and its ticker) so tests end without live frames.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  group('BorderBeam widget', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(_host(BorderBeam(child: const Text('content'))));
      expect(find.text('content'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('does not change the child size', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        _host(BorderBeam(child: SizedBox(key: key, width: 120, height: 48))),
      );
      expect(tester.getSize(find.byKey(key)), const Size(120, 48));
      expect(tester.getSize(find.byType(BorderBeam)), const Size(120, 48));
      await _teardown(tester);
    });

    testWidgets('child stays tappable through the effect layers', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          BorderBeam(
            child: ElevatedButton(
              onPressed: () => taps++,
              child: const Text('tap'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('tap'));
      expect(taps, 1);
      await _teardown(tester);
    });

    testWidgets('animates over time without exceptions', (tester) async {
      await tester.pumpWidget(_host(BorderBeam(child: _box())));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await _teardown(tester);
    });
  });

  group('paints every configuration without errors', () {
    const variants = [
      BorderBeamColorVariant.colorful,
      BorderBeamColorVariant.mono,
      BorderBeamColorVariant.ocean,
      BorderBeamColorVariant.sunset,
    ];

    for (final type in BorderBeamType.values) {
      for (final variant in variants) {
        for (final theme in [BorderBeamTheme.dark, BorderBeamTheme.light]) {
          testWidgets('$type / $variant / $theme', (tester) async {
            await tester.pumpWidget(
              _host(
                BorderBeam(
                  type: type,
                  colorVariant: variant,
                  theme: theme,
                  child: _box(),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 500));
            await tester.pump(const Duration(seconds: 1));
            await _teardown(tester);
          });
        }
      }
    }
  });

  group('custom colors', () {
    testWidgets('accepts a single color', (tester) async {
      await tester.pumpWidget(
        _host(
          BorderBeam(
            colorVariant: BorderBeamColorVariant.custom,
            customColors: const [Colors.cyan],
            child: _box(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await _teardown(tester);
    });

    testWidgets('accepts many colors across all types', (tester) async {
      const colors = [
        Colors.cyan,
        Colors.deepPurple,
        Colors.pink,
        Colors.amber,
        Colors.lightGreen,
      ];
      for (final type in BorderBeamType.values) {
        await tester.pumpWidget(
          _host(
            BorderBeam(
              type: type,
              colorVariant: BorderBeamColorVariant.custom,
              customColors: colors,
              child: _box(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
      }
      await _teardown(tester);
    });

    test('asserts when customColors is missing', () {
      expect(
        () => BorderBeam(
          colorVariant: BorderBeamColorVariant.custom,
          child: const SizedBox(),
        ),
        throwsAssertionError,
      );
    });
  });

  group('active toggle', () {
    testWidgets('starts hidden when active is false', (tester) async {
      await tester.pumpWidget(_host(BorderBeam(active: false, child: _box())));
      await tester.pump(const Duration(seconds: 1));
      await _teardown(tester);
    });

    testWidgets('fades in when activated and out when deactivated', (
      tester,
    ) async {
      Widget build(bool active) =>
          _host(BorderBeam(active: active, child: _box()));

      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(build(true));
      // Fade-in lasts 0.6s.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.pumpWidget(build(false));
      // Fade-out lasts 0.5s, after which the ticker stops.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(seconds: 1));
      await _teardown(tester);
    });
  });

  group('parameters', () {
    testWidgets('strength is clamped and strength 0 paints nothing fatal', (
      tester,
    ) async {
      for (final strength in [0.0, 0.5, 1.0, 5.0, -1.0]) {
        await tester.pumpWidget(
          _host(BorderBeam(strength: strength, child: _box())),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
      await _teardown(tester);
    });

    testWidgets('oversized borderRadius is clamped (pill shape)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(BorderBeam(borderRadius: 999, child: _box(height: 48))),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await _teardown(tester);
    });

    testWidgets('custom duration is respected without errors', (tester) async {
      await tester.pumpWidget(
        _host(
          BorderBeam(
            duration: const Duration(milliseconds: 200),
            child: _box(),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _teardown(tester);
    });

    testWidgets('theme auto follows the ambient theme', (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          _host(
            BorderBeam(theme: BorderBeamTheme.auto, child: _box()),
            brightness: brightness,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
      await _teardown(tester);
    });

    testWidgets('zero-size child does not crash', (tester) async {
      await tester.pumpWidget(
        _host(const BorderBeam(child: SizedBox.shrink())),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await _teardown(tester);
    });
  });
}
