import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money_core/where_money_core.dart';

import 'as_drawn.dart';
import 'fakes/fake_device_lock.dart';
import 'fakes/fake_model_gateway.dart';
import 'fakes/fake_sign_in_gateway.dart';
import 'fakes/in_memory_device_preferences.dart';
import 'fakes/in_memory_ledger_store.dart';

/// A phone whose text size is turned all the way up still has to draw every
/// screen. WCAG asks for 200% without losing content, and two places used to
/// lose it silently: the Ledger's trend clipped its month labels and squeezed
/// the bars to nothing, and Review's Category field overflowed by the
/// difference between the widest Category and the one chosen.
///
/// Neither failed a test. A Flutter overflow is a layout error rather than an
/// exception, so a widget test only sees it if it looks — which is what this
/// file is for. Anything that pins a height around text belongs here.
void main() {
  const phone = Size(390, 844);

  /// Every step of the way up, not just the top: 1.5 was clean while 2.0 was
  /// clipping, so a test at 2.0 alone would not have said where it started.
  const scales = <double>[1.0, 1.5, 2.0];

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearTextScaleFactorTestValue();
  });

  Future<void> openLedger(WidgetTester tester, double scale) async {
    tester.view
      ..physicalSize = phone
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;

    await tester.pumpWidget(
      WhereMoneyApp(
        lock: FakeDeviceLock(),
        preferences: InMemoryDevicePreferences(
          locksOnOpen: false,
          // Seeded so Settings draws the Daily cap counted rather than as the
          // bare cap: the figure, the word beside it and the track are what
          // the widest column on that row is made of.
          scanAllowance: Allowance(
            used: 12,
            limit: 20,
            resetsAt: fixtureNow.add(const Duration(hours: 6)),
          ),
        ),
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        storesFor: (_) =>
            InMemoryLedgerStore(seedLedger(around: fixtureNow)).stores,
        model: FakeModelGateway(),
        homeCurrency: 'MYR',
        photograph: (_) async => null,
        clock: () => fixtureNow,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// What the frame reported, said in full. `takeException` answers with a
  /// summary once there is more than one, and six clipped months is exactly
  /// when the detail is worth having.
  void expectNothingClipped(WidgetTester tester, String where) {
    final reported = tester.takeException();
    expect(
      reported,
      isNull,
      reason: 'Something did not fit on $where: $reported',
    );
  }

  for (final scale in scales) {
    testWidgets('the Ledger fits at $scale', (tester) async {
      await openLedger(tester, scale);
      expectNothingClipped(tester, 'the Ledger at $scale');

      // The trend is the only way through the months, so it has to be there
      // and it has to be tappable — a header that fits because the trend
      // went missing is not a header that fits.
      expect(find.text('AUG'), findsOneWidget);
      await tester.tap(find.text('JUL'));
      await tester.pumpAndSettle();
      expectNothingClipped(tester, 'the Ledger on another month at $scale');
      expect(find.text('JUL'), findsOneWidget);
    });

    testWidgets('the chart detail fits at $scale', (tester) async {
      await openLedger(tester, scale);
      tester.takeException();

      await tester.tap(find.byTooltip('Charts'));
      await tester.pumpAndSettle();
      expectNothingClipped(tester, 'the chart detail at $scale');
    });

    testWidgets('Review fits at $scale', (tester) async {
      await openLedger(tester, scale);
      tester.takeException();

      await tester.tap(find.byTooltip('Add an Expense by hand'));
      await tester.pumpAndSettle();
      expectNothingClipped(tester, 'Review at $scale');
    });

    testWidgets('Settings fits at $scale', (tester) async {
      await openLedger(tester, scale);
      tester.takeException();

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expectNothingClipped(tester, 'Settings at $scale');

      // The two rows that wrap to two lines in the 88px column, and the one
      // the scaled label column has to leave room for a switch beside.
      expect(markSaying('Lock Where Money'), findsOneWidget);
      expect(markSaying('Home Currency'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      // And the foot of it, which at 200% is past the fold. A `ListView` never
      // lays out what nobody has scrolled to, so without this the Home
      // Currency's two sentences and the sign-out button are never measured at
      // the scale most likely to break them.
      //
      // Reaching the button is all this can say about the button itself: a
      // Material button ellipsises its label rather than reporting an
      // overflow, so its own height is not a thing a frame complains about.
      await tester.scrollUntilVisible(markSaying('Sign out'), 200);
      await tester.pumpAndSettle();
      expectNothingClipped(tester, 'the foot of Settings at $scale');
      expect(markSaying('Sign out'), findsOneWidget);
      // The figure, the word beside it and the track under both, which is the
      // busiest value column on the screen and the last row before the gap.
      expect(markSaying('Daily cap'), findsOneWidget);
      expect(find.text('12 / 20'), findsOneWidget);
    });
  }
}
