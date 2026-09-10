import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money_core/where_money_core.dart';

import '../as_drawn.dart';
import '../fakes/fake_device_lock.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';

/// The day's Scans against the cap, on Settings. A fact about the service
/// rather than a Setting: it is drawn read-only, it answers no tap, and every
/// figure on it came from the Worker rather than from anything this phone
/// worked out for itself.
void main() {
  final today = DateTime(2026, 8, 25, 14);
  final tomorrow = DateTime.utc(2026, 8, 26);

  Future<void> openSettings(
    WidgetTester tester, {
    Allowance? heard,
    Knobs knobs = const Knobs(),
  }) async {
    await tester.pumpWidget(
      WhereMoneyApp(
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        storesFor: (_) => InMemoryLedgerStore(seedLedger(around: today)).stores,
        model: FakeModelGateway(),
        lock: FakeDeviceLock(),
        preferences: InMemoryDevicePreferences(scanAllowance: heard),
        homeCurrency: 'MYR',
        knobs: knobs,
        photograph: (_) async => null,
        clock: () => today,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

  Finder theTrack() => find.byType(LinearProgressIndicator);

  testWidgets('a phone that has never heard from the Worker shows the cap it '
      'asks for', (tester) async {
    await openSettings(tester, knobs: const Knobs(dailyCap: 40));

    expect(markSaying('Daily cap'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('Scans a day'), findsOneWidget);
    expect(
      theTrack(),
      findsNothing,
      reason: 'nothing is counted, so there is nothing to fill',
    );
    expect(find.textContaining('receipts the Model reads'), findsOneWidget);
  });

  testWidgets('an allowance whose day has passed reads as nothing spent', (
    tester,
  ) async {
    await openSettings(
      tester,
      heard: Allowance(
        used: 20,
        limit: 20,
        resetsAt: today.toUtc().subtract(const Duration(hours: 8)),
      ),
    );

    expect(find.text('0 / 20'), findsOneWidget);
    expect(find.text('Scans today'), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(theTrack()).value, 0);
    expect(find.textContaining('receipts the Model reads'), findsOneWidget);
  });

  testWidgets('a day part spent fills the track by what is gone', (
    tester,
  ) async {
    await openSettings(
      tester,
      heard: Allowance(used: 12, limit: 20, resetsAt: tomorrow),
    );

    expect(find.text('12 / 20'), findsOneWidget);
    expect(find.text('Scans today'), findsOneWidget);
    expect(
      tester.widget<LinearProgressIndicator>(theTrack()).value,
      closeTo(0.6, 0.001),
    );
    expect(find.textContaining('receipts the Model reads'), findsOneWidget);
  });

  testWidgets('a day spent says so in the Inbox\'s own words, and when more '
      'arrive', (tester) async {
    await openSettings(
      tester,
      heard: Allowance(used: 20, limit: 20, resetsAt: tomorrow),
    );

    expect(find.text('20 / 20'), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(theTrack()).value, 1);
    expect(
      find.textContaining("Today's Scans are used up"),
      findsWidgets,
      reason: 'the same news as the Inbox, in the same words',
    );
    expect(find.textContaining('More Scans at'), findsOneWidget);
    expect(find.textContaining('receipts the Model reads'), findsNothing);
  });

  testWidgets('more used than the cap is said as it was heard, and the track '
      'stops at its end', (tester) async {
    await openSettings(
      tester,
      heard: Allowance(used: 23, limit: 20, resetsAt: tomorrow),
    );

    // The counter is approximate — two Scans at once read the same number and
    // both go through — and rounding that down to 20 would be the lie.
    expect(find.text('23 / 20'), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(theTrack()).value, 1);
    expect(find.textContaining("Today's Scans are used up"), findsWidgets);
  });

  testWidgets('the whole row is one thing to a screen reader, and the figure '
      'is not read as a slash', (tester) async {
    final handle = tester.ensureSemantics();

    await openSettings(
      tester,
      heard: Allowance(used: 12, limit: 20, resetsAt: tomorrow),
    );

    final announced = tester.getSemantics(find.text('12 / 20'));

    expect(
      announced.label,
      allOf(
        contains('12 of 20'),
        contains('Scans today'),
        contains('receipts the Model reads'),
      ),
    );
    expect(
      announced.label,
      isNot(contains('/')),
      reason: '"twelve slash twenty" is not how a figure is read out',
    );
    expect(
      announced,
      isSemantics(isFocusable: false),
      reason:
          'nothing here answers a tap, so it is not a stop on the way '
          'round the screen',
    );

    handle.dispose();
  });

  testWidgets('the row is the last thing in the table, under Home Currency', (
    tester,
  ) async {
    await openSettings(
      tester,
      heard: Allowance(used: 12, limit: 20, resetsAt: tomorrow),
    );

    expect(
      tester.getRect(markSaying('Home Currency')).bottom,
      lessThan(tester.getRect(markSaying('Daily cap')).top),
    );
    expect(
      tester.getRect(markSaying('Daily cap')).bottom,
      lessThan(tester.getRect(find.byType(OutlinedButton)).top),
    );
  });

  testWidgets("the figure sits beside the row's name and the sentence under "
      'the figure', (tester) async {
    await openSettings(
      tester,
      heard: Allowance(used: 12, limit: 20, resetsAt: tomorrow),
    );

    final name = tester.getRect(markSaying('Daily cap'));
    final figure = tester.getRect(find.text('12 / 20'));
    final governs = tester.getRect(
      find.textContaining('receipts the Model reads'),
    );

    expect(name.right, lessThanOrEqualTo(figure.left));
    expect(governs.left, greaterThan(name.right));
    expect(governs.top, greaterThan(figure.bottom));
  });
}
