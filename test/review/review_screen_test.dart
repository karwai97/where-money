import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_ledger_store.dart';
import '../scan/inbox_bloc_test.dart' show photograph;
import 'where_things_sit.dart';

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

  Future<void> openLedger(
    WidgetTester tester, {
    DateTime? on,
    Size? screen,
  }) async {
    if (screen == null) {
      useATallScreen(tester);
    } else {
      tester.view
        ..physicalSize = screen
        ..devicePixelRatio = 1;
    }
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

  /// Review over what the Model read. The Scan is seeded already read rather
  /// than photographed: what these are about is what Review does with an
  /// Extraction, not how it came by one.
  Future<void> openReviewOfAScan(
    WidgetTester tester,
    Extraction read, {
    Size? screen,
  }) async {
    final scan = await store.capture(photograph(width: 300, height: 400));
    await store.put(scan.movedTo(ScanState.extracted, extraction: read));

    await openLedger(tester, on: fixtureNow, screen: screen);
    await tester.tap(find.byTooltip('Inbox, 1 waiting'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
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

  testWidgets('what the Check noticed is spelled out under the field it is '
      'about', (tester) async {
    await openReview(tester);

    expect(find.text('No total'), findsOneWidget);
    expect(
      find.textContaining('Total is zero or negative'),
      findsOneWidget,
      reason: 'a Finding is a sentence, not a rule name',
    );

    final saying = rectOf(tester, find.text('No merchant'));
    expect(
      saying.top,
      greaterThan(fieldNamed(tester, 'Merchant').bottom),
      reason: 'the complaint sits under the field a correction would reach',
    );
    expect(
      saying.bottom,
      lessThan(fieldNamed(tester, 'Date').top),
      reason: 'and above the next field, not floating over it',
    );
  });

  // With the Findings pinned above the form, this is what typing did: the card
  // shrank, and every field slid up under the finger correcting one of them.
  testWidgets('nothing the Check noticed takes room above the form', (
    tester,
  ) async {
    await openReview(tester);
    final noticed = fieldNamed(tester, 'Merchant');

    await fillIn(tester);

    expect(find.text('No total'), findsNothing);
    expect(find.text('No merchant'), findsNothing);
    expect(
      fieldNamed(tester, 'Merchant'),
      noticed,
      reason: 'the form starts in the same place whatever the Check found',
    );
  });

  testWidgets('correcting a field does not move the field being corrected', (
    tester,
  ) async {
    await openReview(tester);
    final total = fieldNamed(tester, 'Total');

    await type(tester, 'Total', '26.00');

    expect(find.text('No total'), findsNothing);
    expect(
      fieldNamed(tester, 'Total'),
      total,
      reason: 'a Finding clearing itself is below the field that cleared it',
    );
  });

  testWidgets('a field with two Findings shows both', (tester) async {
    await openReview(tester);

    await type(tester, 'Subtotal', '20.00');
    await type(tester, 'Tax', '1.20');

    final total = fieldNamed(tester, 'Total');
    for (final saying in const ['No total', 'Total does not add up']) {
      expect(find.text(saying), findsOneWidget);
      expect(
        rectOf(tester, find.text(saying)).top,
        greaterThan(total.bottom),
        reason: 'this is about the total, so it belongs under it',
      );
    }
    expect(
      rectOf(tester, find.text('Line Items')).top,
      greaterThan(rectOf(tester, find.text('Total does not add up')).bottom),
      reason: 'both fit between the total and what comes after it',
    );
  });

  // The icon is the whole of the distinction once the Findings are scattered
  // down the form: a card could group them under one heading, and a sentence
  // beside a field cannot.
  testWidgets('a fail is marked differently from a warn', (tester) async {
    await openReview(tester);

    // A blank form is one fail — no total — and three warnings.
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsNWidgets(3));

    await type(tester, 'Total', '26.00');

    expect(
      find.byIcon(Icons.error_outline),
      findsNothing,
      reason: 'the only fail was the total, and the total is now a number',
    );
    expect(find.byIcon(Icons.info_outline), findsNWidgets(3));
  });

  // The Check costs nothing and calls nothing, so it is not an authority. A
  // discount it cannot see is not a reason to refuse to record what was paid.
  testWidgets('a fail standing does not stop the Expense being committed', (
    tester,
  ) async {
    await openReview(tester);
    await type(tester, 'Merchant', 'Kopitiam SS2');
    await type(tester, 'Date', '2026-08-22');
    await type(tester, 'Currency', 'MYR');

    expect(find.text('No total'), findsOneWidget);

    await tester.tap(find.text('Add to Ledger'));
    await tester.pumpAndSettle();

    expect(find.text('Ledger'), findsOneWidget);
    expect(store.contents, hasLength(1));
  });

  testWidgets('a photo that is not a receipt is said across the whole form', (
    tester,
  ) async {
    await openReviewOfAScan(tester, notAReceiptExtraction);

    expect(find.text('Not a receipt'), findsOneWidget);
    expect(
      find.textContaining('is not a receipt'),
      findsOneWidget,
      reason: 'a claim about the photograph, not about a field to go and fix',
    );
    expect(
      rectOf(tester, find.text('Not a receipt')).bottom,
      lessThan(fieldNamed(tester, 'Merchant').top),
    );
    for (final other in const [
      'No total',
      'No merchant',
      'No date',
      'Currency unclear',
    ]) {
      expect(
        find.text(other),
        findsNothing,
        reason: 'nothing shares the screen with a photo that is not a receipt',
      );
    }
  });

  testWidgets('the banner stays while the form under it scrolls', (
    tester,
  ) async {
    await openReviewOfAScan(
      tester,
      notAReceiptExtraction,
      screen: const Size(1000, 560),
    );

    final banner = rectOf(tester, find.text('Not a receipt'));
    expect(find.text('Merchant'), findsOneWidget);

    // The form's own scroll view, reached by type the way a field is.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(
      find.text('Merchant'),
      findsNothing,
      reason: 'the form did move, so the banner had something to sit still for',
    );
    expect(
      rectOf(tester, find.text('Not a receipt')),
      banner,
      reason: 'a claim about the whole photograph is not one to scroll past',
    );
  });

  // A phone, deliberately: a form too tall for the screen is the whole
  // complaint this answers, and permanent height is what it costs.
  testWidgets('what names no field scrolls away with the form', (tester) async {
    await openReviewOfAScan(
      tester,
      flawedExtraction,
      screen: const Size(400, 900),
    );

    expect(find.text('Model asked for review'), findsOneWidget);

    await tester.drag(
      find.text('Model asked for review'),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    expect(find.text('Model asked for review'), findsNothing);
  });

  testWidgets('the line saying a receipt came back clean scrolls away with '
      'the form', (tester) async {
    await openReviewOfAScan(
      tester,
      cleanExtraction,
      screen: const Size(400, 900),
    );

    const clean = 'Everything on this receipt adds up';
    expect(find.textContaining(clean), findsOneWidget);

    await tester.drag(find.textContaining(clean), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.textContaining(clean), findsNothing);
  });

  testWidgets('a refused commit is at the top of the form and scrolls with '
      'it', (tester) async {
    store.refuseWrites = StateError('denied');

    await openReview(tester);
    await fillIn(tester);

    // Shrunk to a phone only now that the typing is in: what this is about is
    // a form taller than the screen, and every field has to be reachable to
    // fill it in.
    tester.view
      ..physicalSize = const Size(400, 560)
      ..devicePixelRatio = 1;
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Add to Ledger'),
      200,
      // The form's own scroll view. Every TextField holds one too, and the
      // outermost is the one this drags.
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Ledger'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('was not saved'),
      findsNothing,
      reason:
          'the form is scrolled to its button, and the notice is at its top',
    );

    await tester.drag(find.text('Add to Ledger'), const Offset(0, 900));
    await tester.pumpAndSettle();

    expect(find.textContaining('was not saved'), findsOneWidget);
    expect(find.text('Kopitiam SS2'), findsOneWidget);
  });

  testWidgets('what the rows do not add up to is said with the rows', (
    tester,
  ) async {
    await openReviewOfAScan(tester, flawedExtraction);

    expect(find.text('Line items do not match subtotal'), findsOneWidget);

    final saying = rectOf(
      tester,
      find.text('Line items do not match subtotal'),
    );
    expect(
      saying.top,
      greaterThan(rectOf(tester, find.text('Line Items')).bottom),
    );
    expect(
      saying.bottom,
      lessThan(rectOf(tester, find.text('Description')).top),
      reason: 'against the set of rows, above the first of them',
    );
  });

  testWidgets('a row that does not multiply out is said with the Line Items, '
      'not against the row', (tester) async {
    await openReview(tester);

    await tester.tap(find.text('Add a Line Item'));
    await tester.pumpAndSettle();
    await type(tester, 'Qty', '2');
    await type(tester, 'Unit price', '3.00');
    await type(tester, 'Amount', '5.00');

    expect(
      find.text('Line arithmetic off'),
      findsOneWidget,
      reason: 'said once, with the section — the Finding carries no row index',
    );
    expect(
      rectOf(tester, find.text('Line arithmetic off')).bottom,
      lessThan(rectOf(tester, find.text('Description')).top),
    );
  });

  // A Category outside the taxonomy cannot be typed — the dropdown is closed —
  // so only an Extraction can carry one in.
  testWidgets('a row whose Category is not in the taxonomy is said with the '
      'Line Items', (tester) async {
    await openReviewOfAScan(
      tester,
      cleanExtraction.copyWith(
        lineItems: [
          ...cleanExtraction.lineItems.take(3),
          const LineItem(
            description: 'Cavendish Bananas',
            quantity: 1,
            unitPrice: 7.30,
            amount: 7.30,
            category: 'fruit',
          ),
        ],
      ),
    );

    expect(find.text('Unknown item category'), findsOneWidget);
    expect(
      rectOf(tester, find.text('Unknown item category')).top,
      greaterThan(rectOf(tester, find.text('Line Items')).bottom),
    );
    expect(
      rectOf(tester, find.text('Unknown item category')).bottom,
      lessThan(rectOf(tester, find.text('Description')).top),
    );
  });

  testWidgets('a Finding about the rows goes when the row it is about goes', (
    tester,
  ) async {
    await openReview(tester);

    await tester.tap(find.text('Add a Line Item'));
    await tester.pumpAndSettle();
    await type(tester, 'Amount', '5.00');

    expect(find.text('Line items do not match total'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove this Line Item'));
    await tester.pumpAndSettle();

    expect(find.text('Line items do not match total'), findsNothing);
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

  testWidgets('a refused write says so at the top of the form and leaves the '
      'typing on screen', (tester) async {
    store.refuseWrites = StateError('denied');

    await openReview(tester);
    await fillIn(tester);
    await tester.tap(find.text('Add to Ledger'));
    await tester.pumpAndSettle();

    expect(find.textContaining('was not saved'), findsOneWidget);
    expect(find.text('Kopitiam SS2'), findsOneWidget);
    expect(
      rectOf(tester, find.textContaining('was not saved')).bottom,
      lessThan(fieldNamed(tester, 'Merchant').top),
      reason: 'the refusal is about the attempt, so it is above every field',
    );
  });
}
