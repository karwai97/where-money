import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/data/erasing_a_ledger.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';

/// The order is the whole of what this class is, so the order is what is
/// pinned here. Everything it reaches — the Ledger, the Scans, the phone's
/// memory, the account — deletes itself; the only thing that can go wrong at
/// this level is doing them in the wrong sequence, or letting the wrong one
/// stop the rest.
///
/// The screen's side of an erasure is
/// `test/session/a_guest_keeps_a_real_ledger_test.dart`.
void main() {
  late InMemoryLedgerStore store;
  late InMemoryDevicePreferences preferences;
  late FakeSignInGateway identity;

  const uid = 'guest-uid';

  final expense = Expense(
    id: 'seed-1',
    merchant: 'Village Grocer',
    date: DateTime(2026, 8, 21),
    currency: 'MYR',
    total: 42.10,
    category: 'groceries',
    lineItems: const [],
    source: ExpenseSource.scanned,
    needsReview: false,
  );

  setUp(() async {
    store = InMemoryLedgerStore([expense]);
    await store.capture(Uint8List.fromList([1, 2, 3]));
    preferences = InMemoryDevicePreferences(homeCurrency: 'MYR');
    identity = FakeSignInGateway(alreadySignedIn: FakeSignInGateway.guest);
  });

  ErasingALedger erasing() => ErasingWhatAUidOwns(
    uid: uid,
    stores: store.stores,
    preferences: preferences,
    identity: identity,
  );

  test('everything the uid owns goes, and the account goes last', () async {
    await erasing().erase();

    expect(store.contents, isEmpty);
    expect(store.waiting, isEmpty);
    expect(preferences.forgotten, contains(uid));
    expect(await preferences.homeCurrency(), isNull);
    expect(identity.deleted, isTrue);
    // Nothing is left saying an erasure is owed: this one is finished.
    expect(await preferences.erasureUnderWay(), isNull);
  });

  test(
    'a refused Ledger stops the whole thing, and takes nothing with it',
    () async {
      store.refuseErasing = StateError('no network');

      await expectLater(erasing().erase(), throwsStateError);

      // The account above all: deleting it would take away the only identity
      // that could ever reach these Expenses again.
      expect(identity.deleted, isFalse);
      expect(store.contents, [expense]);
      expect(store.waiting, hasLength(1));
      expect(preferences.forgotten, isEmpty);
    },
  );

  test('a refused Ledger leaves no record to resume from', () async {
    store.refuseErasing = StateError('no network');

    await expectLater(erasing().erase(), throwsStateError);

    // The record means "started, and nobody knows whether it finished". A
    // refusal caught here is not that. Left set, it would arm some later
    // launch to delete a Ledger the user may by then have signed in to keep
    // — linking leaves the uid exactly as it was.
    expect(await preferences.erasureUnderWay(), isNull);
  });

  test(
    'a phone that will not delete its Scans does not stop the rest',
    () async {
      store.refuseErasingScans = StateError('the directory is busy');

      await erasing().erase();

      expect(store.contents, isEmpty);
      expect(identity.deleted, isTrue);
      expect(await preferences.erasureUnderWay(), isNull);
    },
  );

  test('nor does one that will not forget what it remembers', () async {
    preferences.refuseForgetting = StateError('no room');

    await erasing().erase();

    expect(store.contents, isEmpty);
    expect(store.waiting, isEmpty);
    expect(identity.deleted, isTrue);
    expect(await preferences.erasureUnderWay(), isNull);
  });
}
