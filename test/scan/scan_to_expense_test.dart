import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_ledger_store.dart';
import 'inbox_bloc_test.dart' show photograph;

/// The whole tracer bullet, from the shutter to the Ledger, as the user sees
/// it: photograph a receipt, put the phone down, come back to find it read and
/// waiting.
void main() {
  late InMemoryLedgerStore store;
  late FakeModelGateway model;

  setUp(() {
    store = InMemoryLedgerStore();
    model = FakeModelGateway();
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1000, 4000)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(
      WhereMoneyApp(
        // The lock is not what these are about, so it is off.
        lock: FakeDeviceLock(),
        preferences: InMemoryDevicePreferences(locksOnOpen: false),
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        ledgerFor: (_) => store,
        model: model,
        photograph: (_) async => photograph(width: 600, height: 800),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The resize runs on another isolate and the Model answers off the event
  /// loop, neither of which the test binding's clock knows about.
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('never found ${finder.describeMatch(Plurality.one)}');
  }

  Future<void> shoot(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Photograph a receipt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();
  }

  Future<void> openTheInbox(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Inbox, 1 waiting'));
    await tester.pumpAndSettle();
  }

  Future<void> photographAndWait(WidgetTester tester) async {
    await open(tester);
    await shoot(tester);
    await waitFor(tester, find.byTooltip('Inbox, 1 waiting'));
    await openTheInbox(tester);
    await waitFor(tester, find.text('Ready to Review'));
  }

  testWidgets('a photographed receipt is read while the user is elsewhere', (
    tester,
  ) async {
    await open(tester);
    await shoot(tester);
    await waitFor(tester, find.byTooltip('Inbox, 1 waiting'));

    // Nothing opened itself: the Ledger is still what is on screen.
    expect(find.text('Ledger'), findsOneWidget);
    expect(find.text('Review this receipt'), findsNothing);

    await openTheInbox(tester);
    await waitFor(tester, find.text('Ready to Review'));
  });

  testWidgets('Review opens on what the Model read, beside the receipt', (
    tester,
  ) async {
    await photographAndWait(tester);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('Review this receipt'), findsOneWidget);
    expect(find.text('Village Grocer Bangsar'), findsOneWidget);
    expect(find.byTooltip('Zoom into the receipt'), findsOneWidget);
  });

  testWidgets('the receipt can be zoomed enough to read faint print', (
    tester,
  ) async {
    await photographAndWait(tester);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Zoom into the receipt'));
    await tester.pumpAndSettle();

    expect(find.text('The receipt'), findsOneWidget);
    expect(find.byTooltip('Back to the fields'), findsOneWidget);
  });

  testWidgets('the Model says why it chose the Category', (tester) async {
    await photographAndWait(tester);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Fresh food and household staples'),
      findsOneWidget,
    );
  });

  testWidgets('a clean Extraction is not an Expense until it is tapped', (
    tester,
  ) async {
    await photographAndWait(tester);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Everything on this receipt adds up'),
      findsOneWidget,
    );
    expect(store.contents, isEmpty);

    await tester.tap(find.text('Add to Ledger'));
    await tester.pumpAndSettle();

    expect(store.contents, hasLength(1));
    expect(find.text('No receipts waiting.'), findsOneWidget);
  });

  testWidgets('a flagged Extraction pins the Findings above the fields', (
    tester,
  ) async {
    model.answer = FakeModelGateway.reading(flawedExtraction);
    await photographAndWait(tester);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('No date'), findsOneWidget);
    expect(find.text('Line items do not match subtotal'), findsOneWidget);
    expect(
      find.textContaining('Everything on this receipt adds up'),
      findsNothing,
    );

    // Pinned, not merely present: scrolling down to correct what a Finding
    // names must not scroll the Finding away.
    await tester.drag(find.text('Line Items'), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('No date'), findsOneWidget);
  });

  testWidgets('a correction made during Review reaches the Ledger', (
    tester,
  ) async {
    await photographAndWait(tester);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Merchant').first,
      'Village Grocer KL',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Ledger'));
    await tester.pumpAndSettle();

    expect(store.contents.single.merchant, 'Village Grocer KL');
    expect(store.contents.single.correctedFields, ['merchant']);
  });

  testWidgets(
    'a photo the Model says is not a receipt is offered for discard',
    (tester) async {
      model.answer = FakeModelGateway.reading(notAReceiptExtraction);
      await open(tester);
      await shoot(tester);
      await waitFor(tester, find.byTooltip('Inbox, 1 waiting'));
      await openTheInbox(tester);
      await waitFor(tester, find.text('This does not look like a receipt'));

      expect(find.text('Review'), findsNothing);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Discard'));
      await tester.pumpAndSettle();

      expect(find.text('No receipts waiting.'), findsOneWidget);
    },
  );
}
