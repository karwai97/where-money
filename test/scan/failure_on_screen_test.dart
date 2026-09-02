import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money/scan/model_gateway.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_ledger_store.dart';
import 'inbox_bloc_test.dart' show photograph;

/// What the user actually reads when a Scan did not work, and what they can do
/// about it without leaving the Inbox.
void main() {
  late InMemoryLedgerStore store;
  late FakeModelGateway model;

  setUp(() {
    store = InMemoryLedgerStore();
    model = FakeModelGateway();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      WhereMoneyApp(
        // The lock is not what these are about, so it is off.
        lock: FakeDeviceLock(),
        preferences: InMemoryDevicePreferences(locksOnOpen: false),
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        storesFor: (_) => store.stores,
        model: model,
        photograph: (_) async => photograph(width: 600, height: 800),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Resizing and the Model both answer off the test binding's fake clock, so
  /// this hands the real event loop time before pumping again.
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

  /// Takes the tree down, which closes the Inbox and cancels the timer a Scan
  /// waiting on a signal leaves running.
  Future<void> shut(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  Future<void> photographInto(WidgetTester tester, String line) async {
    await tester.tap(find.byTooltip('Photograph a receipt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.byTooltip('Inbox, 1 waiting'));
    await tester.tap(find.byTooltip('Inbox, 1 waiting'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text(line));
  }

  for (final (name, answer, line) in [
    (
      'a refusal',
      FakeModelGateway.refusal,
      'The Model would not read this photo',
    ),
    (
      'reasoning that ate the whole output budget',
      FakeModelGateway.silence,
      'The Model answered with nothing at all',
    ),
    (
      'an answer that was not the promised JSON',
      FakeModelGateway.gibberish,
      'The Model\'s answer was not readable',
    ),
    (
      'a dead network',
      const ModelOutOfReach('SocketException'),
      'No connection when this was read',
    ),
    (
      'the Model being down at the far end',
      const ModelUnavailable('model_unavailable'),
      'The Model was not available',
    ),
    (
      'a refused token',
      const TokenRefused('expired'),
      'Your sign-in was not accepted',
    ),
    (
      'an image the Worker would not take',
      const ImageNotAccepted('image_too_large'),
      'This photo could not be sent',
    ),
  ]) {
    testWidgets('$name says so in the Inbox', (tester) async {
      model.answer = answer;
      await open(tester);

      await photographInto(tester, line);

      expect(find.text(line), findsOneWidget);
      await shut(tester);
    });
  }

  testWidgets('the daily cap says so and says when it resets', (tester) async {
    model.answer = AllowanceSpent(resetsAt: DateTime(2026, 8, 26, 16, 30));
    await open(tester);

    await photographInto(tester, 'Today\'s Scans are used up');

    // The gap before the meridiem is a narrow no-break space, which is what
    // CLDR puts there and not something this app chose.
    expect(
      find.text('More Scans at Aug 26, 2026 4:30\u202fPM.'),
      findsOneWidget,
    );
    await shut(tester);
  });

  testWidgets('a cap with no reset time still does not say something went '
      'wrong', (tester) async {
    model.answer = const AllowanceSpent();
    await open(tester);

    await photographInto(tester, 'Today\'s Scans are used up');

    expect(find.text('More Scans tomorrow.'), findsOneWidget);
    await shut(tester);
  });

  testWidgets('a failed Scan can be read again without waiting', (
    tester,
  ) async {
    model.answer = FakeModelGateway.refusal;
    await open(tester);
    await photographInto(tester, 'The Model would not read this photo');

    model.answer = FakeModelGateway.reading(cleanExtraction);
    await tester.tap(find.text('Read again'));
    await waitFor(tester, find.text('Ready to Review'));

    expect(find.text('Ready to Review'), findsOneWidget);
    await shut(tester);
  });

  testWidgets('a Scan waiting to be Reviewed is not offered a second read', (
    tester,
  ) async {
    await open(tester);

    await photographInto(tester, 'Ready to Review');

    expect(find.text('Read again'), findsNothing);
    await shut(tester);
  });

  testWidgets('no failure loses the photo', (tester) async {
    model.answer = const TokenRefused('expired');
    await open(tester);

    await photographInto(tester, 'Your sign-in was not accepted');

    expect(await store.receiptFor(store.waiting.single.id), isNotNull);
    await shut(tester);
  });
}
