import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';

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

  Future<void> openReview(WidgetTester tester) async {
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('手动添加一笔支出'));
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
