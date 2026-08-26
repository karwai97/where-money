import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money/scan/photographer.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_ledger_store.dart';
import 'inbox_bloc_test.dart' show photograph;

/// The camera is above the tested surface, so these hand the app bytes and
/// assert on what the user can then read on the screen.
void main() {
  late InMemoryLedgerStore store;
  late PhotoSource? opened;

  /// Held open, so these stay about capture: a Scan reaches the Inbox and the
  /// Model has not answered yet.
  late FakeModelGateway model;

  setUp(() {
    store = InMemoryLedgerStore();
    model = FakeModelGateway()..hold();
    opened = null;
  });

  Future<void> open(WidgetTester tester, {Uint8List? shutter}) async {
    await tester.pumpWidget(
      WhereMoneyApp(
        // The lock is not what these are about, so it is off.
        lock: FakeDeviceLock(),
        preferences: InMemoryDevicePreferences(locksOnOpen: false),
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        ledgerFor: (_) => store,
        model: model,
        photograph: (from) async {
          opened = from;
          return shutter;
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Resizing runs off the main isolate, which the test binding's fake clock
  /// knows nothing about, so this hands the real event loop time to deliver
  /// the answer before pumping again.
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

  Future<void> shoot(WidgetTester tester, String how) async {
    await tester.tap(find.byTooltip('Photograph a receipt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(how));
    await tester.pumpAndSettle();
  }

  testWidgets('a receipt photographed with the camera is in the Inbox', (
    tester,
  ) async {
    await open(tester, shutter: photograph(width: 600, height: 800));

    await shoot(tester, 'Take a photo');
    await waitFor(tester, find.byTooltip('Inbox, 1 waiting'));

    expect(opened, PhotoSource.camera);
  });

  testWidgets('a receipt chosen from the gallery is in the Inbox', (
    tester,
  ) async {
    await open(tester, shutter: photograph(width: 600, height: 800));

    await shoot(tester, 'Choose from gallery');
    await waitFor(tester, find.byTooltip('Inbox, 1 waiting'));

    expect(opened, PhotoSource.gallery);
  });

  testWidgets('backing out of the camera adds nothing', (tester) async {
    await open(tester);

    await shoot(tester, 'Take a photo');
    await tester.pumpAndSettle();

    expect(find.byTooltip('Inbox'), findsOneWidget);
  });

  testWidgets('the Inbox says what each Scan is waiting on', (tester) async {
    await open(tester, shutter: photograph(width: 600, height: 800));
    await shoot(tester, 'Take a photo');
    await waitFor(tester, find.byTooltip('Inbox, 1 waiting'));

    await tester.tap(find.byTooltip('Inbox, 1 waiting'));
    await tester.pumpAndSettle();

    expect(find.text('Being read'), findsOneWidget);
  });

  testWidgets('the count on the main screen keeps up with the Inbox', (
    tester,
  ) async {
    await open(tester, shutter: photograph(width: 600, height: 800));

    await shoot(tester, 'Take a photo');
    await waitFor(tester, find.byTooltip('Inbox, 1 waiting'));
    await shoot(tester, 'Take a photo');
    await waitFor(tester, find.byTooltip('Inbox, 2 waiting'));

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('abandoning a Scan takes it out of the Inbox and its image with '
      'it', (tester) async {
    await open(tester, shutter: photograph(width: 600, height: 800));
    await shoot(tester, 'Take a photo');
    await waitFor(tester, find.byTooltip('Inbox, 1 waiting'));

    await tester.tap(find.byTooltip('Inbox, 1 waiting'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Abandon this Scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abandon'));
    await tester.pumpAndSettle();

    expect(find.text('No receipts waiting.'), findsOneWidget);
    expect(await store.receiptFor('scan-1'), isNull);
  });

  testWidgets('keeping a Scan the user thought better of abandoning leaves it '
      'alone', (tester) async {
    await open(tester, shutter: photograph(width: 600, height: 800));
    await shoot(tester, 'Take a photo');
    await waitFor(tester, find.byTooltip('Inbox, 1 waiting'));

    await tester.tap(find.byTooltip('Inbox, 1 waiting'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Abandon this Scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();

    expect(find.text('Being read'), findsOneWidget);
    expect(await store.receiptFor('scan-1'), isNotNull);
  });

  testWidgets('an empty Inbox says so', (tester) async {
    await open(tester);

    await tester.tap(find.byTooltip('Inbox'));
    await tester.pumpAndSettle();

    expect(find.text('No receipts waiting.'), findsOneWidget);
  });
}
