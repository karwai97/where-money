import 'package:flutter/material.dart';

/// The colours one brightness of C5 Graphite is made of. Field names are the
/// design's own token names, so the values can be checked against the palette
/// they came from without translating first.
class _Palette {
  const _Palette({
    required this.bg,
    required this.surf,
    required this.ink,
    required this.muted,
    required this.rule,
    required this.track,
    required this.accent,
    required this.onAccent,
  });

  final Color bg;
  final Color surf;
  final Color ink;
  final Color muted;
  final Color rule;
  final Color track;
  final Color accent;
  final Color onAccent;
}

/// Neutral dark greys and a soft violet, measured on the design canvas rather
/// than eyeballed, and kept well away from the red and green spending moves in
/// so an accent is never read as a direction.
const _dark = _Palette(
  bg: Color(0xFF15161A),
  surf: Color(0xFF1D1F25),
  ink: Color(0xFFE5E6EB),
  muted: Color(0xFF9A9DA8),
  rule: Color(0xFF262931),
  track: Color(0xFF2E323C),
  accent: Color(0xFF9B8CF0),
  onAccent: Color(0xFF16131F),
);

const _light = _Palette(
  bg: Color(0xFFFAFAFB),
  surf: Color(0xFFF1F2F5),
  ink: Color(0xFF17181C),
  muted: Color(0xFF5A5E68),
  rule: Color(0xFFE3E5EA),
  track: Color(0xFFD9DBE2),
  // The one value that does not invert. Dark's #9B8CF0 measures 2.72:1 on this
  // ground, so it would fail on every small thing the accent touches — the ISO
  // code beside an amount, the month badge, a chart's column heads. Same hue,
  // deliberately not the same colour.
  accent: Color(0xFF5B47C4),
  onAccent: Color(0xFFF6F4FF),
);

/// The hue both accents belong to. Seeding from this rather than from either
/// accent keeps the roles Graphite does not name — the containers, the error
/// reds — growing from one place at both brightnesses, so they stay a matched
/// pair. The accent itself is not taken from the seed; it is measured, and it
/// is the one value the two brightnesses hold differently.
const _seed = Color(0xFF9B8CF0);

/// One seed, both brightnesses, so choosing Dark is choosing a theme somebody
/// looked at rather than the Material default. Grown once: deriving a scheme
/// from a seed is expensive, and this is read on every rebuild above the
/// MaterialApp.
ThemeData themeFor(Brightness brightness) =>
    brightness == Brightness.dark ? _darkTheme : _lightTheme;

final _lightTheme = _grownFrom(Brightness.light, _light);
final _darkTheme = _grownFrom(Brightness.dark, _dark);

/// The seed supplies every tonal role the design does not name. What Graphite
/// measured is laid over the top.
ThemeData _grownFrom(Brightness brightness, _Palette palette) => ThemeData(
  useMaterial3: true,
  colorScheme:
      ColorScheme.fromSeed(seedColor: _seed, brightness: brightness).copyWith(
        primary: palette.accent,
        onPrimary: palette.onAccent,
        surface: palette.bg,
        onSurface: palette.ink,
        surfaceContainer: palette.surf,
        surfaceContainerHighest: palette.track,
        onSurfaceVariant: palette.muted,
        outlineVariant: palette.rule,
      ),
);
