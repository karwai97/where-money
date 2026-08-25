import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money/scan/model_gateway.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_ledger_store.dart';

/// The month said in words, on the screen the charts are on. Assertions are on
/// text the user can read.
void main() {
  late InMemoryLedgerStore store;

  setUp(() => store = InMemoryLedgerStore(seedLedger()));

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> openCharts(WidgetTester tester, FakeModelGateway model) async {
    tester.view
      ..physicalSize = const Size(1200, 3000)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(
      WhereMoneyApp(
        // The lock is not what these are about, so it is off.
        lock: FakeDeviceLock(),
        preferences: InMemoryDevicePreferences(locksOnOpen: false),
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        ledgerFor: (_) => store,
        model: model,
        photograph: (_) async => null,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Charts'));
    await tester.pumpAndSettle();
  }

  testWidgets('the month is read back in words above the charts', (
    tester,
  ) async {
    await openCharts(
      tester,
      FakeModelGateway(
        recapAnswer: FakeModelGateway.wrote(
          'Groceries took MYR 423.10 of it, more than anything else.',
        ),
      ),
    );

    expect(find.text('Where your money went'), findsOneWidget);
    expect(
      find.text('Groceries took MYR 423.10 of it, more than anything else.'),
      findsOneWidget,
    );
  });

  testWidgets('a month with too little in it says so instead of inventing '
      'something', (tester) async {
    store = InMemoryLedgerStore([
      Expense(
        id: 'only-one',
        merchant: 'Kopitiam SS2',
        date: DateTime.now(),
        currency: 'MYR',
        total: 12.40,
        category: 'dining',
        lineItems: const [],
        source: ExpenseSource.manual,
        needsReview: false,
      ),
    ]);

    await openCharts(tester, FakeModelGateway());

    expect(
      find.textContaining('before there is anything worth writing up'),
      findsOneWidget,
    );
  });

  testWidgets('a Recap that could not be written leaves the charts on screen', (
    tester,
  ) async {
    await openCharts(
      tester,
      FakeModelGateway(recapAnswer: const ModelOutOfReach('no signal')),
    );

    expect(
      find.textContaining('No Recap without a connection'),
      findsOneWidget,
    );
    expect(find.text('Ask again'), findsOneWidget);
    expect(find.text('By category'), findsOneWidget);
    expect(find.text('Groceries'), findsWidgets);
  });

  testWidgets('asking again is one tap', (tester) async {
    final model = FakeModelGateway(
      recapAnswer: const ModelOutOfReach('no signal'),
    );
    await openCharts(tester, model);

    model.recapAnswer = FakeModelGateway.wrote('August was an expensive one.');
    await tester.tap(find.text('Ask again'));
    await tester.pumpAndSettle();

    expect(find.text('August was an expensive one.'), findsOneWidget);
  });
}
