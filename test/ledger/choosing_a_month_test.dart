import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money_core/where_money_core.dart';

import '../as_drawn.dart';
import '../fakes/fake_device_lock.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';

/// Naming a month rather than stepping to it. The trend is one month per tap
/// and six months wide; these are the two ways off it — the badge over the
/// total, which opens a year at a time, and the pill that goes back to the
/// month the app was opened in.
///
/// The clock is named in every test here rather than hung off `DateTime.now()`
/// as `month_on_screen_test.dart` mostly is: a sheet of twelve months has to
/// say which of them lie after today, and that is not assertable against a
/// calendar that moves.
void main() {
  final opened = DateTime(2026, 8, 23);

  /// A month as the sheet and the trend both draw it: upper case, which is
  /// typography rather than wording.
  String column(String month) => month.toUpperCase();

  late InMemoryLedgerStore store;
  final model = FakeModelGateway();

  setUp(() => store = InMemoryLedgerStore(seedLedger(around: opened)));

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Expense spent(DateTime on, {double total = 40.00}) => Expense(
    id: 'spent-${on.toIso8601String()}',
    merchant: 'Village Grocer',
    date: on,
    currency: 'MYR',
    total: total,
    category: 'groceries',
    lineItems: const [],
    source: ExpenseSource.manual,
    needsReview: false,
  );

  Future<void> openLedger(
    WidgetTester tester, {
    String? homeCurrency = 'MYR',
  }) async {
    tester.view
      ..physicalSize = const Size(1200, 3000)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(
      WhereMoneyApp(
        lock: FakeDeviceLock(),
        preferences: InMemoryDevicePreferences(locksOnOpen: false),
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        storesFor: (_) => store.stores,
        model: model,
        homeCurrency: homeCurrency,
        photograph: (_) async => null,
        clock: () => opened,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Scoped to the sheet, because the trend behind it draws the same twelve
  /// abbreviations and a bare `find.text('JUL')` would match either.
  Finder inSheet(Finder matching) =>
      find.descendant(of: find.byType(BottomSheet), matching: matching);

  Future<void> openTheSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Choose a month'));
    await tester.pumpAndSettle();
  }

  /// The tooltip lives inside the button rather than around it, so this reads
  /// up the tree rather than down.
  IconButton chevronFor(WidgetTester tester, String tooltip) =>
      tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(IconButton),
        ),
      );

  testWidgets('the month over the total opens a year of months', (
    tester,
  ) async {
    await openLedger(tester);
    await openTheSheet(tester);

    expect(inSheet(find.text('2026')), findsOneWidget);
    for (final month in const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ]) {
      expect(
        inSheet(find.text(column(month))),
        findsOneWidget,
        reason: '$month should be one tap away',
      );
    }
  });

  testWidgets('the sheet opens on the year of the month on screen, not on the '
      'year the app was opened in', (tester) async {
    store = InMemoryLedgerStore([
      ...seedLedger(around: opened),
      spent(DateTime(2024, 11, 4)),
    ]);
    await openLedger(tester);
    await openTheSheet(tester);

    await tester.tap(find.byTooltip('Previous year'));
    await tester.tap(find.byTooltip('Previous year'));
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.text(column('Nov'))));
    await tester.pumpAndSettle();

    await openTheSheet(tester);
    expect(inSheet(find.text('2024')), findsOneWidget);
  });

  testWidgets('tapping a month moves the Ledger onto it and closes the sheet', (
    tester,
  ) async {
    await openLedger(tester);
    await openTheSheet(tester);
    await tester.tap(inSheet(find.text(column('Jul'))));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('AirAsia'), findsWidgets);
    expect(find.text('Ikea Damansara'), findsNothing);
    expect(find.text(column('Jul 2026')), findsOneWidget);
  });

  testWidgets('a month nobody spent anything in is still somewhere to go', (
    tester,
  ) async {
    await openLedger(tester);
    await openTheSheet(tester);

    expect(
      inSheet(find.text('MYR 1806.75')),
      findsNothing,
      reason: 'the code is in the header above; a cell prints the figure',
    );

    await tester.tap(inSheet(find.text(column('Mar'))));
    await tester.pumpAndSettle();

    expect(find.text('Nothing in March 2026.'), findsOneWidget);
    expect(
      find.text(column('Apr')),
      findsWidgets,
      reason: 'and the trend is there to move on from',
    );
  });

  testWidgets('the month already on screen closes the sheet and moves '
      'nowhere', (tester) async {
    await openLedger(tester);
    await openTheSheet(tester);
    await tester.tap(inSheet(find.text(column('Aug'))));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Ikea Damansara'), findsWidgets);
  });

  testWidgets('a month after the one the app was opened in is dimmed, '
      'untotalled and does not respond', (tester) async {
    store = InMemoryLedgerStore([
      ...seedLedger(around: opened),
      spent(DateTime(2026, 12, 4), total: 512.34),
    ]);
    final semantics = tester.ensureSemantics();
    await openLedger(tester);
    await openTheSheet(tester);

    expect(
      inSheet(find.text('512.34')),
      findsNothing,
      reason: 'there is nothing to see after today, so nothing is totalled',
    );
    expect(
      tester.getSemantics(inSheet(find.text(column('Dec')))),
      isSemantics(isEnabled: false, isFocusable: false),
    );

    await tester.tap(inSheet(find.text(column('Dec'))));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Ikea Damansara'), findsWidgets);

    semantics.dispose();
  });

  testWidgets('the years stop at the oldest Expense and at the month the app '
      'was opened in', (tester) async {
    store = InMemoryLedgerStore([
      ...seedLedger(around: opened),
      spent(DateTime(2024, 11, 4)),
    ]);
    await openLedger(tester);
    await openTheSheet(tester);

    IconButton chevron(String tooltip) => chevronFor(tester, tooltip);

    expect(
      chevron('Next year').onPressed,
      isNull,
      reason: 'nothing to see past the month the app was opened in',
    );
    expect(chevron('Previous year').onPressed, isNotNull);

    await tester.tap(find.byTooltip('Previous year'));
    await tester.pumpAndSettle();

    expect(inSheet(find.text('2025')), findsOneWidget);
    expect(
      chevron('Previous year').onPressed,
      isNotNull,
      reason: '2025 has no Expenses in it and is still a year to pass through',
    );
    expect(chevron('Next year').onPressed, isNotNull);

    await tester.tap(find.byTooltip('Previous year'));
    await tester.pumpAndSettle();

    expect(inSheet(find.text('2024')), findsOneWidget);
    expect(chevron('Previous year').onPressed, isNull);
  });

  // The trend's window reaches back past the oldest Expense, so a reader can
  // be standing in a year nothing was ever spent in. The sheet opened from
  // that month has to be about that month.
  testWidgets('the sheet opens on a year older than the oldest Expense when '
      'that is where the reader is', (tester) async {
    store = InMemoryLedgerStore([spent(DateTime(2026, 1, 6))]);
    await openLedger(tester);

    // The sheet as far back as it goes, and then one column down the trend,
    // which windows itself past the oldest Expense.
    await openTheSheet(tester);
    await tester.tap(inSheet(find.text(column('Jan'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text(column('Dec')));
    await tester.pumpAndSettle();
    expect(find.text(column('Dec 2025')), findsOneWidget);

    await openTheSheet(tester);

    expect(inSheet(find.text('2025')), findsOneWidget);
    expect(
      chevronFor(tester, 'Next year').onPressed,
      isNotNull,
      reason: '2026 is still ahead of it',
    );
    expect(
      chevronFor(tester, 'Previous year').onPressed,
      isNull,
      reason: 'and nothing before it',
    );
  });

  testWidgets('a disabled chevron is still drawn, so the year does not shift', (
    tester,
  ) async {
    await openLedger(tester);
    await openTheSheet(tester);

    expect(find.byTooltip('Previous year'), findsOneWidget);
    expect(find.byTooltip('Next year'), findsOneWidget);
  });

  // `useSafeArea` is `SafeArea(bottom: false)` for a modal sheet, so the
  // bottom row of cells is only off the gesture bar if the content holds
  // itself off it.
  testWidgets('the bottom row of cells clears the gesture bar', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(bottom: 34)
      ..viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(() {
      tester.view
        ..resetPadding()
        ..resetViewPadding();
    });
    await tester.pumpWidget(
      WhereMoneyApp(
        lock: FakeDeviceLock(),
        preferences: InMemoryDevicePreferences(locksOnOpen: false),
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        storesFor: (_) => store.stores,
        model: model,
        homeCurrency: 'MYR',
        photograph: (_) async => null,
        clock: () => opened,
      ),
    );
    await tester.pumpAndSettle();
    await openTheSheet(tester);

    expect(
      tester.getRect(inSheet(find.text(column('Dec')))).bottom,
      lessThanOrEqualTo(844 - 34 - 28),
      reason: 'the design asks for 28 above the inset, not 28 into it',
    );
  });

  testWidgets('a focused month is ringed in the accent', (tester) async {
    final semantics = tester.ensureSemantics();
    await openLedger(tester);
    await openTheSheet(tester);

    Border? ringAround(String month) {
      final box = find
          .ancestor(
            of: inSheet(find.text(column(month))),
            matching: find.byType(Container),
          )
          .evaluate()
          .map((element) => element.widget as Container)
          .firstWhere((container) => container.foregroundDecoration != null);
      return (box.foregroundDecoration! as BoxDecoration).border as Border?;
    }

    expect(ringAround('Jul')?.top.color, const Color(0x00000000));

    tester.semantics.performAction(
      find.semantics.byLabel(RegExp('^July')),
      SemanticsAction.focus,
    );
    await tester.pumpAndSettle();

    final accent = Theme.of(
      tester.element(inSheet(find.text(column('Jul'))).first),
    ).colorScheme.primary;
    expect(ringAround('Jul')?.top.color, accent);
    expect(ringAround('Mar')?.top.color, const Color(0x00000000));

    semantics.dispose();
  });

  testWidgets('a cell says its month and what it cost, in one sentence', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openLedger(tester);
    await openTheSheet(tester);

    expect(
      inSheet(find.bySemanticsLabel('July 2026, MYR 1265.80')),
      findsOneWidget,
      reason: 'the same words the trend behind it gives its own columns',
    );
    expect(
      inSheet(find.bySemanticsLabel('March 2026')),
      findsOneWidget,
      reason: 'a month with nothing in it has no amount to read out',
    );

    semantics.dispose();
  });

  testWidgets('Escape closes the sheet without changing month', (tester) async {
    await openLedger(tester);
    await openTheSheet(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Ikea Damansara'), findsWidgets);
  });

  testWidgets('the way back to today is not offered on today', (tester) async {
    await openLedger(tester);

    expect(markSaying('Back to Aug 2026'), findsNothing);
  });

  testWidgets('the way back to today appears once the reader has left it', (
    tester,
  ) async {
    await openLedger(tester);
    await openTheSheet(tester);
    await tester.tap(inSheet(find.text(column('Mar'))));
    await tester.pumpAndSettle();

    expect(markSaying('Back to Aug 2026'), findsOneWidget);

    await tester.tap(markSaying('Back to Aug 2026'));
    await tester.pumpAndSettle();

    expect(find.text('Ikea Damansara'), findsWidgets);
    expect(markSaying('Back to Aug 2026'), findsNothing);
  });

  testWidgets('the way back says the month in full to a screen reader', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openLedger(tester);
    await openTheSheet(tester);
    await tester.tap(inSheet(find.text(column('Mar'))));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Back to August 2026'), findsOneWidget);

    semantics.dispose();
  });

  // No header on a Ledger with no Home Currency: nothing to total, no month
  // named, and so neither of these two ways of naming one.
  testWidgets('a Ledger with no Home Currency has no badge and no pill', (
    tester,
  ) async {
    // Empty, because a seeded Ledger teaches the app its Home Currency from
    // the first Expense and is a LedgerReady a frame later.
    store = InMemoryLedgerStore();
    await openLedger(tester, homeCurrency: null);

    expect(find.byTooltip('Choose a month'), findsNothing);
    expect(markSaying('Back to Aug 2026'), findsNothing);
  });

  // The last row and the notice under it used to sit behind the camera
  // button. The pill lands beside it, so the list has to clear both.
  testWidgets('the foot of the list scrolls clear of the pill and the '
      'buttons', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(
      WhereMoneyApp(
        lock: FakeDeviceLock(),
        preferences: InMemoryDevicePreferences(locksOnOpen: false),
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        storesFor: (_) => store.stores,
        model: model,
        homeCurrency: 'MYR',
        photograph: (_) async => null,
        clock: () => opened,
      ),
    );
    await tester.pumpAndSettle();

    final notice = find.textContaining('not in these totals');
    await tester.scrollUntilVisible(notice, 200);
    await tester.pumpAndSettle();

    expect(
      tester.getRect(notice).bottom,
      lessThanOrEqualTo(844 - 88),
      reason: 'the notice can be read rather than sitting under the buttons',
    );
  });
}
