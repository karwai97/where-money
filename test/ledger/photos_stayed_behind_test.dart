import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/data/receipt_store.dart';
import 'package:where_money/ledger/photos_stayed_behind.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';

void main() {
  late InMemoryLedgerStore store;
  late InMemoryDevicePreferences preferences;

  setUp(() {
    store = InMemoryLedgerStore();
    preferences = InMemoryDevicePreferences();
  });

  PhotosStayedBehind restored() =>
      PhotosStayedBehind(store, preferences, 'kai-uid');

  Expense scanned(String id) => Expense(
    id: id,
    merchant: 'Village Grocer',
    date: DateTime(2026, 8, 20),
    currency: 'MYR',
    total: 42.10,
    category: 'groceries',
    lineItems: const [],
    source: ExpenseSource.scanned,
    needsReview: false,
    receiptPath: receiptPathFor(id),
  );

  Expense byHand(String id) => Expense(
    id: id,
    merchant: 'Parking',
    date: DateTime(2026, 8, 21),
    currency: 'MYR',
    total: 5,
    category: 'transport',
    lineItems: const [],
    source: ExpenseSource.manual,
    needsReview: false,
  );

  blocTest<PhotosStayedBehind, bool>(
    'a Ledger restored onto a new phone says the photos did not come with it',
    build: restored,
    act: (notice) => notice.considered([scanned('a'), scanned('b')]),
    expect: () => [true],
  );

  blocTest<PhotosStayedBehind, bool>(
    'the phone the receipts were photographed on says nothing',
    build: () {
      store.keepReceipt(receiptPathFor('a'), Uint8List.fromList([1, 2, 3]));
      return restored();
    },
    act: (notice) => notice.considered([scanned('a'), scanned('b')]),
    expect: () => <bool>[],
  );

  blocTest<PhotosStayedBehind, bool>(
    'a Ledger of Expenses typed by hand has no photos to have lost',
    build: restored,
    act: (notice) => notice.considered([byHand('a')]),
    expect: () => <bool>[],
  );

  blocTest<PhotosStayedBehind, bool>(
    'an empty Ledger says nothing',
    build: restored,
    act: (notice) => notice.considered([]),
    expect: () => <bool>[],
  );

  blocTest<PhotosStayedBehind, bool>(
    'it is said once, not on every read of the Ledger',
    build: restored,
    act: (notice) async {
      await notice.considered([scanned('a')]);
      await notice.acknowledged();
      await notice.considered([scanned('a'), scanned('b')]);
    },
    expect: () => [true, false],
  );

  blocTest<PhotosStayedBehind, bool>(
    'it is not said again on the next launch',
    build: () {
      preferences.rememberExplainingMissingPhotos('kai-uid');
      return restored();
    },
    act: (notice) => notice.considered([scanned('a')]),
    expect: () => <bool>[],
  );
}
