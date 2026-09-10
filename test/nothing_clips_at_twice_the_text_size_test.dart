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
import 'picking_a_currency.dart';

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

  /// The app at [scale], opened as whoever [signIn] says is signed in.
  Future<void> openApp(
    WidgetTester tester,
    double scale, {
    required FakeSignInGateway signIn,
  }) async {
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
        signIn: signIn,
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

  Future<void> openLedger(WidgetTester tester, double scale) => openApp(
    tester,
    scale,
    signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
  );

  /// Signed out, with [refusing] set as what the phone says when the way in
  /// is tapped — the failure sentence is the one thing that changes the
  /// strip's height, and a long detail is what it has to wrap.
  Future<void> openSignedOut(
    WidgetTester tester,
    double scale, {
    Object? refusing,
  }) => openApp(tester, scale, signIn: FakeSignInGateway()..refuse = refusing);

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
    testWidgets('the sign-in screen fits at $scale', (tester) async {
      await openSignedOut(
        tester,
        scale,
        refusing: StateError(
          'the phone turned it down and said rather a lot about why',
        ),
      );
      expectNothingClipped(tester, 'the sign-in screen at $scale');

      // The block over the strip scrolls when it outgrows the space, so what
      // this asserts is that everything is still there and still reachable.
      // The buttons grow past 48 rather than clipping their labels, and a
      // Material button ellipsises rather than reporting an overflow — so
      // reaching them by their words is all a frame can say about them.
      expect(find.text('Where Money'), findsOneWidget);
      expect(
        find.text('Photograph the receipt. See where the money went.'),
        findsOneWidget,
      );
      expect(markSaying('Continue with Google'), findsOneWidget);
      expect(markSaying('Continue as guest'), findsOneWidget);

      // And with the failure sentence in the strip as well, which is the one
      // thing that changes the strip's height.
      await tester.tap(markSaying('Continue with Google'));
      await tester.pumpAndSettle();
      expectNothingClipped(tester, 'the sign-in screen refused at $scale');
      expect(find.textContaining('turned it down'), findsOneWidget);
      expect(markSaying('Continue as guest'), findsOneWidget);
    });

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

    testWidgets('the sheet of months fits at $scale', (tester) async {
      await openLedger(tester, scale);
      tester.takeException();

      await tester.tap(find.byTooltip('Choose a month'));
      await tester.pumpAndSettle();
      expectNothingClipped(tester, 'the sheet of months at $scale');

      // Twelve cells and the year over them, all still there: a grid that
      // fits because half of it scrolled off is not a grid that fits.
      expect(find.text('2026'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('MAR'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('MAR'),
        ),
      );
      await tester.pumpAndSettle();
      expectNothingClipped(tester, 'the Ledger back from the sheet at $scale');

      // And the pill it left behind, which shares the foot of the screen
      // with the camera button.
      expect(markSaying('Back to Aug 2026'), findsOneWidget);
      expect(
        tester.getRect(markSaying('Back to Aug 2026')).right,
        lessThanOrEqualTo(phone.width - 88),
        reason: 'the pill stays out from under the buttons in the corner',
      );
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

    testWidgets('the currency sheet fits at $scale', (tester) async {
      await openLedger(tester, scale);
      tester.takeException();

      await tester.tap(find.byTooltip('Add an Expense by hand'));
      await tester.pumpAndSettle();
      tester.takeException();

      // Past the fold at 200%, and a `ListView` lays out nothing nobody has
      // scrolled to.
      await tester.scrollUntilVisible(
        markSaying('Currency'),
        200,
        // Named because the form is not the only scrollable on the screen:
        // every field that can be typed into carries one of its own. The
        // form's is the outermost, so it is the one found first.
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await openTheCurrencySheet(tester, 'Currency');
      expectNothingClipped(tester, 'the currency sheet at $scale');

      // The two things a sheet that fits could have dropped: the search,
      // whose mark wraps to two lines in the 88px column, and the fullest
      // row there is — the Home Currency, which is also what the field
      // holds, so it carries the code, the mark and the check at once.
      expect(inTheCurrencySheet(markSaying('Search codes')), findsOneWidget);
      expect(inTheCurrencySheet(currencyRow('MYR')), findsOneWidget);

      // And the sentence that replaces the list, indented past a label
      // column that has grown with the text.
      await tester.enterText(inTheCurrencySheet(find.byType(TextField)), 'ZZZ');
      await tester.pumpAndSettle();
      expectNothingClipped(
        tester,
        'the currency sheet with no match at $scale',
      );
      expect(
        inTheCurrencySheet(find.textContaining('No code matches')),
        findsOneWidget,
      );
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
