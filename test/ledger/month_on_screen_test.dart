import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_ledger_store.dart';

/// Assertions are on text the user can read. The seeded Ledger hangs off the
/// current month, so these hold whatever day they are run on; the months are
/// spelled out here rather than asked of the code under test.
void main() {
  const short = [
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
  ];
  final now = DateTime.now();
  final thisMonth = short[now.month - 1];
  final lastMonth = short[DateTime(now.year, now.month - 1).month - 1];
  final nextMonth = short[DateTime(now.year, now.month + 1).month - 1];

  /// A month as the trend draws it. The columns are upper case, which is
  /// typography rather than wording — elsewhere the same month is read from a
  /// sentence, so the two spellings are kept apart here rather than merged.
  String column(String month) => month.toUpperCase();

  late InMemoryLedgerStore store;
  final model = FakeModelGateway();

  setUp(() => store = InMemoryLedgerStore(seedLedger()));

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearPlatformBrightnessTestValue();
  });

  Future<void> openLedger(WidgetTester tester, {DateTime? on}) async {
    tester.view
      ..physicalSize = const Size(1200, 3000)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(
      WhereMoneyApp(
        // The lock is not what these are about, so it is off.
        lock: FakeDeviceLock(),
        preferences: InMemoryDevicePreferences(locksOnOpen: false),
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        storesFor: (_) => store.stores,
        model: model,
        homeCurrency: 'MYR',
        photograph: (_) async => null,
        clock: on == null ? DateTime.now : () => on,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openCharts(WidgetTester tester) async {
    await openLedger(tester);
    await tester.tap(find.byTooltip('Charts'));
    await tester.pumpAndSettle();
  }

  testWidgets('the Ledger shows the month it is filtered to', (tester) async {
    await openLedger(tester);

    expect(find.textContaining(thisMonth), findsWidgets);
    expect(find.text('Ikea Damansara'), findsWidgets);
    expect(find.text('AirAsia'), findsNothing);
  });

  // The one test here that does not hang off today. Every other test in this
  // file works around an unreachable clock by seeding the Ledger relative to
  // `DateTime.now()`; this one names both ends, so that removing the seam
  // fails a test rather than quietly making six others rot with the calendar.
  testWidgets('the Ledger opens on the month its clock names, not the month '
      'the machine is in', (tester) async {
    store = InMemoryLedgerStore(seedLedger(around: DateTime(2026, 8, 23)));

    await openLedger(tester, on: DateTime(2026, 8, 23));

    expect(find.textContaining('Aug'), findsWidgets);
    expect(find.text('Ikea Damansara'), findsWidgets);
    // Seeded into July, so it is there to be found and should not be: the
    // clock picked a month, and the month is filtering.
    expect(find.text('AirAsia'), findsNothing);
  });

  // The trend in the Ledger's header is the way through the months: the
  // chevrons direction C replaced it with are gone, and a column knows which
  // month it drew.
  testWidgets('tapping the month before this one moves the list onto it', (
    tester,
  ) async {
    await openLedger(tester);
    await tester.tap(find.text(column(lastMonth)));
    await tester.pumpAndSettle();

    expect(find.text('AirAsia'), findsWidgets);
    expect(find.text('Ikea Damansara'), findsNothing);
  });

  testWidgets('the month you are in is as far forward as the Ledger goes', (
    tester,
  ) async {
    await openLedger(tester);

    // Nothing to tap that leads past the month the app opened in: the trend
    // ends there, so there is no forward step to shut off.
    expect(find.text(column(thisMonth)), findsWidgets);
    expect(find.text(column(nextMonth)), findsNothing);
    expect(find.text('Ikea Damansara'), findsWidgets);
  });

  // The two lines of a row are not equals. Material paints both in the one
  // ink, which left a date and a category reading as loudly as the merchant
  // they belong to.
  testWidgets('a row says the merchant louder than what it was for', (
    tester,
  ) async {
    await openLedger(tester);

    final merchant = tester.widget<Text>(find.text('Ikea Damansara'));
    final under = tester.widget<Text>(find.textContaining('· Home'));

    expect(
      merchant.style?.fontWeight,
      FontWeight.w500,
      reason: 'the merchant carries the weight',
    );
    expect(
      under.style?.color,
      isNot(merchant.style?.color),
      reason: 'and the line under it is a tier down in ink',
    );
  });

  // A bar of no height marks nothing, and the months worth stepping back to
  // are often the empty ones.
  testWidgets('the month on screen is named in the accent even when it drew '
      'no bar', (tester) async {
    store = InMemoryLedgerStore();
    await openLedger(tester);

    final label = tester.widget<Text>(find.text(column(thisMonth)));

    expect(
      label.style?.color,
      isNotNull,
      reason: 'the showing month carries a colour of its own',
    );
    expect(
      label.style?.color,
      isNot(tester.widget<Text>(find.text(column(lastMonth))).style?.color),
    );
  });

  // The complaint this was built for: the trend used to end at the month on
  // screen, so walking back put that month against the right-hand edge and
  // left nothing on screen leading forward. Restarting the app was the only
  // way back to today.
  testWidgets('walking back down the trend leaves a way forward again', (
    tester,
  ) async {
    store = InMemoryLedgerStore(seedLedger(around: DateTime(2026, 8, 23)));
    await openLedger(tester, on: DateTime(2026, 8, 23));

    // The oldest column the trend opens on, six months back from August.
    await tester.tap(find.text(column('Mar')));
    await tester.pumpAndSettle();

    expect(
      find.text(column('Apr')),
      findsWidgets,
      reason: 'a month later than March',
    );

    await tester.tap(find.text(column('Apr')));
    await tester.pumpAndSettle();

    expect(find.text('AirAsia'), findsNothing, reason: 'off March, not on it');
    expect(
      find.text(column('May')),
      findsWidgets,
      reason: 'and still going forward',
    );
  });

  testWidgets('a month with nothing in it says so rather than showing a stale '
      'list', (tester) async {
    store = InMemoryLedgerStore();
    await openLedger(tester);

    expect(find.textContaining('Nothing here yet'), findsOneWidget);
  });

  // Found by running the app, not by reading it. The trend is the only way
  // through the months now, so hiding it on a month with no spending — which
  // the chart detail is right to do — left the reader on a dead screen with
  // nothing to tap.
  testWidgets('a month with nothing in it still has a way out of it', (
    tester,
  ) async {
    store = InMemoryLedgerStore();
    await openLedger(tester);

    expect(
      find.text(column(lastMonth)),
      findsWidgets,
      reason:
          'an empty month draws no bar, but its column is still the way '
          'back',
    );

    await tester.tap(find.text(column(lastMonth)));
    await tester.pumpAndSettle();

    // The badge over the total, which names the month it landed on. Upper
    // case like the column it was tapped: on an empty Ledger there is no
    // sentence naming the month to find instead.
    expect(find.textContaining(column(lastMonth)), findsWidgets);
  });

  // Direction C folds the total into the Ledger's own header. Before that the
  // screen a user opens on could not say what the month came to at all — the
  // figure was a tap away on the charts.
  testWidgets('the Ledger says what the month came to, not only what it went '
      'on', (tester) async {
    await openLedger(tester);

    expect(find.text('MYR 1806.75'), findsOneWidget);
    expect(find.textContaining('than'), findsWidgets);
  });

  testWidgets('the Ledger owns up to what its own total leaves out', (
    tester,
  ) async {
    await openLedger(tester);

    // The seeded month spends USD, which is not the Home Currency and so is
    // not in the figure above the list (ADR-0006). The charts said so; the
    // screen holding the total now has to say it too.
    expect(find.textContaining('not in these totals'), findsOneWidget);
  });

  testWidgets('the charts break the month down by category', (tester) async {
    await openCharts(tester);

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('MYR 423.10'), findsOneWidget);
    expect(find.text('Fuel'), findsOneWidget);
    expect(find.text('MYR 235.00'), findsOneWidget);
  });

  testWidgets('the charts compare this month against the ones before it', (
    tester,
  ) async {
    await openCharts(tester);

    expect(find.text(column(thisMonth)), findsOneWidget);
    expect(find.text(column(lastMonth)), findsOneWidget);
    expect(find.textContaining('MYR 1806.75'), findsWidgets);
  });

  testWidgets('tapping a month in the trend moves the whole screen onto it', (
    tester,
  ) async {
    await openCharts(tester);
    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.text(column(lastMonth)));
    await tester.pumpAndSettle();

    // The title, the breakdown and the trend all read from one Rollup, so a
    // breakdown that is now last month's is the whole screen having moved.
    expect(find.widgetWithText(AppBar, thisMonth), findsNothing);
    expect(find.text('Travel'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('the Ledger behind the charts is on the month the trend was '
      'left on', (tester) async {
    await openCharts(tester);

    await tester.tap(find.text(column(lastMonth)));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('AirAsia'), findsWidgets);
    expect(find.text('Ikea Damansara'), findsNothing);
  });

  // The trend now reaches past the month on screen, so the charts cannot take
  // the end of it for the month they are about — the title would name one
  // month and the figure above the bars another.
  testWidgets('the charts are about the month on screen, not the end of the '
      'trend', (tester) async {
    store = InMemoryLedgerStore(seedLedger(around: DateTime(2026, 8, 23)));
    await openLedger(tester, on: DateTime(2026, 8, 23));

    await tester.tap(find.text(column('Mar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Charts'));
    await tester.pumpAndSettle();

    expect(find.text('March 2026'), findsOneWidget);
    expect(find.textContaining('August'), findsNothing);
  });

  testWidgets('a month in the trend is a button, not just a drawing', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openCharts(tester);

    expect(
      tester.getSemantics(find.text(column(lastMonth))),
      containsSemantics(hasTapAction: true, isButton: true),
    );
    semantics.dispose();
  });

  testWidgets('spending in another currency is named as left out rather than '
      'dropped', (tester) async {
    await openCharts(tester);

    expect(find.textContaining('USD'), findsWidgets);
    expect(find.textContaining('not in these totals'), findsWidgets);
  });

  testWidgets('the months in the trend say what they left out too, not only '
      'the month on screen', (tester) async {
    await openCharts(tester);

    // The seeded Ledger spends USD this month and SGD last month, and only
    // the trend covers both.
    expect(
      find.textContaining('SGD, USD'),
      findsOneWidget,
      reason: 'the trend should account for every month it draws',
    );
    expect(find.textContaining('2 Expenses'), findsOneWidget);
  });

  testWidgets('a month with no Expenses is empty rather than a chart of '
      'zeroes', (tester) async {
    store = InMemoryLedgerStore();
    await openCharts(tester);

    expect(find.textContaining('Nothing spent'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
    expect(find.textContaining('not in these totals'), findsNothing);
  });

  // Contrast itself is not measured here — this only holds the charts to
  // rendering every value as text under a dark scheme. Whether they are
  // legible needs eyes on a phone.
  testWidgets('every value is still on screen under a dark theme', (
    tester,
  ) async {
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .platformBrightnessTestValue =
        Brightness.dark;
    await openCharts(tester);

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('MYR 423.10'), findsOneWidget);
    expect(find.text(column(thisMonth)), findsOneWidget);
  });

  // Geometry rather than text, unlike everything else here, because the defect
  // this pins is geometric: the fill drew at zero height and every value on the
  // screen still read correctly. Found by looking at a phone, not a test.
  testWidgets('a category bar is drawn, not just the track it sits in', (
    tester,
  ) async {
    await openCharts(tester);

    final fill = find.byKey(const ValueKey('category bar: Groceries'));
    expect(fill, findsOneWidget);
    expect(
      tester.getSize(fill).height,
      greaterThan(0),
      reason: 'a bar nobody can see is not a chart',
    );
    expect(
      tester.getSize(fill).width,
      greaterThan(0),
      reason: 'the largest category fills its track',
    );
  });
}
