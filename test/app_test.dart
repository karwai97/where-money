import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money_core/where_money_core.dart';

import 'fakes/fake_sign_in_gateway.dart';
import 'fakes/in_memory_ledger_store.dart';

void main() {
  late FakeSignInGateway signIn;
  late InMemoryLedgerStore store;

  setUp(() {
    signIn = FakeSignInGateway();
    store = InMemoryLedgerStore();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      WhereMoneyApp(
        signIn: signIn,
        ledgerFor: (_) => store,
        photograph: (_) async => null,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a signed-out user is offered Google and nothing else', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Ledger'), findsNothing);
  });

  testWidgets('signing in shows the Ledger', (tester) async {
    await open(tester);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Ledger'), findsOneWidget);
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

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Ikea Damansara'), findsNothing);
    expect(find.text('Ledger'), findsNothing);
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
