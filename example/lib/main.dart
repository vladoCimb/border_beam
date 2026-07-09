import 'package:beam_border/beam_border.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const ExampleApp());
}

/// Demo application showcasing every [BorderBeam] type.
class ExampleApp extends StatelessWidget {
  /// Creates the example app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'beam_border example',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: const ExamplePage(),
    );
  }
}

/// Scroll page with one demo per effect type.
class ExamplePage extends StatelessWidget {
  /// Creates the example page.
  const ExamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      appBar: AppBar(title: const Text('beam_border')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _demo(
            'BorderBeamType.full',
            BorderBeam(child: _card('Full border beam')),
          ),
          _demo(
            'BorderBeamType.compact',
            Center(
              child: BorderBeam(
                type: BorderBeamType.compact,
                borderRadius: 32,
                child: _pill('Compact'),
              ),
            ),
          ),
          _demo(
            'BorderBeamType.line',
            BorderBeam(
              type: BorderBeamType.line,
              borderRadius: 999,
              child: _searchBar(),
            ),
          ),
          _demo(
            'BorderBeamType.pulseInner',
            BorderBeam(
              type: BorderBeamType.pulseInner,
              colorVariant: BorderBeamColorVariant.ocean,
              child: _card('Breathing pulse'),
            ),
          ),
          _demo(
            'Custom colors',
            BorderBeam(
              colorVariant: BorderBeamColorVariant.custom,
              customColors: const [
                Color(0xFF00E5FF),
                Color(0xFF7C4DFF),
                Color(0xFFFF4081),
              ],
              child: _card('Custom palette'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _demo(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(label, style: const TextStyle(color: Colors.white54)),
          ),
          child,
        ],
      ),
    );
  }

  Widget _card(String text) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF17171B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70)),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF17171B),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70)),
    );
  }

  Widget _searchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF17171B),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        children: [
          Icon(Icons.search, size: 20, color: Colors.white38),
          SizedBox(width: 12),
          Text('Search', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}
