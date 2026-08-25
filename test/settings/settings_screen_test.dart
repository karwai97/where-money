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

  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      WhereMoneyApp(
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        ledgerFor: (_) => store,
        model: FakeModelGateway(),
        lock: lock,
        preferences: preferences,
        photograph: (_) async => null,
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

    await tester.tap(find.text('Lock where_money'));
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
    await tester.tap(find.text('Lock where_money'));
    await tester.pumpAndSettle();
    expect(await preferences.locksOnOpen(), isTrue);
  });
}
