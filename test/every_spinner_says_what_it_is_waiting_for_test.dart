import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money/data/receipt_store.dart';
import 'package:where_money/lock/lock_screen.dart';
import 'package:where_money_core/where_money_core.dart';

import 'fakes/fake_device_lock.dart';
import 'fakes/fake_model_gateway.dart';
import 'fakes/fake_sign_in_gateway.dart';
import 'fakes/in_memory_device_preferences.dart';
import 'fakes/in_memory_ledger_store.dart';
import 'scan/inbox_bloc_test.dart' show photograph;

/// What a screen reader is given while a screen is still loading. A bare
/// `CircularProgressIndicator` contributes no semantics node at all, so a
/// screen whose whole body is one is a screen TalkBack reaches and has nothing
/// to say about.
///
/// Five of them are the only thing in their body, and each is asserted here
/// through the whole app rather than by pumping a screen, because reaching a
/// loading state is the hard half: it means holding a seam open. The
/// `Completer`s these tests set are what hold it.
///
/// The sixth spinner — the Recap's, in a `Row` beside a sentence that already
/// says what it means — is deliberately wordless. It is the last test in this
/// file, and it fails if somebody labels it.
///
/// `pumpAndSettle` is unusable throughout: a spinner animates forever, so
/// nothing on any of these screens ever settles. [reach] pumps frames instead.
void main() {
  /// Away from today, deliberately. A clock pinned to the real date passes
  /// whether or not it is read.
  final pinned = DateTime(2026, 6, 15);

  late InMemoryLedgerStore store;
  late FakeDeviceLock lock;
  late FakeModelGateway model;
  late Uint8List receipt;

  /// The only seeded Expense with a photo, so tapping it is what puts the
  /// receipt reader on screen.
  final photographed = Expense(
    id: 'scan-7',
    merchant: 'Kedai Kopi Ping',
    date: DateTime(pinned.year, pinned.month, 10),
    currency: 'MYR',
    total: 14.60,
    category: 'dining',
    lineItems: const [],
    source: ExpenseSource.scanned,
    needsReview: false,
    receiptPath: receiptPathFor('scan-7'),
  );

  setUpAll(() => receipt = photograph(width: 400, height: 600));

  setUp(() {
    lock = FakeDeviceLock();
    model = FakeModelGateway();
    store = InMemoryLedgerStore([...seedLedger(around: pinned), photographed])
      ..keepReceipt(receiptPathFor('scan-7'), receipt);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  /// Pumps until [finder] is empty, or gives up.
  Future<void> goesAway(WidgetTester tester, Finder finder) async {
    for (var frame = 0; frame < 100; frame++) {
      if (finder.evaluate().isEmpty) return;
      await tester.pump(const Duration(milliseconds: 20));
    }
    fail('${finder.describeMatch(Plurality.one)} never went away');
  }

  Future<void> open(
    WidgetTester tester, {
    String language = defaultLanguage,
    bool lockIt = false,
  }) async {
    tester.view
      ..physicalSize = const Size(1000, 3000)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(
      WhereMoneyApp(
        lock: lock,
        preferences: InMemoryDevicePreferences(locksOnOpen: lockIt),
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        storesFor: (_) => store.stores,
        model: model,
        language: language,
        photograph: (_) async => null,
        // Pinned alongside the seeded Ledger, so a test that seeds a month is
        // about that month rather than about the day it is run.
        clock: () => pinned,
      ),
    );
    await tester.pump();
    // The Lock is opaque to a screen reader as well as to the eye: it blocks
    // the semantics of everything under it, so a test about any other screen
    // has to wait for it to have decided it is not wanted.
    if (!lockIt) await goesAway(tester, find.byType(LockScreen));
  }

  /// Pumps until [finder] hits, or gives up. Stands in for `pumpAndSettle` on
  /// a screen that never settles.
  Future<void> reach(WidgetTester tester, Finder finder) async {
    for (var frame = 0; frame < 100; frame++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 20));
    }
    fail('never reached ${finder.describeMatch(Plurality.one)}');
  }

  /// Opens a route from the Ledger's app bar. Two pumps rather than a settle,
  /// the second long enough to finish the transition.
  Future<void> openFromTheAppBar(WidgetTester tester, String tooltip) async {
    await reach(tester, find.byTooltip(tooltip));
    // The app bar exists a frame or two before it has finished arriving, and a
    // tap on a widget still moving misses it.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip(tooltip));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// Lets go of every held seam and pumps the answers through, so no test ends
  /// with a `Completer` nobody completed and work still in flight.
  Future<void> letGo(WidgetTester tester) async {
    for (final held in [
      store.holdLedger,
      store.holdInbox,
      store.holdReceipts,
      lock.holdsThePrompt,
    ]) {
      if (held != null && !held.isCompleted) held.complete();
    }
    model.release();
    await tester.pump(const Duration(milliseconds: 20));
  }

  testWidgets('the Ledger says it is opening while its month loads', (
    tester,
  ) async {
    store.holdLedger = Completer<void>();

    await open(tester);
    await reach(tester, find.text('Ledger'));

    expect(find.bySemanticsLabel('Opening your Ledger'), findsOneWidget);

    await letGo(tester);
  });

  testWidgets('the charts say the month is opening while the Ledger loads', (
    tester,
  ) async {
    store.holdLedger = Completer<void>();

    await open(tester);
    await openFromTheAppBar(tester, 'Charts');

    expect(find.bySemanticsLabel('Opening the month'), findsOneWidget);

    await letGo(tester);
  });

  testWidgets('the Inbox says it is opening while its Scans load', (
    tester,
  ) async {
    store.holdInbox = Completer<void>();

    await open(tester);
    await openFromTheAppBar(tester, 'Inbox');

    expect(find.bySemanticsLabel('Opening the Inbox'), findsOneWidget);

    await letGo(tester);
  });

  testWidgets('an Expense says its receipt is loading while it is read off '
      'disk', (tester) async {
    store.holdReceipts = Completer<void>();

    await open(tester);
    await reach(tester, find.text('Kedai Kopi Ping'));
    await tester.tap(find.text('Kedai Kopi Ping'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.bySemanticsLabel('Loading the receipt'), findsOneWidget);

    await letGo(tester);
  });

  testWidgets('the Lock says it is waiting while the phone asks', (
    tester,
  ) async {
    lock.holdsThePrompt = Completer<void>();

    await open(tester, lockIt: true);
    await reach(tester, find.text('where_money is locked'));

    // The Lock is a `Column` of Texts and this spinner, and the whole of it
    // merges into one utterance — so the label is asserted as the line it
    // becomes rather than on its own. Wrong-looking and correct: without the
    // label the utterance ends at "read it." and says nothing about waiting.
    expect(
      find.bySemanticsLabel(
        'where_money is locked\n'
        'Your spending is on this phone. Unlock it to read it.\n'
        'Waiting for the phone to ask',
      ),
      findsOneWidget,
    );

    await letGo(tester);
  });

  testWidgets('a spinner is read in the language the app is in', (
    tester,
  ) async {
    store.holdLedger = Completer<void>();

    await open(tester, language: 'zh');
    await reach(tester, find.text('账本'));

    expect(find.bySemanticsLabel('正在打开你的账本'), findsOneWidget);
    expect(find.bySemanticsLabel('Opening your Ledger'), findsNothing);

    await letGo(tester);
  });

  testWidgets('the Recap says it is being read once, not twice', (
    tester,
  ) async {
    // Held, so the Recap sits at pending rather than blinking through it.
    model.hold();

    await open(tester);
    await openFromTheAppBar(tester, 'Charts');

    // The spinner beside this sentence is wordless on purpose: it is 14px, it
    // sits in a `Row`, and the sentence already says what it means.
    //
    // The whole Recap card is one semantics node — the heading and the
    // sentence merge, which is why this asserts both of them and asserts them
    // exactly. That is what makes it a guard rather than a description: a
    // label on the spinner joins this same blob, and the announcement stops
    // being these two lines.
    expect(
      find.bySemanticsLabel('Where your money went\nReading the month.'),
      findsOneWidget,
    );

    await letGo(tester);
  });
}
