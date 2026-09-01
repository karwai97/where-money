import 'package:flutter/material.dart';

/// A muted teal, kept well away from the red and green this app spends on
/// deltas so an accent is never mistaken for a direction. A starting point for
/// whoever picks the real palette, not a brand decision.
const _seed = Color(0xFF3E7C77);

/// One seed, both brightnesses, so choosing Dark is choosing a theme somebody
/// looked at rather than the Material default. Grown once: deriving a scheme
/// from a seed is expensive, and this is read on every rebuild above the
/// MaterialApp.
ThemeData themeFor(Brightness brightness) =>
    brightness == Brightness.dark ? _dark : _light;

final _light = _grownFrom(Brightness.light);
final _dark = _grownFrom(Brightness.dark);

ThemeData _grownFrom(Brightness brightness) => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
);
