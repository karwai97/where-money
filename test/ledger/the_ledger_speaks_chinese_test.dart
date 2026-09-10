import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';

/// The screens a user spends the most time on, read in Chinese: the Ledger, an
/// Expense, both charts and the Rollup. The seeded Ledger hangs off the month
/// this is run in, so the months are worked out here rather than asked of the
/// code under test.
///
/// Three things deliberately do not move. Money keeps its explicit currency
/// code, because the Home Currency rule depends on a foreign-currency Expense
/// looking foreign (ADR-0006). A merchant's name and a line item's description
/// are printed as the paper had them. And the Recap itself is the Model's prose
/// — the_recap_speaks_chinese_test.dart is what says it is asked for in the
/// right language.
void main() {
  final now = DateTime.now();
  final thisMonth = '${now.year}年${now.month}月';
  final lastMonth = DateTime(now.year, now.month - 1);
  final previousMonth = '${lastMonth.year}年${lastMonth.month}月';

  late InMemoryLedgerStore store;
  final model = FakeModelGateway();

  setUp(() => store = InMemoryLedgerStore(seedLedger()));

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

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
        language: 'zh',
        photograph: (_) async => null,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openCharts(
    WidgetTester tester, {
    String? homeCurrency = 'MYR',
  }) async {
    await openLedger(tester, homeCurrency: homeCurrency);
    await tester.tap(find.byTooltip('图表'));
    await tester.pumpAndSettle();
  }

  Future<void> openExpense(WidgetTester tester, String merchant) async {
    await openLedger(tester);
    await tester.tap(find.text(merchant).first);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the Ledger names itself and the month it is showing in Chinese',
    (tester) async {
      await openLedger(tester);

      expect(find.text('账本'), findsOneWidget);
      expect(find.text(thisMonth), findsOneWidget);
      // The heads over the list, which the header put there. Upper-casing
      // them is a no-op in Chinese, so they read as the message file wrote
      // them.
      expect(find.text('商家'), findsOneWidget);
      expect(find.text('金额'), findsOneWidget);
      expect(find.byTooltip('手动添加一笔支出'), findsOneWidget);
    },
  );

  testWidgets('an Expense in the list reads its date and Category in Chinese', (
    tester,
  ) async {
    await openLedger(tester);

    expect(find.text('Ikea Damansara'), findsOneWidget);
    expect(
      find.text('${now.year}年${now.month}月23日 · 居家'),
      findsOneWidget,
      reason: 'the date reads the way Chinese reads dates',
    );
  });

  testWidgets('nothing on the Ledger is still in English', (tester) async {
    await openLedger(tester);

    for (final english in const [
      'Ledger',
      'Home',
      'Groceries',
      'Transport',
      'Fuel',
    ]) {
      expect(
        find.text(english),
        findsNothing,
        reason: '"$english" did not move',
      );
    }
    for (final tooltip in const [
      'Ledger',
      'Charts',
      'Settings',
      'Inbox',
      'Previous month',
      'Next month',
      'Choose a month',
      'Previous year',
      'Next year',
      'Add an Expense by hand',
      'Photograph a receipt',
    ]) {
      expect(
        find.byTooltip(tooltip),
        findsNothing,
        reason: '"$tooltip" did not move',
      );
    }
  });

  // The two tests here that name their own clock. Everything else in this
  // file works around an unreachable one by seeding relative to today; a
  // sheet of twelve months has to say which of them lie ahead, and "the
  // month before this one" is in the previous year every January.
  group('choosing a month', () {
    final august = DateTime(2026, 8, 23);

    Future<void> openOnAugust(WidgetTester tester) async {
      store = InMemoryLedgerStore(seedLedger(around: august));
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
          homeCurrency: 'MYR',
          language: 'zh',
          photograph: (_) async => null,
          clock: () => august,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('选一个月'));
      await tester.pumpAndSettle();
    }

    Finder inSheet(Finder matching) =>
        find.descendant(of: find.byType(BottomSheet), matching: matching);

    testWidgets('the sheet is a Chinese year of Chinese months', (
      tester,
    ) async {
      await openOnAugust(tester);

      expect(
        inSheet(find.text('2026年')),
        findsOneWidget,
        reason: 'a year is written with its own character, not as four digits',
      );
      expect(
        inSheet(find.text('8月')),
        findsOneWidget,
        reason: 'and a month is not the first three characters of one',
      );
      expect(find.byTooltip('上一年'), findsOneWidget);
      expect(find.byTooltip('下一年'), findsOneWidget);
      expect(find.textContaining('Choose'), findsNothing);
    });

    testWidgets('the way back to the month it opened in is in Chinese and is '
        'not shouted', (tester) async {
      await openOnAugust(tester);
      await tester.tap(inSheet(find.text('3月')));
      await tester.pumpAndSettle();

      // `cased` is a no-op in Chinese, so the pill reads as the message file
      // wrote it — beside a Latin month it would have been shouted.
      expect(find.text('回到2026年8月'), findsOneWidget);
      expect(find.textContaining('Back to'), findsNothing);
    });
  });

  testWidgets('an empty month says so in Chinese and names the month', (
    tester,
  ) async {
    store = InMemoryLedgerStore(seedLedger(around: DateTime(now.year - 2, 6)));
    await openLedger(tester);

    expect(find.text('$thisMonth没有记录。'), findsOneWidget);
  });

  testWidgets('a Ledger with nothing in it at all says so in Chinese', (
    tester,
  ) async {
    store = InMemoryLedgerStore();
    await openLedger(tester);

    expect(find.textContaining('这里还什么都没有'), findsOneWidget);
    expect(find.textContaining('Nothing'), findsNothing);
  });

  testWidgets('an opened Expense is in Chinese and keeps the words off the '
      'receipt', (tester) async {
    await openExpense(tester, 'Ikea Damansara');

    expect(find.text('Ikea Damansara'), findsOneWidget);
    expect(find.text('MYR 289.90'), findsOneWidget);
    expect(find.text('${now.year}年${now.month}月23日 · 居家'), findsOneWidget);
    expect(find.text('从拍下的收据读出来的'), findsOneWidget);
    expect(find.byTooltip('修正这笔支出'), findsOneWidget);
    expect(find.byTooltip('删除这笔支出'), findsOneWidget);

    for (final english in const [
      'Read from a photographed receipt',
      'Typed in by hand',
      'No Line Items — just the total.',
    ]) {
      expect(
        find.text(english),
        findsNothing,
        reason: '"$english" did not move',
      );
    }
  });

  testWidgets('an Expense with no Line Items says so in Chinese', (
    tester,
  ) async {
    await openExpense(tester, 'Ikea Damansara');

    expect(find.text('没有明细——只有总额。'), findsOneWidget);
  });

  testWidgets('a Line Item names its Category and its count in Chinese, and '
      'its description as printed', (tester) async {
    store = InMemoryLedgerStore([
      Expense(
        id: 'with-items',
        merchant: 'Village Grocer',
        date: DateTime(now.year, now.month, 4),
        currency: 'MYR',
        total: 24.00,
        category: 'groceries',
        source: ExpenseSource.scanned,
        needsReview: false,
        lineItems: const [
          LineItem(
            description: 'NESCAFE GOLD 200G',
            amount: 24.00,
            category: 'groceries',
            quantity: 2,
            unitPrice: 12.00,
          ),
        ],
      ),
    ]);
    await openExpense(tester, 'Village Grocer');

    expect(find.text('明细'), findsOneWidget);
    expect(
      find.text('NESCAFE GOLD 200G'),
      findsOneWidget,
      reason: 'a line item is what the paper said, in either language',
    );
    expect(
      find.text('食品杂货 · 2 × 12.00'),
      findsOneWidget,
      reason: 'two of something is 2, not 2.0',
    );
    expect(find.text('Line Items'), findsNothing);
  });

  testWidgets('a foreign-currency Expense says why it is left out, in Chinese, '
      'and keeps its own code', (tester) async {
    await openExpense(tester, 'Steam');

    expect(find.text('MYR 24.99'), findsNothing);
    expect(
      find.text('USD 24.99'),
      findsOneWidget,
      reason: 'money is deliberately not locale-formatted',
    );
    expect(find.text('以 USD 支付，所以不计入你的月度总额。'), findsOneWidget);
    expect(find.text('手动输入的'), findsOneWidget);
  });

  testWidgets('deleting asks in Chinese and names the amount as it stands', (
    tester,
  ) async {
    await openExpense(tester, 'Ikea Damansara');
    await tester.tap(find.byTooltip('删除这笔支出'));
    await tester.pumpAndSettle();

    expect(find.text('删除这笔支出？'), findsOneWidget);
    expect(
      find.text('Ikea Damansara，MYR 289.90，会从你的账本和总额里消失。'),
      findsOneWidget,
      reason: 'an Expense with no photo is not promised one is kept',
    );
    expect(find.text('留着'), findsOneWidget);
    expect(find.text('删除'), findsWidgets);
  });

  testWidgets('the Rollup is headed in Chinese and compares the month before '
      'it by name', (tester) async {
    await openCharts(tester);

    expect(find.text(thisMonth), findsWidgets);
    expect(find.text('按分类'), findsOneWidget);
    expect(find.text('逐月对比'), findsOneWidget);
    expect(find.text('你的钱花到哪里了'), findsOneWidget);
    expect(find.textContaining(previousMonth), findsOneWidget);

    for (final english in const [
      'By category',
      'Month by month',
      'Where your money went',
    ]) {
      expect(
        find.text(english),
        findsNothing,
        reason: '"$english" did not move',
      );
    }
  });

  testWidgets('the breakdown names its Categories in Chinese and its amounts '
      'in their own currency', (tester) async {
    await openCharts(tester);

    expect(find.text('食品杂货'), findsOneWidget);
    expect(find.text('MYR 423.10'), findsOneWidget);
    expect(find.text('油费'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
  });

  testWidgets('the trend labels its axis with Chinese months, not the first '
      'three characters of one', (tester) async {
    await openCharts(tester);

    expect(find.text('${now.month}月'), findsOneWidget);
    expect(find.text('${lastMonth.month}月'), findsOneWidget);
  });

  testWidgets('what a chart row announces is one Chinese sentence rather than '
      'two languages', (tester) async {
    final semantics = tester.ensureSemantics();
    await openCharts(tester);

    expect(
      find.bySemanticsLabel('食品杂货，MYR 423.10，3 笔支出'),
      findsOneWidget,
      reason: 'the count is inside the sentence, not glued onto the end of it',
    );
    expect(find.bySemanticsLabel(RegExp('Expenses?')), findsNothing);
    expect(
      find.bySemanticsLabel('$thisMonth，MYR 1806.75'),
      findsOneWidget,
      reason: 'a bar of the trend reads its month and its total',
    );

    semantics.dispose();
  });

  testWidgets('what was left out of the totals is one Chinese sentence with '
      'no English plural in it', (tester) async {
    await openCharts(tester);

    expect(find.text('这个月有 1 笔以 USD 支付的支出，没有计入这些总额。'), findsOneWidget);
    expect(
      find.text('这几个月有 2 笔以 SGD, USD 支付的支出，没有计入这些总额。'),
      findsOneWidget,
      reason: 'Chinese has one plural form, and the currency codes stay codes',
    );
    expect(find.textContaining('Expense'), findsNothing);
  });

  testWidgets('a month with nothing spent in it says so in Chinese', (
    tester,
  ) async {
    store = InMemoryLedgerStore();
    await openCharts(tester);

    expect(find.text('$thisMonth没有支出。'), findsOneWidget);
    expect(find.textContaining('Nothing spent'), findsNothing);
  });

  testWidgets('a month too thin to write up says so in Chinese', (
    tester,
  ) async {
    store = InMemoryLedgerStore([
      Expense(
        id: 'lonely',
        merchant: 'Kopitiam SS2',
        date: DateTime(now.year, now.month, 4),
        currency: 'MYR',
        total: 26.00,
        category: 'dining',
        source: ExpenseSource.manual,
        needsReview: false,
        lineItems: const [],
      ),
    ]);
    await openCharts(tester);

    expect(
      find.textContaining('才有值得写的东西'),
      findsOneWidget,
      reason: 'the count it needs lands inside the Chinese sentence',
    );
    expect(find.textContaining('A month needs'), findsNothing);
  });

  testWidgets('a Ledger with no Home Currency says why there are no totals, '
      'in Chinese', (tester) async {
    store = InMemoryLedgerStore();
    await openCharts(tester, homeCurrency: null);

    expect(find.text('还没有总额'), findsOneWidget);
    expect(find.textContaining('总额从你的第一笔支出开始'), findsOneWidget);
    expect(find.textContaining('Totals start with'), findsNothing);
  });
}
