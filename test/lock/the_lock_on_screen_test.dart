import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money/lock/device_lock.dart';
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

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      WhereMoneyApp(
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        storesFor: (_) => store.stores,
        model: FakeModelGateway(),
        lock: lock,
        preferences: preferences,
        photograph: (_) async => null,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a returning user is asked before any of their spending shows', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Ikea Damansara'), findsWidgets);
  });

  testWidgets('a refused fingerprint keeps the Ledger covered', (tester) async {
    lock.answer = Unlocking.refused;

    await open(tester);

    expect(find.text('where_money is locked'), findsOneWidget);
    // Still mounted underneath, so that unlocking puts the user back where
    // they were — but covered, and out of reach.
    expect(find.text('Ikea Damansara').hitTestable(), findsNothing);
  });

  testWidgets('trying again after a refusal shows the Ledger', (tester) async {
    lock.answer = Unlocking.refused;
    await open(tester);

    lock.answer = Unlocking.unlocked;
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('where_money is locked'), findsNothing);
    expect(find.text('Ikea Damansara'), findsWidgets);
  });

  testWidgets('a user whose finger has stopped working can still sign out', (
    tester,
  ) async {
    lock.answer = Unlocking.refused;
    await open(tester);

    await tester.tap(find.text('Sign out instead'));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('where_money is locked'), findsNothing);
  });

  testWidgets('a phone with no screen lock is never asked', (tester) async {
    lock
      ..available = LockAvailability.none
      // Would refuse if it were asked, so an uncovered Ledger can only mean
      // it never was.
      ..answer = Unlocking.refused;

    await open(tester);

    expect(find.text('Ikea Damansara').hitTestable(), findsWidgets);
  });

  testWidgets('signing in is not behind the lock', (tester) async {
    lock.answer = Unlocking.refused;
    await tester.pumpWidget(
      WhereMoneyApp(
        signIn: FakeSignInGateway(),
        storesFor: (_) => store.stores,
        model: FakeModelGateway(),
        lock: lock,
        preferences: preferences,
        photograph: (_) async => null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google').hitTestable(), findsOneWidget);
  });
}
