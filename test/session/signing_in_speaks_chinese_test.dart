import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money/session/sign_in_gateway.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';

/// The first screen anybody meets, read in Chinese. This one is only possible
/// because the Language is a Setting on the phone: there is no account to read
/// a preference off yet.
///
/// `app_test.dart` pins the same states in English and is not touched.
void main() {
  late FakeSignInGateway signIn;
  late InMemoryLedgerStore store;

  setUp(() {
    signIn = FakeSignInGateway();
    store = InMemoryLedgerStore();
  });

  Future<void> open(WidgetTester tester, {SignInGateway? gateway}) async {
    await tester.pumpWidget(
      WhereMoneyApp(
        lock: FakeDeviceLock(),
        preferences: InMemoryDevicePreferences(locksOnOpen: false),
        signIn: gateway ?? signIn,
        storesFor: (_) => store.stores,
        model: FakeModelGateway(),
        language: 'zh',
        photograph: (_) async => null,
      ),
    );
  }

  testWidgets('a signed-out user is asked in Chinese', (tester) async {
    await open(tester);
    await tester.pumpAndSettle();

    expect(find.text('拍下收据，然后就可以把手机收起来。'), findsOneWidget);
    expect(find.text('用 Google 继续'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    expect(
      find.text('Photograph a receipt, put the phone away.'),
      findsNothing,
    );
  });

  testWidgets('the product keeps its name in Latin', (tester) async {
    await open(tester);
    await tester.pumpAndSettle();

    expect(find.text('Where Money'), findsOneWidget);
  });

  testWidgets('a sign-in that failed is explained in Chinese, and still says '
      'what the phone said', (tester) async {
    signIn.refuse = StateError('no network');
    await open(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('用 Google 继续'));
    await tester.pumpAndSettle();

    expect(find.textContaining('登录没有成功。'), findsOneWidget);
    expect(find.textContaining('no network'), findsOneWidget);
    expect(find.textContaining('Signing in did not work'), findsNothing);
  });

  testWidgets('a sign-in in flight says so in Chinese to a screen reader', (
    tester,
  ) async {
    final held = Completer<void>();
    signIn.holds = held;
    await open(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('用 Google 继续'));
    await tester.pump();

    expect(find.bySemanticsLabel('正在登录'), findsOneWidget);
    expect(find.bySemanticsLabel('Signing in'), findsNothing);

    held.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('the app opening before it knows who is signed in says so in '
      'Chinese', (tester) async {
    await open(tester, gateway: _StillReading());
    await tester.pump();

    expect(find.bySemanticsLabel('正在打开 Where Money'), findsOneWidget);
    expect(find.bySemanticsLabel('Opening Where Money'), findsNothing);
    expect(find.text('用 Google 继续'), findsNothing);
  });
}

/// A phone that has not yet said whether anybody is signed in, which is the
/// only way to hold the opening state still.
class _StillReading implements SignInGateway {
  @override
  Stream<SignedInUser?> changes() => const Stream.empty();

  @override
  Future<void> signIn() async {}

  @override
  Future<void> signOut() async {}
}
