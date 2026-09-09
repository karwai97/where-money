import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money/settings/themes.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';

void main() {
  late InMemoryDevicePreferences preferences;
  late InMemoryLedgerStore store;
  late int storesBuilt;

  setUp(() {
    preferences = InMemoryDevicePreferences();
    store = InMemoryLedgerStore();
    storesBuilt = 0;
  });

  Widget app({ThemeMode theme = ThemeMode.system}) => WhereMoneyApp(
    signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
    storesFor: (_) {
      storesBuilt++;
      return store.stores;
    },
    model: FakeModelGateway(),
    lock: FakeDeviceLock(),
    preferences: preferences,
    theme: theme,
    photograph: (_) async => null,
  );

  Brightness brightnessOn(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String option) async {
    await tester.tap(find.byType(DropdownButtonFormField<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  testWidgets('Settings offers System, Light and Dark', (tester) async {
    await tester.pumpWidget(app());
    await openSettings(tester);

    await tester.tap(find.byType(DropdownButtonFormField<ThemeMode>));
    await tester.pumpAndSettle();

    expect(find.text('System'), findsWidgets);
    expect(find.text('Light'), findsWidgets);
    expect(find.text('Dark'), findsWidgets);
  });

  testWidgets('an app nobody has chosen for follows the phone', (tester) async {
    await tester.pumpWidget(app());
    await openSettings(tester);

    // The test phone is light, so following it means light.
    expect(brightnessOn(tester), Brightness.light);
    expect(await preferences.theme(), ThemeMode.system);
  });

  testWidgets('choosing Dark darkens the app and is remembered', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await openSettings(tester);

    await choose(tester, 'Dark');

    expect(brightnessOn(tester), Brightness.dark);
    expect(await preferences.theme(), ThemeMode.dark);
  });

  testWidgets('choosing Light stays light on a phone that is dark', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(app());
    await openSettings(tester);
    expect(brightnessOn(tester), Brightness.dark);

    await choose(tester, 'Light');

    expect(brightnessOn(tester), Brightness.light);
    expect(await preferences.theme(), ThemeMode.light);
  });

  testWidgets('changing the theme does not reach for the Ledger again', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await openSettings(tester);
    expect(storesBuilt, 1);

    await choose(tester, 'Dark');

    expect(storesBuilt, 1);
  });

  testWidgets('an app opened Dark is dark on the frame it opens with', (
    tester,
  ) async {
    // One pump, not pumpAndSettle: whoever chose Dark never sees a light frame
    // on the way in.
    await tester.pumpWidget(app(theme: ThemeMode.dark));

    expect(brightnessOn(tester), Brightness.dark);
  });

  test('both themes keep a bar readable against its track', () {
    for (final brightness in Brightness.values) {
      final colours = themeFor(brightness).colorScheme;

      expect(
        _contrast(colours.primary, colours.surfaceContainerHighest),
        greaterThanOrEqualTo(3.0),
        reason: 'a $brightness chart bar is lost against its track',
      );
    }
  });

  // The accent is not only a bar. It also carries the ISO code beside an amount
  // and the month badge, and small text owes 4.5:1 where a filled shape gets
  // away with 3:1. That is the pair of thresholds one accent cannot pay on both
  // grounds, and why themes.dart holds two.
  test('the accent carries small text in both themes', () {
    for (final brightness in Brightness.values) {
      final colours = themeFor(brightness).colorScheme;

      expect(
        _contrast(colours.primary, colours.surface),
        greaterThanOrEqualTo(4.5),
        reason: 'a $brightness ISO code in the accent is unreadable',
      );
    }
  });

  // A claim about hue, which contrast cannot see: a teal and a red of equal
  // lightness sit at 1.0:1 and are still unmistakable.
  test('an accent is never mistaken for a delta', () {
    for (final brightness in Brightness.values) {
      final accent = HSLColor.fromColor(
        themeFor(brightness).colorScheme.primary,
      ).hue;

      for (final direction in {'a loss': 0.0, 'a saving': 120.0}.entries) {
        expect(
          _hueApart(accent, direction.value),
          greaterThanOrEqualTo(45.0),
          reason:
              'a $brightness accent is too near the hue of ${direction.key}',
        );
      }
    }
  });
}

/// Degrees between two hues the short way round the wheel, so red at 0 and a
/// hue at 350 are ten apart rather than most of a circle.
double _hueApart(double a, double b) {
  final gap = (a - b).abs() % 360;
  return gap > 180 ? 360 - gap : gap;
}

/// WCAG relative-luminance contrast, the measure a bar has to clear to still
/// say what it says in either theme.
double _contrast(Color a, Color b) {
  final one = a.computeLuminance() + 0.05;
  final other = b.computeLuminance() + 0.05;
  return one > other ? one / other : other / one;
}
