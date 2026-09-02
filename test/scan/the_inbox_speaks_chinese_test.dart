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
import 'inbox_bloc_test.dart' show photograph;

/// The Inbox read in Chinese, and with it every way a Scan can fail. This is
/// the copy a user most needs in their own language: something went wrong and
/// the app is the only thing that knows what to do next.
///
/// Modelled on `failure_on_screen_test.dart`, which pins the same states in
/// English. The two are deliberately the same shape — a Scan is walked into
/// each state through the camera, because a Scan is only written beside an
/// image and there is no seeding it from the outside.
void main() {
  late InMemoryLedgerStore store;
  late FakeModelGateway model;

  setUp(() {
    store = InMemoryLedgerStore();
    model = FakeModelGateway();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      WhereMoneyApp(
        lock: FakeDeviceLock(),
        preferences: InMemoryDevicePreferences(locksOnOpen: false),
        signIn: FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai),
        storesFor: (_) => store.stores,
        model: model,
        language: 'zh',
        photograph: (_) async => photograph(width: 600, height: 800),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Resizing and the Model both answer off the test binding's fake clock, so
  /// this hands the real event loop time before pumping again.
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('never found ${finder.describeMatch(Plurality.one)}');
  }

  /// Takes the tree down, which closes the Inbox and cancels the timer a Scan
  /// waiting on a signal leaves running.
  Future<void> shut(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  Future<void> photographInto(WidgetTester tester, String line) async {
    await tester.tap(find.byTooltip('拍一张收据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('拍照'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.byTooltip('待处理，1 张等着'));
    await tester.tap(find.byTooltip('待处理，1 张等着'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text(line));
  }

  testWidgets('an empty Inbox names itself and says so in Chinese', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byTooltip('待处理'));
    await tester.pumpAndSettle();

    expect(find.text('待处理'), findsOneWidget);
    expect(find.text('没有等着处理的收据。'), findsOneWidget);
    expect(find.text('Inbox'), findsNothing);
    expect(find.text('No receipts waiting.'), findsNothing);
    await shut(tester);
  });

  for (final (name, answer, saying, next) in [
    ('a refusal', FakeModelGateway.refusal, '模型不肯读这张照片', '重新拍得清楚一些，多半就能读出来。'),
    (
      'reasoning that ate the whole output budget',
      FakeModelGateway.silence,
      '模型什么都没有答',
      '再读一次通常就好了。',
    ),
    (
      'an answer that was not the promised JSON',
      FakeModelGateway.gibberish,
      '模型的回答读不通',
      '再读一次通常就好了。',
    ),
    (
      'a dead network',
      const ModelOutOfReach('SocketException'),
      '读这张的时候没有网络',
      '它会自己继续试。',
    ),
    (
      'the Model being down at the far end',
      const ModelUnavailable('model_unavailable'),
      '模型当时用不了',
      '这种情况通常一会儿就过去。过一分钟再读一次。',
    ),
    (
      'a refused token',
      const TokenRefused('expired'),
      '你的登录没有被接受',
      '重新登录，然后再读一次。',
    ),
    (
      'an image the Worker would not take',
      const ImageNotAccepted('image_too_large'),
      '这张照片没能发出去',
      '把收据重新拍一次。',
    ),
  ]) {
    testWidgets('$name says so in Chinese, and says what to do next', (
      tester,
    ) async {
      model.answer = answer;
      await open(tester);

      await photographInto(tester, saying);

      expect(find.text(saying), findsOneWidget);
      expect(find.text(next), findsOneWidget);
      expect(find.byTooltip('放弃这次扫描'), findsOneWidget);
      await shut(tester);
    });
  }

  testWidgets('a failed Scan reads its photographed moment the way Chinese '
      'reads a moment', (tester) async {
    model.answer = FakeModelGateway.refusal;
    await open(tester);

    await photographInto(tester, '模型不肯读这张照片');

    expect(find.textContaining('拍摄于'), findsOneWidget);
    expect(find.textContaining('Photographed'), findsNothing);
    expect(
      find.textContaining(RegExp('AM|PM')),
      findsNothing,
      reason: 'Chinese keeps a 24-hour clock, which is what CLDR says for zh',
    );
    await shut(tester);
  });

  testWidgets('the daily cap says so in Chinese and says when it resets', (
    tester,
  ) async {
    model.answer = AllowanceSpent(resetsAt: DateTime(2026, 8, 26, 16, 30));
    await open(tester);

    await photographInto(tester, '今天的扫描次数用完了');

    expect(find.text('2026年8月26日 16:30 之后可以再扫描。'), findsOneWidget);
    await shut(tester);
  });

  testWidgets('a cap with no reset time still does not say something went '
      'wrong, in Chinese', (tester) async {
    model.answer = const AllowanceSpent();
    await open(tester);

    await photographInto(tester, '今天的扫描次数用完了');

    expect(find.text('明天可以再扫描。'), findsOneWidget);
    expect(find.textContaining('Scans'), findsNothing);
    await shut(tester);
  });

  testWidgets('a photo that is not a receipt says so in Chinese and is only '
      'offered discarding', (tester) async {
    model.answer = FakeModelGateway.reading(notAReceiptExtraction);
    await open(tester);

    await photographInto(tester, '这看起来不像收据');

    expect(find.text('丢弃'), findsOneWidget);
    expect(find.text('复核'), findsNothing);
    expect(find.text('Discard'), findsNothing);
    await shut(tester);
  });

  testWidgets('discarding a photo that is not a receipt asks in Chinese', (
    tester,
  ) async {
    model.answer = FakeModelGateway.reading(notAReceiptExtraction);
    await open(tester);
    await photographInto(tester, '这看起来不像收据');

    await tester.tap(find.text('丢弃'));
    await tester.pumpAndSettle();

    expect(find.text('丢弃这张照片会把它从手机里删掉。'), findsOneWidget);
    expect(find.text('留着'), findsOneWidget);
    await shut(tester);
  });

  testWidgets('abandoning a Scan asks in Chinese and promises the photo goes '
      'with it', (tester) async {
    model.answer = FakeModelGateway.refusal;
    await open(tester);
    await photographInto(tester, '模型不肯读这张照片');

    await tester.tap(find.byTooltip('放弃这次扫描'));
    await tester.pumpAndSettle();

    expect(find.text('放弃这次扫描会把它的照片从手机里删掉。'), findsOneWidget);
    expect(find.text('留着'), findsOneWidget);
    expect(find.text('放弃'), findsOneWidget);
    await shut(tester);
  });

  testWidgets('a Scan waiting to be Reviewed says so in Chinese and offers '
      'both a Review and a second read where one is due', (tester) async {
    await open(tester);

    await photographInto(tester, '可以复核了');

    expect(find.text('复核'), findsOneWidget);
    expect(find.text('再读一次'), findsNothing);
    await shut(tester);
  });

  testWidgets('a failed Scan can be read again in Chinese', (tester) async {
    model.answer = FakeModelGateway.refusal;
    await open(tester);
    await photographInto(tester, '模型不肯读这张照片');

    model.answer = FakeModelGateway.reading(cleanExtraction);
    await tester.tap(find.text('再读一次'));
    await waitFor(tester, find.text('可以复核了'));

    expect(find.text('可以复核了'), findsOneWidget);
    expect(find.text('Read again'), findsNothing);
    await shut(tester);
  });

  testWidgets('nothing left in the Inbox is still in English', (tester) async {
    model.answer = FakeModelGateway.refusal;
    await open(tester);

    await photographInto(tester, '模型不肯读这张照片');

    for (final english in const [
      'Inbox',
      'Read again',
      'Review',
      'Discard',
      'Abandon',
      'Keep',
      'A clearer photograph is the likeliest fix.',
    ]) {
      expect(
        find.text(english),
        findsNothing,
        reason: '"$english" did not move',
      );
    }
    for (final tooltip in const [
      'Abandon this Scan',
      'Zoom into the receipt',
    ]) {
      expect(
        find.byTooltip(tooltip),
        findsNothing,
        reason: '"$tooltip" did not move',
      );
    }
    await shut(tester);
  });

  testWidgets('the receipt up close is titled in Chinese', (tester) async {
    await open(tester);
    await photographInto(tester, '可以复核了');

    await tester.tap(find.text('复核'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('放大收据'));
    await tester.pumpAndSettle();

    expect(find.text('这张收据'), findsOneWidget);
    expect(find.byTooltip('返回各项字段'), findsOneWidget);
    expect(find.text('The receipt'), findsNothing);
    await shut(tester);
  });
}
