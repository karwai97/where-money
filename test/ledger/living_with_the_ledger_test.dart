import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money/data/receipt_store.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_ledger_store.dart';
import '../scan/inbox_bloc_test.dart' show photograph;

/// The Ledger as something to live in: open an Expense, read what was bought,
/// look at the receipt, fix a mistake, throw a duplicate away.
void main() {
  final today = DateTime.now();
  DateTime thisMonth(int day) =>
      DateTime(today.year, today.month, day.clamp(1, today.day));

  final supermarket = Expense(
    id: 'scan-7',
    merchant: 'Village Grocer Bangsar',
    date: thisMonth(3),
    currency: 'MYR',
    total: 44.10,
    category: 'groceries',
    lineItems: const [
      LineItem(
        description: 'Farm Fresh Milk 1L',
        quantity: 2,
        unitPrice: 8.50,
        amount: 17.00,
        category: 'groceries',
      ),
      LineItem(
        description: 'Free Range Eggs 10s',
        quantity: 1,
        unitPrice: 12.90,
        amount: 12.90,
        category: 'groceries',
      ),
    ],
    source: ExpenseSource.scanned,
    needsReview: false,
    subtotal: 41.60,
    tax: 2.50,
    paymentMethod: 'card',
    receiptPath: 'scan-7.jpg',
  );

  final byHand = Expense(
    id: 'typed-1',
    merchant: 'Kopitiam SS2',
    date: thisMonth(1),
    currency: 'MYR',
    total: 26.00,
    category: 'dining',
    lineItems: const [],
    source: ExpenseSource.manual,
    needsReview: false,
  );

  final abroad = Expense(
    id: 'typed-2',
    merchant: 'Steam',
    date: thisMonth(2),
    currency: 'USD',
    total: 24.99,
    category: 'entertainment',
    lineItems: const [],
    source: ExpenseSource.manual,
    needsReview: false,
  );

  late InMemoryLedgerStore store;
  late InMemoryDevicePreferences preferences;
  late Uint8List receipt;

  setUpAll(() => receipt = photograph(width: 400, height: 600));

  setUp(() {
    store = InMemoryLedgerStore([supermarket, byHand, abroad])
      ..keepReceipt(receiptPathFor('scan-7'), receipt);
    preferences = InMemoryDevicePreferences(locksOnOpen: false);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> openLedger(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1000, 3000)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(
      WhereMoneyApp(
        // The lock is not what these are about, so it is off.
        lock: FakeDeviceLock(),
        preferences: preferences,
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        ledgerFor: (_) => store,
        model: FakeModelGateway(),
        photograph: (_) async => null,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, String merchant) async {
    await openLedger(tester);
    await tester.tap(find.text(merchant));
    await tester.pumpAndSettle();
  }

  testWidgets('the Ledger lists Expenses newest first', (tester) async {
    await openLedger(tester);

    double downFrom(String merchant) =>
        tester.getTopLeft(find.text(merchant)).dy;

    expect(downFrom('Village Grocer Bangsar'), lessThan(downFrom('Steam')));
    expect(downFrom('Steam'), lessThan(downFrom('Kopitiam SS2')));
  });

  testWidgets('the Ledger names Categories the way the charts do', (
    tester,
  ) async {
    await openLedger(tester);

    expect(find.textContaining('Dining out'), findsOneWidget);
    expect(find.textContaining('dining'), findsNothing);
  });

  testWidgets('what was actually bought is there when the Expense is opened', (
    tester,
  ) async {
    await open(tester, 'Village Grocer Bangsar');

    expect(find.text('Farm Fresh Milk 1L'), findsOneWidget);
    expect(find.text('Free Range Eggs 10s'), findsOneWidget);
    expect(find.textContaining('MYR 17.00'), findsOneWidget);
  });

  testWidgets('the receipt that produced the Expense is there too', (
    tester,
  ) async {
    await open(tester, 'Village Grocer Bangsar');
    await tester.pumpAndSettle();

    expect(find.byTooltip('Zoom into the receipt'), findsOneWidget);
  });

  testWidgets('an Expense whose photo did not come to this device says so '
      'rather than breaking', (tester) async {
    store = InMemoryLedgerStore([supermarket]);
    // A Ledger of one photoless Expense is also a Ledger restored onto a new
    // phone. That has already been said to this user; this is about what the
    // Expense screen does afterwards.
    await preferences.rememberExplainingMissingPhotos(
      FakeSignInGateway.kai.uid,
    );

    await open(tester, 'Village Grocer Bangsar');
    await tester.pumpAndSettle();

    expect(find.textContaining('not on this device'), findsOneWidget);
    expect(find.byTooltip('Zoom into the receipt'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an Expense typed by hand has no receipt to be missing', (
    tester,
  ) async {
    await open(tester, 'Kopitiam SS2');
    await tester.pumpAndSettle();

    expect(find.textContaining('not on this device'), findsNothing);
  });

  testWidgets('what the app read and what the user typed are told apart at a '
      'glance', (tester) async {
    await openLedger(tester);

    expect(find.byTooltip('Read from a receipt'), findsOneWidget);
    expect(find.byTooltip('Typed by hand'), findsNWidgets(2));
  });

  testWidgets('an Expense paid in another currency shows the currency it was '
      'paid in', (tester) async {
    await openLedger(tester);

    expect(find.text('USD 24.99'), findsOneWidget);

    await tester.tap(find.text('Steam'));
    await tester.pumpAndSettle();

    expect(find.text('USD 24.99'), findsOneWidget);
    expect(find.textContaining('not in your monthly totals'), findsOneWidget);
  });

  testWidgets('a mistake noticed a week later is fixable, and the Check runs '
      'while it is being fixed', (tester) async {
    await open(tester, 'Village Grocer Bangsar');
    await tester.tap(find.byTooltip('Correct this Expense'));
    await tester.pumpAndSettle();

    expect(find.text('Correct this Expense'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Total').first,
      '99.00',
    );
    await tester.pumpAndSettle();

    expect(find.text('Total does not add up'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Total').first,
      '44.10',
    );
    await tester.pumpAndSettle();

    expect(find.text('Total does not add up'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'Merchant').first,
      'Village Grocer KL',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = store.contents.firstWhere((e) => e.id == 'scan-7');
    expect(store.contents, hasLength(3));
    expect(saved.merchant, 'Village Grocer KL');
    // The total was typed over and typed back, which Review has always counted
    // as a correction — the user did have to look at it.
    expect(saved.correctedFields, ['total', 'merchant']);
    expect(find.text('Village Grocer KL'), findsWidgets);
  });

  testWidgets('an Expense is not deleted without being asked about first', (
    tester,
  ) async {
    await open(tester, 'Kopitiam SS2');
    await tester.tap(find.byTooltip('Delete this Expense'));
    await tester.pumpAndSettle();

    expect(find.text('Keep it'), findsOneWidget);
    expect(
      find.textContaining('receipt photo stays'),
      findsNothing,
      reason: 'an Expense typed by hand has no photo to promise to keep',
    );

    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    expect(store.contents, hasLength(3));
  });

  testWidgets('a duplicate confirmed for deletion goes from the Ledger', (
    tester,
  ) async {
    await open(tester, 'Kopitiam SS2');
    await tester.tap(find.byTooltip('Delete this Expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(
      store.contents.map((e) => e.merchant),
      isNot(contains('Kopitiam SS2')),
    );
    expect(find.text('Kopitiam SS2'), findsNothing);
  });

  testWidgets('deleting a scanned Expense says what happens to its photo', (
    tester,
  ) async {
    await open(tester, 'Village Grocer Bangsar');
    await tester.tap(find.byTooltip('Delete this Expense'));
    await tester.pumpAndSettle();

    expect(find.textContaining('receipt photo stays'), findsOneWidget);
  });
}
