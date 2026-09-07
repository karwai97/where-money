import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money_core/where_money_core.dart';

import 'fakes/fake_device_lock.dart';
import 'fakes/in_memory_device_preferences.dart';
import 'fakes/fake_model_gateway.dart';
import 'fakes/fake_sign_in_gateway.dart';
import 'fakes/in_memory_ledger_store.dart';

void main() {
  late FakeSignInGateway signIn;
  late InMemoryLedgerStore store;
  final model = FakeModelGateway();

  setUp(() {
    signIn = FakeSignInGateway();
    store = InMemoryLedgerStore();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      WhereMoneyApp(
        // The lock is not what these are about, so it is off.
        lock: FakeDeviceLock(),
        preferences: InMemoryDevicePreferences(locksOnOpen: false),
        signIn: signIn,
        storesFor: (_) => store.stores,
        model: model,
        photograph: (_) async => null,
        // The seeded Ledger hangs off a fixed date, so the month the screen
        // opens on has to be fixed too — otherwise these pass until the
        // calendar moves on and then fail on an empty month.
        clock: () => DateTime(2026, 8, 23),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a signed-out user is offered Google and nothing else', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('LEDGER'), findsNothing);
  });

  testWidgets('signing in shows the Ledger', (tester) async {
    await open(tester);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('LEDGER'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('a returning user goes straight to their Ledger', (tester) async {
    signIn = FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai);
    store = InMemoryLedgerStore(seedLedger(around: DateTime(2026, 8, 23)));

    await open(tester);

    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Ikea Damansara'), findsWidgets);
  });

  testWidgets('signing out clears the Ledger from view', (tester) async {
    signIn = FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai);
    store = InMemoryLedgerStore(seedLedger(around: DateTime(2026, 8, 23)));

    await open(tester);
    expect(find.text('Ikea Damansara'), findsWidgets);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Ikea Damansara'), findsNothing);
    expect(find.text('LEDGER'), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('an empty Ledger says so rather than sitting blank', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing here yet'), findsOneWidget);
  });

  testWidgets('a sign-in that failed is explained on the sign-in screen', (
    tester,
  ) async {
    signIn.refuse = StateError('no network');

    await open(tester);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no network'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
