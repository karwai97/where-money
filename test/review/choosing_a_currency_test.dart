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

/// The currency stopped being typed. Everything here is about what a user can
/// see and choose: the field they cannot type into, the order of the rows in
/// the sheet, and what happens to a value the app cannot place — and, at the
/// bottom, what choosing one does to the tally that measures the Model.
void main() {
  late InMemoryLedgerStore store;
  final model = FakeModelGateway();

  setUp(() => store = InMemoryLedgerStore());

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> openLedger(
    WidgetTester tester, {
    String? homeCurrency,
    List<Expense> ledger = const [],
  }) async {
    tester.view
      ..physicalSize = const Size(1000, 4000)
      ..devicePixelRatio = 1;
    for (final expense in ledger) {
      await store.add(expense);
    }

    await tester.pumpWidget(
      WhereMoneyApp(
        lock: FakeDeviceLock(),
        preferences: InMemoryDevicePreferences(locksOnOpen: false),
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

  Future<void> openReview(WidgetTester tester, {String? homeCurrency}) async {
    await openLedger(tester, homeCurrency: homeCurrency);
    await tester.tap(find.byTooltip('Add an Expense by hand'));
    await tester.pumpAndSettle();
  }

  Future<void> openReviewOfAScan(WidgetTester tester, Extraction read) async {
    final scan = await store.capture(photograph(width: 300, height: 400));
    await store.put(scan.movedTo(ScanState.extracted, extraction: read));

    await openLedger(tester);
    await tester.tap(find.byTooltip('Inbox, 1 waiting'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
  }

  Future<void> openTheSheet(WidgetTester tester) async {
    await tester.tap(
      find
          .ancestor(of: find.text('Currency'), matching: find.byType(InkWell))
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> correct(WidgetTester tester) async {
    await tester.tap(find.text('Village Grocer Bangsar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Correct this Expense'));
    await tester.pumpAndSettle();
  }

  Expense spentIn(String currency, {required String id, required int day}) =>
      Expense.fromExtraction(
        cleanExtraction.copyWith(
          currency: currency,
          purchasedAt: '2026-08-${day.toString().padLeft(2, '0')}',
        ),
        id: id,
        now: DateTime(2026, 8, day),
      );

  testWidgets('the currency field cannot be typed into', (tester) async {
    await openReview(tester);

    expect(
      find.widgetWithText(TextField, 'Currency'),
      findsNothing,
      reason: 'a currency that can be typed is a currency that can be a typo',
    );
  });

  testWidgets('the sheet opens on the currencies this Ledger already uses, '
      'then everything else', (tester) async {
    await openLedger(
      tester,
      homeCurrency: 'MYR',
      ledger: [
        spentIn('JPY', id: 'older', day: 3),
        spentIn('SGD', id: 'newer', day: 19),
      ],
    );
    await tester.tap(find.byTooltip('Add an Expense by hand'));
    await tester.pumpAndSettle();
    await openTheSheet(tester);

    expect(find.text('Yours'), findsOneWidget);
    expect(find.text('All currencies'), findsOneWidget);

    double topOf(String code) => tester
        .getRect(inTheCurrencySheet(find.widgetWithText(ListTile, code)))
        .top;

    expect(
      topOf('MYR'),
      lessThan(topOf('SGD')),
      reason: 'the Home Currency comes first',
    );
    expect(
      topOf('SGD'),
      lessThan(topOf('JPY')),
      reason: 'then what the Ledger already holds, most recent first',
    );
    expect(
      topOf('JPY'),
      lessThan(tester.getRect(find.text('All currencies')).top),
      reason: 'and the rest of the world below the head',
    );
  });

  testWidgets('a currency is found by searching for its code', (tester) async {
    await openReview(tester);
    await openTheSheet(tester);

    await tester.enterText(inTheCurrencySheet(find.byType(TextField)), 'nok');
    await tester.pumpAndSettle();

    expect(inTheCurrencySheet(find.widgetWithText(ListTile, 'NOK')), findsOne);
    expect(
      inTheCurrencySheet(find.widgetWithText(ListTile, 'USD')),
      findsNothing,
    );
  });

  testWidgets('a search that matches nothing says so rather than showing an '
      'empty list', (tester) async {
    await openReview(tester);
    await openTheSheet(tester);

    await tester.enterText(inTheCurrencySheet(find.byType(TextField)), 'ZZZ');
    await tester.pumpAndSettle();

    expect(find.textContaining('No code matches'), findsOneWidget);
  });

  testWidgets('a chosen currency lands on the form', (tester) async {
    await openReview(tester);
    await pickCurrency(tester, 'Currency', 'SGD');

    expect(find.text('SGD'), findsOneWidget);
    expect(find.text('Currency unclear'), findsNothing);
  });

  testWidgets('a receipt printed in RM arrives as MYR', (tester) async {
    await openReviewOfAScan(tester, cleanExtraction.copyWith(currency: 'RM'));

    expect(find.text('MYR'), findsOneWidget);
    expect(
      find.text('Currency unclear'),
      findsNothing,
      reason: 'the app understood a symbol the user did not have to translate',
    );
  });

  testWidgets('a symbol the app cannot place shows as itself, and is said to '
      'be wrong', (tester) async {
    // Eight currencies print this one, and guessing between them is worse than
    // saying the app does not know which it is.
    await openReviewOfAScan(tester, cleanExtraction.copyWith(currency: r'$'));

    expect(find.text(r'$'), findsOneWidget);
    expect(find.text('Currency unclear'), findsOneWidget);
    expect(find.textContaining('not an ISO 4217 code'), findsOneWidget);
  });

  testWidgets('a three-letter code nobody issues shows as itself too', (
    tester,
  ) async {
    await openReviewOfAScan(tester, cleanExtraction.copyWith(currency: 'XYZ'));

    expect(find.text('XYZ'), findsOneWidget);
    expect(find.text('Currency unclear'), findsOneWidget);
  });

  testWidgets('an Expense stored with no currency at all shows what it holds, '
      'and is told about it', (tester) async {
    await openLedger(
      tester,
      homeCurrency: 'MYR',
      ledger: [spentIn('???', id: 'unplaceable', day: 20)],
    );
    await correct(tester);

    expect(find.text('???'), findsOneWidget);
    expect(find.text('Currency unclear'), findsOneWidget);
  });

  testWidgets('opening a committed foreign Expense and saving it leaves the '
      'currency it was paid in', (tester) async {
    await openLedger(
      tester,
      homeCurrency: 'MYR',
      ledger: [spentIn('SGD', id: 'abroad', day: 20)],
    );
    await correct(tester);

    expect(
      find.text('SGD'),
      findsWidgets,
      reason: 'an edit opens on what is stored, never on the Home Currency',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.contents.single.currency, 'SGD');
  });

  group('what choosing one costs the Model', () {
    // Corrected Fields are the only measure of extraction accuracy this
    // project has, and they measure the Model. A blank is not a claim, so
    // filling one is not the Model being put right.
    Future<List<String>> commit(WidgetTester tester, String read) async {
      await openReviewOfAScan(tester, cleanExtraction.copyWith(currency: read));
      await pickCurrency(tester, 'Currency', 'SGD');
      await tester.tap(find.text('Add to Ledger'));
      await tester.pumpAndSettle();

      return store.contents.single.correctedFields;
    }

    testWidgets('a currency chosen into a field the Model left empty is not a '
        'correction', (tester) async {
      expect(await commit(tester, ''), isEmpty);
    });

    testWidgets('a currency changed from one the Model read is', (
      tester,
    ) async {
      expect(await commit(tester, 'MYR'), ['currency']);
    });

    testWidgets('and correcting something else is counted either way', (
      tester,
    ) async {
      await openReviewOfAScan(tester, cleanExtraction.copyWith(currency: ''));
      await tester.enterText(
        find.widgetWithText(TextField, 'Merchant').first,
        'Village Grocer KL',
      );
      await tester.pumpAndSettle();
      await pickCurrency(tester, 'Currency', 'SGD');
      await tester.tap(find.text('Add to Ledger'));
      await tester.pumpAndSettle();

      expect(store.contents.single.correctedFields, ['merchant']);
    });
  });
}
