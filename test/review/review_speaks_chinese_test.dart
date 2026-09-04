import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';
import '../scan/inbox_bloc_test.dart' show photograph;
import 'where_things_sit.dart';

/// The Review screen read in Chinese, on a real widget tree rather than
/// through [sayingFor]. The Ledger it is reached from speaks Chinese too since
/// ticket 06, so the way in is a Chinese tooltip.
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

  Future<void> openTheLedger(WidgetTester tester) async {
    // Review is a long form and the default test viewport is a small phone, so
    // half of it would never be built.
    tester.view
      ..physicalSize = const Size(1000, 4000)
      ..devicePixelRatio = 1;

    await tester.pumpWidget(
      WhereMoneyApp(
        lock: FakeDeviceLock(),
        preferences: InMemoryDevicePreferences(locksOnOpen: false),
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        storesFor: (_) => store.stores,
        model: model,
        language: 'zh',
        photograph: (_) async => null,
        clock: () => fixtureNow,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openReview(WidgetTester tester) async {
    await openTheLedger(tester);
    await tester.tap(find.byTooltip('手动添加一笔支出'));
    await tester.pumpAndSettle();
  }

  /// Review over what the Model read, reached the way a user reaches it: in
  /// through a Chinese Inbox.
  Future<void> openReviewOfAScan(WidgetTester tester, Extraction read) async {
    final scan = await store.capture(photograph(width: 300, height: 400));
    await store.put(scan.movedTo(ScanState.extracted, extraction: read));

    await openTheLedger(tester);
    await tester.tap(find.byTooltip('待处理，1 张等着'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复核'));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String label, String value) async {
    await tester.enterText(find.widgetWithText(TextField, label).first, value);
    await tester.pumpAndSettle();
  }

  testWidgets('the form and its fields are named in Chinese', (tester) async {
    await openReview(tester);

    expect(find.text('添加一笔支出'), findsOneWidget);
    expect(find.text('商家'), findsOneWidget);
    expect(find.text('日期'), findsOneWidget);
    expect(find.text('货币'), findsOneWidget);
    expect(find.text('小计'), findsOneWidget);
    expect(find.text('总额'), findsOneWidget);
    expect(find.text('明细'), findsOneWidget);
    expect(find.text('加入账本'), findsOneWidget);
    expect(find.byTooltip('选择日期'), findsOneWidget);
  });

  testWidgets('no field on the form is still labelled in English', (
    tester,
  ) async {
    await openReview(tester);

    for (final english in const [
      'Add an Expense',
      'Merchant',
      'Date',
      'Currency',
      'Subtotal',
      'Tax',
      'Tip',
      'Total',
      'Category',
      'Paid with',
      'Line Items',
      'Add a Line Item',
      'Add to Ledger',
    ]) {
      expect(
        find.text(english),
        findsNothing,
        reason: '"$english" did not move',
      );
    }
  });

  testWidgets('what the Check noticed is said in Chinese', (tester) async {
    await openReview(tester);

    expect(find.text('没有总额'), findsOneWidget);
    expect(
      find.textContaining('总额是零或负数'),
      findsOneWidget,
      reason: 'a Finding is a sentence in either language, not a rule name',
    );
  });

  testWidgets('a Finding still goes the moment the correction settles it', (
    tester,
  ) async {
    await openReview(tester);

    await type(tester, '小计', '20.00');
    await type(tester, '税', '1.20');
    await type(tester, '总额', '30.00');

    expect(find.text('总额对不上'), findsOneWidget);
    expect(
      find.textContaining('小计 20.00 + 税 1.20'),
      findsOneWidget,
      reason: 'the numbers land inside the Chinese sentence',
    );

    await type(tester, '总额', '21.20');

    expect(find.text('总额对不上'), findsNothing);
  });

  testWidgets('a Finding reads in Chinese under the field it is about', (
    tester,
  ) async {
    await openReview(tester);

    final saying = rectOf(tester, find.text('没有商家'));
    expect(saying.top, greaterThan(fieldNamed(tester, '商家').bottom));
    expect(saying.bottom, lessThan(fieldNamed(tester, '日期').top));
    expect(find.text('No merchant'), findsNothing);
  });

  testWidgets('what the rows do not add up to reads in Chinese with the rows', (
    tester,
  ) async {
    await openReview(tester);

    await tester.tap(find.text('添加一项明细'));
    await tester.pumpAndSettle();
    await type(tester, '金额', '5.00');

    expect(find.text('明细与总额不符'), findsOneWidget);
    expect(
      rectOf(tester, find.text('明细与总额不符')).top,
      greaterThan(rectOf(tester, find.text('明细')).bottom),
    );
    expect(find.text('Line items do not match total'), findsNothing);
  });

  testWidgets('a photo that is not a receipt says so in Chinese across the '
      'whole form', (tester) async {
    await openReviewOfAScan(tester, notAReceiptExtraction);

    expect(find.text('不是收据'), findsOneWidget);
    expect(find.textContaining('模型认为这张图不是收据'), findsOneWidget);
    expect(
      rectOf(tester, find.text('不是收据')).bottom,
      lessThan(fieldNamed(tester, '商家').top),
    );
    expect(find.text('Not a receipt'), findsNothing);
  });

  testWidgets('what the Model and the Check said about a Scan reads in '
      'Chinese', (tester) async {
    await openReviewOfAScan(tester, flawedExtraction);

    expect(find.text('模型要求人工复核'), findsOneWidget);
    expect(find.text('明细与小计不符'), findsOneWidget);
    expect(find.text('没有日期'), findsOneWidget);
    for (final english in const [
      'Model asked for review',
      'Line items do not match subtotal',
      'No date',
    ]) {
      expect(
        find.text(english),
        findsNothing,
        reason: '"$english" did not move',
      );
    }
  });

  testWidgets('a row that does not multiply out reads in Chinese with the '
      'Line Items', (tester) async {
    await openReview(tester);

    await tester.tap(find.text('添加一项明细'));
    await tester.pumpAndSettle();
    await type(tester, '数量', '2');
    await type(tester, '单价', '3.00');
    await type(tester, '金额', '5.00');

    expect(find.text('这一行算不对'), findsOneWidget);
    expect(
      rectOf(tester, find.text('这一行算不对')).top,
      greaterThan(rectOf(tester, find.text('明细')).bottom),
    );
    expect(find.text('Line arithmetic off'), findsNothing);
  });

  testWidgets('a refused commit says so in Chinese', (tester) async {
    store.refuseWrites = StateError('denied');

    await openReview(tester);
    await type(tester, '商家', '嘉家咖啡店');
    await type(tester, '货币', 'MYR');
    await type(tester, '总额', '26.00');
    await tester.tap(find.text('加入账本'));
    await tester.pumpAndSettle();

    expect(find.textContaining('这笔支出没有保存'), findsOneWidget);
    expect(find.textContaining('was not saved'), findsNothing);
    expect(find.text('嘉家咖啡店'), findsOneWidget);
  });

  testWidgets('a receipt that came back clean says so in Chinese', (
    tester,
  ) async {
    await openReviewOfAScan(tester, cleanExtraction);

    expect(find.textContaining('这张收据上的数字都对得上'), findsOneWidget);
    expect(
      find.textContaining('Everything on this receipt adds up'),
      findsNothing,
    );
  });

  testWidgets('the Categories on offer are named in Chinese', (tester) async {
    await openReview(tester);

    await tester.tap(find.text('其他').first);
    await tester.pumpAndSettle();

    expect(find.text('外食'), findsWidgets);
    expect(find.text('食品杂货'), findsWidgets);
    expect(find.text('Dining out'), findsNothing);
  });

  testWidgets('a Line Item names its own columns in Chinese', (tester) async {
    await openReview(tester);

    await tester.tap(find.text('添加一项明细'));
    await tester.pumpAndSettle();

    expect(find.text('说明'), findsOneWidget);
    expect(find.text('数量'), findsOneWidget);
    expect(find.text('单价'), findsOneWidget);
    expect(find.text('Description'), findsNothing);

    await tester.tap(find.byTooltip('删除这项明细'));
    await tester.pumpAndSettle();

    expect(find.text('说明'), findsNothing);
  });
}
