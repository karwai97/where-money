import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money_core/where_money_core.dart';

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

  Future<void> openLedger(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1200, 3000)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(
      WhereMoneyApp(
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        ledgerFor: (_) => store,
        model: model,
        photograph: (_) async => null,
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

  testWidgets('stepping back shows the month before it and nothing from this '
      'one', (tester) async {
    await openLedger(tester);
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();

    expect(find.text('AirAsia'), findsWidgets);
    expect(find.text('Ikea Damansara'), findsNothing);
  });

  testWidgets('the month you are in is as far forward as the Ledger goes', (
    tester,
  ) async {
    await openLedger(tester);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();

    expect(find.text('Ikea Damansara'), findsWidgets);
  });

  testWidgets('a month with nothing in it says so rather than showing a stale '
      'list', (tester) async {
    store = InMemoryLedgerStore();
    await openLedger(tester);

    expect(find.textContaining('Nothing'), findsOneWidget);
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

    expect(find.text(thisMonth), findsOneWidget);
    expect(find.text(lastMonth), findsOneWidget);
    expect(find.textContaining('MYR 1806.75'), findsWidgets);
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
    expect(find.text(thisMonth), findsOneWidget);
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
