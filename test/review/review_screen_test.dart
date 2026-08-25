import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_ledger_store.dart';

/// Widget tests, because these criteria are about what is on the screen. As in
/// ticket 03, assertions are on text the user can read; widget types appear
/// only as a way of reaching a field to type into it.
void main() {
  late InMemoryLedgerStore store;
  final model = FakeModelGateway();

  setUp(() => store = InMemoryLedgerStore());

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  /// Review is a long form and the default test viewport is a small
  /// phone, so half of it would never be built. A tall surface is cheaper
  /// than scrolling to every field.
  void useATallScreen(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(1000, 4000)
      ..devicePixelRatio = 1;
  }

  Future<void> openLedger(WidgetTester tester) async {
    useATallScreen(tester);
    await tester.pumpWidget(
      WhereMoneyApp(
        // The lock is not what these are about, so it is off.
        lock: FakeDeviceLock(),
        preferences: InMemoryDevicePreferences(locksOnOpen: false),
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        ledgerFor: (_) => store,
        model: model,
        photograph: (_) async => null,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openReview(WidgetTester tester) async {
    await openLedger(tester);
    await tester.tap(find.byTooltip('Add an Expense by hand'));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String label, String value) async {
    await tester.enterText(find.widgetWithText(TextField, label).first, value);
    await tester.pumpAndSettle();
  }

  Future<void> fillIn(WidgetTester tester) async {
    await type(tester, 'Merchant', 'Kopitiam SS2');
    await type(tester, 'Date', '2026-08-22');
    await type(tester, 'Currency', 'MYR');
    await type(tester, 'Total', '26.00');
  }

  testWidgets('adding by hand opens Review with nothing filled in', (
    tester,
  ) async {
    await openReview(tester);

    expect(find.text('Add an Expense'), findsOneWidget);
    expect(find.text('Merchant'), findsOneWidget);
    expect(find.text('Kopitiam SS2'), findsNothing);
  });

  testWidgets('what the Check noticed is spelled out above the fields', (
    tester,
  ) async {
    await openReview(tester);

    expect(find.text('No total'), findsOneWidget);
    expect(
      find.textContaining('Total is zero or negative'),
      findsOneWidget,
      reason: 'a Finding is a sentence, not a rule name',
    );
  });

  testWidgets('a total that does not add up loses its Finding once corrected', (
    tester,
  ) async {
    await openReview(tester);

    await type(tester, 'Subtotal', '20.00');
    await type(tester, 'Tax', '1.20');
    await type(tester, 'Total', '30.00');

    expect(find.text('Total does not add up'), findsOneWidget);

    await type(tester, 'Total', '21.20');

    expect(find.text('Total does not add up'), findsNothing);
  });

  testWidgets('a Line Item can be added and removed again', (tester) async {
    await openReview(tester);

    expect(find.text('Description'), findsNothing);

    await tester.tap(find.text('Add a Line Item'));
    await tester.pumpAndSettle();

    expect(find.text('Description'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove this Line Item'));
    await tester.pumpAndSettle();

    expect(find.text('Description'), findsNothing);
  });

  testWidgets('the Category is chosen from the taxonomy, never typed', (
    tester,
  ) async {
    await openReview(tester);

    await tester.tap(find.text('Other').first);
    await tester.pumpAndSettle();

    expect(find.text('Dining out'), findsWidgets);
    expect(find.text('Groceries'), findsWidgets);
    expect(
      find.text('Uncategorised'),
      findsNothing,
      reason: 'the only Categories on offer are the ones the taxonomy names',
    );
  });

  testWidgets('committing writes one Expense and returns to the Ledger', (
    tester,
  ) async {
    await openReview(tester);
    await fillIn(tester);

    await tester.tap(find.text('Add to Ledger'));
    await tester.pumpAndSettle();

    expect(find.text('Ledger'), findsOneWidget);
    expect(store.contents, hasLength(1));
    expect(find.text('Kopitiam SS2'), findsOneWidget);
  });

  testWidgets('leaving Review and going back in keeps the typing', (
    tester,
  ) async {
    await openReview(tester);
    await type(tester, 'Merchant', 'Kopitiam SS2');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Add an Expense'), findsNothing);

    await tester.tap(find.byTooltip('Add an Expense by hand'));
    await tester.pumpAndSettle();

    expect(find.text('Kopitiam SS2'), findsOneWidget);
    expect(store.contents, isEmpty);
  });

  testWidgets('a refused write says so and leaves the typing on screen', (
    tester,
  ) async {
    store.refuseWrites = StateError('denied');

    await openReview(tester);
    await fillIn(tester);
    await tester.tap(find.text('Add to Ledger'));
    await tester.pumpAndSettle();

    expect(find.textContaining('was not saved'), findsOneWidget);
    expect(find.text('Kopitiam SS2'), findsOneWidget);
  });
}
