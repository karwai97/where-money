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

  Future<void> openSettings(
    WidgetTester tester, {
    Knobs knobs = const Knobs(),
  }) async {
    await tester.pumpWidget(
      WhereMoneyApp(
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        storesFor: (_) => store.stores,
        model: FakeModelGateway(),
        lock: lock,
        preferences: preferences,
        knobs: knobs,
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

  testWidgets('the knobs this launch is running on are on screen', (
    tester,
  ) async {
    await openSettings(
      tester,
      knobs: const Knobs(
        model: 'gpt-5-mini',
        effort: 'medium',
        longEdge: 1440,
        dailyCap: 15,
      ),
    );

    expect(find.text('Model: gpt-5-mini'), findsOneWidget);
    expect(find.text('Reasoning effort: medium'), findsOneWidget);
    expect(find.text('Image long edge: 1440 px'), findsOneWidget);
    expect(find.text('Daily cap: 15 Scans'), findsOneWidget);
  });

  testWidgets('what Review kept having to correct is on screen', (
    tester,
  ) async {
    // Three scanned and one typed by hand, the hand-typed one carrying a
    // correction on every field. Counting it would say the Model misreads the
    // total, which it has never been asked to.
    store = InMemoryLedgerStore(seedCorrectedLedger());

    await openSettings(tester);

    expect(find.text('3 receipts read, 1 left alone.'), findsOneWidget);
    expect(find.text('Merchant, corrected on 2 of 3'), findsOneWidget);
    expect(find.text('Category, corrected on 1 of 3'), findsOneWidget);
  });

  testWidgets('a Ledger nothing has been read into says so', (tester) async {
    store = InMemoryLedgerStore();

    await openSettings(tester);

    expect(find.textContaining('No receipt has been read yet'), findsOneWidget);
  });
}
