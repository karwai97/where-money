import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money/data/receipt_store.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';

/// A Ledger of scanned Expenses, each pointing at a receipt photo. Whether the
/// photo is on this phone is what these tests vary.
final restored = [
  for (var index = 1; index <= 3; index++)
    Expense(
      id: 'seed-$index',
      merchant: 'Village Grocer',
      date: DateTime(2026, 8, 20 + index),
      currency: 'MYR',
      total: 42.10 * index,
      category: 'groceries',
      lineItems: const [],
      source: ExpenseSource.scanned,
      needsReview: false,
      receiptPath: receiptPathFor('scan-$index'),
    ),
];

void main() {
  late InMemoryDevicePreferences preferences;
  late InMemoryLedgerStore store;

  setUp(() {
    preferences = InMemoryDevicePreferences(locksOnOpen: false);
    store = InMemoryLedgerStore(restored);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      WhereMoneyApp(
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        ledgerFor: (_) => store,
        model: FakeModelGateway(),
        lock: FakeDeviceLock(),
        preferences: preferences,
        photograph: (_) async => null,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a Ledger that came back without its photos says so', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('The photos stayed behind'), findsOneWidget);
    expect(find.textContaining('never leave the phone'), findsOneWidget);
  });

  testWidgets('the phone the receipts were taken on says nothing', (
    tester,
  ) async {
    store.keepReceipt(receiptPathFor('scan-1'), Uint8List.fromList([1, 2, 3]));

    await open(tester);

    expect(find.text('The photos stayed behind'), findsNothing);
  });

  testWidgets('it is said once, and not again on the next launch', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('The photos stayed behind'), findsNothing);

    await open(tester);

    expect(find.text('The photos stayed behind'), findsNothing);
  });
}
