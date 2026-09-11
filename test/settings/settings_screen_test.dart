import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money/lock/device_lock.dart';
import 'package:where_money/session/sign_in_gateway.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';

void main() {
  late FakeDeviceLock lock;
  late InMemoryDevicePreferences preferences;
  late InMemoryLedgerStore store;

  setUp(() {
    lock = FakeDeviceLock();
    preferences = InMemoryDevicePreferences();
    store = InMemoryLedgerStore(seedLedger(around: DateTime(2026, 8, 23)));
  });

  Future<void> openSettings(
    WidgetTester tester, {
    SignedInUser who = FakeSignInGateway.kai,
  }) async {
    await tester.pumpWidget(
      WhereMoneyApp(
        signIn: FakeSignInGateway(alreadySignedIn: who),
        storesFor: (_) => store.stores,
        model: FakeModelGateway(),
        lock: lock,
        preferences: preferences,
        photograph: (_) async => null,
        clock: () => DateTime(2026, 8, 23),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

  testWidgets('the lock can be turned off, and the choice sticks', (
    tester,
  ) async {
    await openSettings(tester);

    // The switch rather than the words beside it: the label sits in the row's
    // own column now, not inside the control.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(await preferences.locksOnOpen(), isFalse);
  });

  testWidgets('a phone with no fingerprint says it will ask for the PIN', (
    tester,
  ) async {
    lock.available = LockAvailability.deviceCredential;

    await openSettings(tester);

    expect(find.textContaining('asks for your PIN'), findsOneWidget);
  });

  testWidgets('a phone with no screen lock says what to do about it', (
    tester,
  ) async {
    lock.available = LockAvailability.none;

    await openSettings(tester);

    expect(find.textContaining('no screen lock'), findsOneWidget);

    // Nothing to switch on: there is no question this phone could ask.
    await tester.tap(find.byType(Switch), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(await preferences.locksOnOpen(), isTrue);
  });

  testWidgets('an account holder is told whose Ledger this is', (tester) async {
    await openSettings(tester);

    expect(find.text('Kai'), findsOneWidget);
    expect(find.text('kai@example.com · Google'), findsOneWidget);
    // The disc says the same thing a second time and is decoration; the two
    // lines beside it are what a screen reader is given.
    expect(find.text('K'), findsOneWidget);
  });

  testWidgets('an account Google named nobody reads as its address', (
    tester,
  ) async {
    await openSettings(tester, who: FakeSignInGateway.nameless);

    // The address takes the first line rather than a made-up name, and the
    // line under it is left with the product name alone.
    expect(find.text('nameless@example.com'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.textContaining('nameless@example.com ·'), findsNothing);
  });
}
