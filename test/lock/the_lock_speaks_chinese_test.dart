import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money/lock/device_lock.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';

/// The Lock read in Chinese. The most defensive screen in the app, and the one
/// a user meets while already blocked from their own spending.
///
/// The Ledger underneath is deliberately empty: what this covers is not what
/// these tests are about, and `the_lock_on_screen_test.dart` pins that in
/// English.
void main() {
  late FakeDeviceLock lock;
  late InMemoryLedgerStore store;

  setUp(() {
    lock = FakeDeviceLock();
    store = InMemoryLedgerStore();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      WhereMoneyApp(
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        storesFor: (_) => store.stores,
        model: FakeModelGateway(),
        lock: lock,
        preferences: InMemoryDevicePreferences(),
        language: 'zh',
        photograph: (_) async => null,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a covered Ledger says in Chinese what is covering it', (
    tester,
  ) async {
    lock.answer = Unlocking.refused;

    await open(tester);

    expect(find.text('Where Money 已锁定'), findsOneWidget);
    expect(find.text('你的消费记录在这台手机上。解锁之后才能读。'), findsOneWidget);
  });

  testWidgets('a refusal says so in Chinese and offers another go', (
    tester,
  ) async {
    lock.answer = Unlocking.refused;

    await open(tester);

    expect(find.text('这次没有解开。'), findsOneWidget);
    expect(find.text('解锁'), findsOneWidget);
  });

  testWidgets('trying again in Chinese shows the Ledger', (tester) async {
    lock.answer = Unlocking.refused;
    await open(tester);

    lock.answer = Unlocking.unlocked;
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    expect(find.text('Where Money 已锁定'), findsNothing);
    expect(find.text('账本'), findsOneWidget);
  });

  testWidgets('the way out for a finger that has stopped working is in '
      'Chinese', (tester) async {
    lock.answer = Unlocking.refused;
    await open(tester);

    await tester.tap(find.text('改为退出登录'));
    await tester.pumpAndSettle();

    expect(find.text('用 Google 继续'), findsOneWidget);
    expect(find.text('Where Money 已锁定'), findsNothing);
  });

  testWidgets("the phone's own prompt asks in Chinese", (tester) async {
    await open(tester);

    expect(lock.reason, '解锁 Where Money 查看你的消费记录。');
  });

  testWidgets('nothing on the Lock is left in English', (tester) async {
    lock.answer = Unlocking.refused;

    await open(tester);

    for (final english in const [
      'Where Money is locked',
      'Your spending is on this phone. Unlock it to read it.',
      'That did not unlock it.',
      'Unlock',
      'Sign out instead',
    ]) {
      expect(
        find.text(english),
        findsNothing,
        reason: '"$english" did not move',
      );
    }
    expect(
      lock.reason,
      isNot(contains('Unlock Where Money')),
      reason: "the platform's own prompt did not move",
    );
  });
}
