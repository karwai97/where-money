import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money/lock/device_lock.dart';
import 'package:where_money_core/where_money_core.dart';

import '../as_drawn.dart';
import '../fakes/fake_device_lock.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';

/// Settings drawn in Review's hand rather than in Material's defaults: the
/// Setting's name in the tracked label column, its value in a filled cell
/// beside it, the sentence about it indented under the cell, and a hairline
/// between rows. No head strips — `settings_screen.dart` says why the design's
/// two came back off.
///
/// What the screen says and does is the rest of `test/settings`, which did not
/// change. This file is about how it is drawn, because that is the only thing
/// the redraw could have broken.
void main() {
  late FakeDeviceLock lock;
  late InMemoryDevicePreferences preferences;

  setUp(() {
    lock = FakeDeviceLock();
    preferences = InMemoryDevicePreferences();
  });

  /// [holdingTheLockRead] leaves the one asynchronous read on this screen
  /// unanswered. Set after the app has opened rather than before, because the
  /// Lock gate asks the same question on the way in and would never let go.
  Future<void> openSettings(
    WidgetTester tester, {
    bool holdingTheLockRead = false,
  }) async {
    await tester.pumpWidget(
      WhereMoneyApp(
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        storesFor: (_) => InMemoryLedgerStore(
          seedLedger(around: DateTime(2026, 8, 23)),
        ).stores,
        model: FakeModelGateway(),
        lock: lock,
        preferences: preferences,
        homeCurrency: 'MYR',
        photograph: (_) async => null,
        clock: () => DateTime(2026, 8, 23),
      ),
    );
    await tester.pumpAndSettle();

    if (holdingTheLockRead) {
      final held = Completer<void>();
      lock.holdsTheAnswer = held;
      // Released before the test ends, because the house rule is that every
      // knob a test sets is cleared by it.
      addTearDown(() {
        if (!held.isCompleted) held.complete();
      });
    }

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

  Rect rectOf(WidgetTester tester, Finder finder) =>
      tester.getRect(finder.first);

  testWidgets('the screen is named in the bar the Ledger wears', (
    tester,
  ) async {
    await openSettings(tester);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: markSaying('Settings'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the Settings are one table, in order, with nothing over them', (
    tester,
  ) async {
    await openSettings(tester);

    // Down the screen in the order the design sets them, with no head strip
    // between any two: four rows do not need telling apart.
    final down = [
      'Theme',
      'Language',
      'Lock Where Money',
      'Home Currency',
      'Sign out',
    ];

    for (final (index, name) in down.indexed.skip(1)) {
      expect(
        rectOf(tester, markSaying(down[index - 1])).bottom,
        lessThan(rectOf(tester, markSaying(name)).top),
        reason: '$name is not under ${down[index - 1]}',
      );
    }
  });

  testWidgets("a Setting's name sits in the column beside its value", (
    tester,
  ) async {
    await openSettings(tester);

    final name = rectOf(tester, markSaying('Theme'));
    final value = rectOf(tester, find.text('System'));

    expect(name.right, lessThanOrEqualTo(value.left));
    expect(
      name.center.dy,
      closeTo(value.center.dy, 4),
      reason: 'beside it, not over it',
    );
  });

  testWidgets('what a Setting governs is said under its value, not under its '
      'name', (tester) async {
    await openSettings(tester);

    final governs = rectOf(
      tester,
      find.textContaining('Spending in other currencies'),
    );
    final name = rectOf(tester, markSaying('Home Currency'));
    final value = rectOf(tester, find.text('MYR'));

    expect(
      governs.left,
      greaterThan(name.right),
      reason: 'indented clear of the name column',
    );
    expect(
      governs.left,
      lessThanOrEqualTo(value.left),
      reason: 'under the cell the code sits in, which insets it a little more',
    );
  });

  testWidgets('the Lock is announced with its name, its state and what it '
      'promises', (tester) async {
    final handle = tester.ensureSemantics();

    await openSettings(tester);

    final announced = tester.getSemantics(find.byType(Switch));

    expect(
      announced.label,
      allOf(contains('Lock Where Money'), contains('fingerprint')),
    );
    expect(announced, isSemantics(hasToggledState: true, isToggled: true));
    expect(
      tester.getSemantics(find.textContaining('fingerprint')),
      same(announced),
      reason: 'the sentence is read with the switch, not as a node after it',
    );

    handle.dispose();
  });

  testWidgets('a phone with no screen lock still draws the switch, off and '
      'disabled', (tester) async {
    final handle = tester.ensureSemantics();
    lock.available = LockAvailability.none;

    await openSettings(tester);

    // Read as it is announced rather than off the widget: a switch nobody can
    // turn on has to say so to whoever cannot see that it is greyed.
    expect(
      tester.getSemantics(find.byType(Switch)),
      isSemantics(
        hasToggledState: true,
        isToggled: false,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    expect(
      find.textContaining('no screen lock'),
      findsOneWidget,
      reason: 'the sentence under it is how the user finds out what to do',
    );

    handle.dispose();
  });

  testWidgets('a Lock read that never comes back leaves the row named and '
      'nothing else', (tester) async {
    await openSettings(tester, holdingTheLockRead: true);

    expect(markSaying('Lock Where Money'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.textContaining('fingerprint'), findsNothing);
    expect(
      markSaying('Home Currency'),
      findsOneWidget,
      reason: 'nothing else on the screen waits on it',
    );
  });

  testWidgets('signing out is a way out of the screen rather than a Setting '
      'on it', (tester) async {
    await openSettings(tester);

    expect(
      find.widgetWithText(OutlinedButton, 'SIGN OUT'),
      findsOneWidget,
      reason: 'outlined and muted: it is not what the screen is for',
    );
    expect(
      rectOf(tester, find.byType(OutlinedButton)).top,
      greaterThan(rectOf(tester, markSaying('Home Currency')).bottom),
    );
  });

  testWidgets('nothing on the screen is drawn in Material list furniture', (
    tester,
  ) async {
    await openSettings(tester);

    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(
      find.byType(Divider),
      findsNothing,
      reason: 'the rows are a table, ruled by hairlines',
    );
  });
}
