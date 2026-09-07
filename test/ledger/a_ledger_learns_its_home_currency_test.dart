import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';
import '../picking_a_currency.dart';
import '../scan/inbox_bloc_test.dart' show photograph;

/// A Ledger with no Home Currency yet, and what it does about it. Nothing here
/// asserts on a constant: the whole point is that there is no longer one to
/// assert on (ADR-0009).
void main() {
  late InMemoryLedgerStore store;
  late InMemoryDevicePreferences preferences;
  late FakeModelGateway model;

  setUp(() {
    store = InMemoryLedgerStore();
    preferences = InMemoryDevicePreferences(locksOnOpen: false);
    model = FakeModelGateway();
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> openLedger(WidgetTester tester, {String? homeCurrency}) async {
    tester.view
      ..physicalSize = const Size(1000, 4000)
      ..devicePixelRatio = 1;

    await tester.pumpWidget(
      WhereMoneyApp(
        lock: FakeDeviceLock(),
        preferences: preferences,
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        storesFor: (_) => store.stores,
        model: model,
        homeCurrency: homeCurrency,
        photograph: (_) async => null,
        clock: () => fixtureNow,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openCharts(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Charts'));
    await tester.pumpAndSettle();
  }

  /// `tester.pageBack` looks for a tooltip Material renames per language; the
  /// icon is the same in both.
  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
  }

  /// The shortest path from an empty Ledger to one Expense in [currency].
  Future<void> addByHand(WidgetTester tester, {String? currency}) async {
    await tester.tap(find.byTooltip('Add an Expense by hand'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Merchant'),
      'Kopitiam SS2',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Date'),
      '2026-08-22',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Total'), '26.00');
    await tester.pumpAndSettle();
    if (currency != null) await pickCurrency(tester, 'Currency', currency);

    await tester.tap(find.text('Add to Ledger'));
    await tester.pumpAndSettle();
  }

  testWidgets('a Ledger with no Home Currency says totals start with the '
      'first expense, rather than drawing bars of zero', (tester) async {
    await openLedger(tester);
    await openCharts(tester);

    expect(
      find.textContaining('Totals start with your first expense'),
      findsOneWidget,
    );
    expect(find.text('By Category'), findsNothing);
    expect(find.text('Month by month'), findsNothing);
  });

  testWidgets('no Recap is asked for while there is no Home Currency', (
    tester,
  ) async {
    // Enough spending for a Recap, and not one code among it the app can
    // learn from, so the Ledger stays without a Home Currency.
    for (var day = 1; day <= 6; day++) {
      await store.add(
        Expense.fromExtraction(
          cleanExtraction.copyWith(
            purchasedAt: '2026-08-0$day',
            currency: '???',
          ),
          id: 'seeded-$day',
          now: DateTime(2026, 8, day),
        ),
      );
    }

    await openLedger(tester);

    expect(
      model.rollupsAsked,
      isEmpty,
      reason: 'there is no Rollup to write up, so nothing is paid for',
    );
  });

  testWidgets('the first Expense committed sets the Home Currency, and the '
      'charts appear in it', (tester) async {
    await openLedger(tester);
    await addByHand(tester, currency: 'SGD');

    expect(await preferences.homeCurrency(), 'SGD');

    await openCharts(tester);

    expect(find.text('SGD 26.00'), findsWidgets);
    expect(find.textContaining('Totals start with'), findsNothing);
  });

  testWidgets('the first Review has no Home Currency to seed with, and says '
      'the currency is missing', (tester) async {
    await openLedger(tester);
    await tester.tap(find.byTooltip('Add an Expense by hand'));
    await tester.pumpAndSettle();

    expect(
      find.text('Currency unclear'),
      findsOneWidget,
      reason: 'once per Ledger, and better than a currency nobody chose',
    );
  });

  testWidgets('once there is one it seeds an Expense typed by hand', (
    tester,
  ) async {
    await openLedger(tester, homeCurrency: 'MYR');
    await tester.tap(find.byTooltip('Add an Expense by hand'));
    await tester.pumpAndSettle();

    expect(find.text('MYR'), findsOneWidget);
    expect(
      find.text('Currency unclear'),
      findsNothing,
      reason: 'the seed is written into the Extraction, so the Check sees it',
    );
  });

  testWidgets('and it seeds a Scan the Model read no currency from', (
    tester,
  ) async {
    final scan = await store.capture(photograph(width: 300, height: 400));
    await store.put(
      scan.movedTo(
        ScanState.extracted,
        extraction: cleanExtraction.copyWith(currency: ''),
      ),
    );

    await openLedger(tester, homeCurrency: 'MYR');
    await tester.tap(find.byTooltip('Inbox, 1 waiting'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('MYR'), findsOneWidget);
    expect(find.text('Currency unclear'), findsNothing);
  });

  testWidgets('but it does not seed an edit: what is stored is what is shown', (
    tester,
  ) async {
    await store.add(
      Expense.fromExtraction(
        cleanExtraction.copyWith(currency: '???'),
        id: 'unplaceable',
        now: DateTime(2026, 8, 20),
      ),
    );

    await openLedger(tester, homeCurrency: 'MYR');
    await tester.tap(find.text('Village Grocer Bangsar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Correct this Expense'));
    await tester.pumpAndSettle();

    expect(find.text('???'), findsOneWidget);
    expect(find.text('Currency unclear'), findsOneWidget);
  });

  testWidgets('Settings shows the Home Currency, says where it came from, and '
      'what it governs', (tester) async {
    await store.add(
      Expense.fromExtraction(
        cleanExtraction,
        id: 'the-first',
        now: DateTime(2026, 8, 20),
      ),
    );

    await openLedger(tester, homeCurrency: 'MYR');
    await openSettings(tester);

    expect(find.text('Home Currency'), findsOneWidget);
    expect(find.text('MYR'), findsOneWidget);
    expect(find.text('Taken from your first expense.'), findsOneWidget);
    expect(
      find.textContaining(
        'Spending in other currencies is listed but not counted',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a Home Currency the user chose is not said to have come from '
      'their first expense', (tester) async {
    await store.add(
      Expense.fromExtraction(
        cleanExtraction,
        id: 'the-first',
        now: DateTime(2026, 8, 20),
      ),
    );

    await openLedger(tester, homeCurrency: 'MYR');
    await openSettings(tester);
    await pickCurrency(tester, 'Home Currency', 'SGD');

    expect(find.text('SGD'), findsWidgets);
    expect(
      find.text('Taken from your first expense.'),
      findsNothing,
      reason:
          'it came from the row the user just tapped, and says nothing it '
          'cannot stand behind',
    );
    expect(
      find.textContaining('Spending in other currencies'),
      findsOneWidget,
      reason: 'what it governs is true however it was arrived at',
    );
  });

  testWidgets('a Ledger that has none says the first expense will set it', (
    tester,
  ) async {
    await openLedger(tester);
    await openSettings(tester);

    expect(find.text('Your first expense will set this.'), findsOneWidget);
  });

  testWidgets('changing it in Settings asks nothing, and the charts follow', (
    tester,
  ) async {
    await store.add(
      Expense.fromExtraction(
        cleanExtraction.copyWith(currency: 'SGD'),
        id: 'abroad',
        now: DateTime(2026, 8, 20),
      ),
    );

    await openLedger(tester, homeCurrency: 'MYR');
    await openSettings(tester);
    await pickCurrency(tester, 'Home Currency', 'SGD');

    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason: 'the house style says things in place, not in a modal',
    );
    expect(await preferences.homeCurrency(), 'SGD');

    await back(tester);
    await openCharts(tester);

    expect(find.text('SGD 44.10'), findsWidgets);
    expect(
      find.textContaining('left out'),
      findsNothing,
      reason: 'the Expense that was foreign a moment ago is the home one now',
    );
  });
}
