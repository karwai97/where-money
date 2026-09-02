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

  Future<void> openLedger(WidgetTester tester, {DateTime? on}) async {
    useATallScreen(tester);
    await tester.pumpWidget(
      WhereMoneyApp(
        // The lock is not what these are about, so it is off.
        lock: FakeDeviceLock(),
        preferences: InMemoryDevicePreferences(locksOnOpen: false),
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        storesFor: (_) => store.stores,
        model: model,
        photograph: (_) async => null,
        // Pinned, and matching the date typed into Review below: an Expense
        // committed from it has to land in the month the Ledger is showing,
        // and the Check has to agree that the date has happened.
        clock: () => on ?? DateTime(2026, 8, 22),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openReview(WidgetTester tester, {DateTime? on}) async {
    await openLedger(tester, on: on);
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

  // The Check asks what day it is too, and asks it below Review rather than
  // above, so a clock the app was handed has to reach it. Without that, a
  // purchase dated today is called a date in the future the moment the fixed
  // date these tests type falls behind the machine's calendar — the same rot,
  // one seam over.
  testWidgets('a purchase dated the day it was bought is not called a date in '
      'the future', (tester) async {
    await openReview(tester, on: DateTime(2028, 3, 1));
    await type(tester, 'Merchant', 'Kopitiam SS2');
    await type(tester, 'Date', '2028-03-01');
    await type(tester, 'Currency', 'MYR');
    await type(tester, 'Total', '26.00');

    expect(find.text('Date in the future'), findsNothing);

    await tester.tap(find.text('Add to Ledger'));
    await tester.pumpAndSettle();

    expect(store.contents, hasLength(1));
  });

  // Both of these are dates the Check has copy for and the card above the
  // fields is already complaining about, so they are exactly the dates a user
  // taps the calendar to correct. The picker asserts that the date it opens on
  // falls inside the range it was given, and the range was the ordinary one.
  testWidgets('the calendar opens on a future date rather than refusing to '
      'open at all', (tester) async {
    await openReview(tester, on: DateTime(2026, 6, 15));
    // What a card expiry misread as the purchase date looks like.
    await type(tester, 'Date', '2027-04-01');

    await tester.tap(find.byTooltip('Pick a date'));
    await tester.pumpAndSettle();

    expect(find.text('OK'), findsOneWidget);
    expect(
      find.textContaining('April 2027'),
      findsWidgets,
      reason: 'the calendar should open on the month the field names',
    );
  });

  testWidgets('the calendar opens on a receipt older than the range it '
      'ordinarily offers', (tester) async {
    await openReview(tester, on: DateTime(2026, 6, 15));
    await type(tester, 'Date', '2018-06-14');

    await tester.tap(find.byTooltip('Pick a date'));
    await tester.pumpAndSettle();

    expect(find.text('OK'), findsOneWidget);
    expect(find.textContaining('June 2018'), findsWidgets);
  });

  // The widening above is conditional, and this is the condition: a field
  // inside the ordinary range leaves the ceiling where it was, so a day that
  // has not happened yet is still not a day anybody can choose.
  // Pinned well away from whatever day this is really run on, so that the
  // ceiling being tested is the clock the screen was handed rather than the
  // machine's — which would make the whole assertion pass by accident.
  testWidgets('an ordinary date leaves the calendar ending today', (
    tester,
  ) async {
    await openReview(tester, on: DateTime(2026, 6, 15));
    await type(tester, 'Date', '2026-06-15');

    await tester.tap(find.byTooltip('Pick a date'));
    await tester.pumpAndSettle();

    // Tomorrow, in the month the calendar is showing.
    await tester.tap(find.text('16'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.text('2026-06-15'),
      findsOneWidget,
      reason: 'the 16th has not happened yet, so tapping it chose nothing',
    );
    expect(find.text('2026-06-16'), findsNothing);
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
