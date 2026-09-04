import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money/scan/model_gateway.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';

/// The Recap, and the reasons there is not one, from the Setting down. What the
/// bloc does with a language is `the_recap_test.dart`'s; this file is about the
/// Setting reaching it, and about the six reasons reading in Chinese.
///
/// The Recap's own prose is the Model's and is never asserted here — the fake
/// answers with whatever the test hands it, which is the only honest thing a
/// test can say about words a Model writes.
void main() {
  late InMemoryDevicePreferences preferences;
  late InMemoryLedgerStore store;
  late FakeModelGateway model;

  setUp(() {
    preferences = InMemoryDevicePreferences(locksOnOpen: false);
    store = InMemoryLedgerStore(seedLedger());
    model = FakeModelGateway();
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> open(WidgetTester tester, {String language = 'en'}) async {
    tester.view
      ..physicalSize = const Size(1200, 3000)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(
      WhereMoneyApp(
        lock: FakeDeviceLock(),
        preferences: preferences,
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        storesFor: (_) => store.stores,
        model: model,
        homeCurrency: 'MYR',
        language: language,
        photograph: (_) async => null,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openCharts(WidgetTester tester, {String tooltip = 'Charts'}) =>
      tester.tap(find.byTooltip(tooltip)).then((_) => tester.pumpAndSettle());

  /// `tester.pageBack` looks for a tooltip called `Back`, which Material
  /// renames the moment the app is in Chinese. The icon is the same in both.
  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  Future<void> chooseChinese(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('中文').last);
    await tester.pumpAndSettle();
    await back(tester);
  }

  testWidgets('an app opened in 中文 asks for its Recap in 中文', (tester) async {
    await open(tester, language: 'zh');
    await openCharts(tester, tooltip: '图表');

    expect(model.recappedIn, ['zh']);
  });

  testWidgets('choosing 中文 asks for the month again in the new language', (
    tester,
  ) async {
    await open(tester);
    await openCharts(tester);
    expect(model.recappedIn, ['en']);
    await back(tester);

    await chooseChinese(tester);
    await openCharts(tester, tooltip: '图表');

    expect(model.recappedIn, ['en', 'zh']);
  });

  testWidgets('the Recap the new language asks for is the one on the screen', (
    tester,
  ) async {
    model.recapAnswer = FakeModelGateway.wrote('August was a quiet one.');
    await open(tester);
    await openCharts(tester);
    expect(find.text('August was a quiet one.'), findsOneWidget);
    await back(tester);

    model.recapAnswer = FakeModelGateway.wrote('八月过得挺省。');
    await chooseChinese(tester);
    await openCharts(tester, tooltip: '图表');

    expect(find.text('八月过得挺省。'), findsOneWidget);
    expect(find.text('August was a quiet one.'), findsNothing);
  });

  testWidgets('switching back serves the Recap already paid for', (
    tester,
  ) async {
    model.recapAnswer = FakeModelGateway.wrote('August was a quiet one.');
    await open(tester);
    await openCharts(tester);
    await back(tester);

    model.recapAnswer = FakeModelGateway.wrote('八月过得挺省。');
    await chooseChinese(tester);
    await openCharts(tester, tooltip: '图表');
    await back(tester);

    // A third answer, so a served cache and a fresh ask are told apart by what
    // is on the screen rather than by counting anything.
    model.recapAnswer = FakeModelGateway.wrote('A third nobody asked for.');
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    await back(tester);
    await openCharts(tester);

    expect(find.text('August was a quiet one.'), findsOneWidget);
    expect(find.text('A third nobody asked for.'), findsNothing);
    expect(model.recappedIn, ['en', 'zh']);
  });

  testWidgets('the Ledger is still there after a language change, unfetched', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Ikea Damansara'), findsWidgets);

    await chooseChinese(tester);

    expect(find.text('Ikea Damansara'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  for (final (name, answer, chinese, english) in [
    (
      'a refusal',
      FakeModelGateway.recapRefused,
      '模型不肯写这个月的回顾。',
      'The Model would not write up this month.',
    ),
    (
      'reasoning that ate the whole budget',
      FakeModelGateway.recapSilence,
      '模型对这个月没什么可说的。',
      'The Model had nothing to say about this month.',
    ),
    (
      "the day's allowance",
      const AllowanceSpent(),
      '今天的次数用完了。明天会有回顾。',
      "That is today's allowance. There will be a Recap tomorrow.",
    ),
    (
      'a refused token',
      const TokenRefused('expired'),
      '重新登录，回顾就会回来。',
      'Sign in again and the Recap will come back.',
    ),
    (
      'a dead network',
      const ModelOutOfReach('SocketException'),
      '没有网络就没有回顾。图表不需要网络。',
      'No Recap without a connection. The charts do not need one.',
    ),
    (
      'the Model being down at the far end',
      const ModelUnavailable('model_unavailable'),
      '联系不上模型。图表不需要它。',
      'The Model could not be reached. The charts do not need it.',
    ),
  ]) {
    testWidgets('$name says so in Chinese and leaves the charts standing', (
      tester,
    ) async {
      model.recapAnswer = answer;
      await open(tester, language: 'zh');
      await openCharts(tester, tooltip: '图表');

      expect(find.text(chinese), findsOneWidget);
      expect(find.text(english), findsNothing);
      expect(find.text('再问一次'), findsOneWidget);
      expect(find.text('按分类'), findsOneWidget);
    });
  }

  testWidgets('a reason is read in the language the interface is in, not the '
      'one the Recap was asked for', (tester) async {
    model.recapAnswer = const ModelOutOfReach('SocketException');
    await open(tester);
    await openCharts(tester);
    expect(
      find.text('No Recap without a connection. The charts do not need one.'),
      findsOneWidget,
    );
    await back(tester);

    await chooseChinese(tester);
    await openCharts(tester, tooltip: '图表');

    expect(find.text('没有网络就没有回顾。图表不需要网络。'), findsOneWidget);
  });
}
