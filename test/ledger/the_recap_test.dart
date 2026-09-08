import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/ledger/ledger_bloc.dart';
import 'package:where_money/scan/model_gateway.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/fake_model_gateway.dart';
import '../fakes/in_memory_ledger_store.dart';

void main() {
  final august = DateTime(2026, 8, 23);

  Expense spent(String merchant, double total, {int day = 6}) => Expense(
    id: 'x-$merchant-$day',
    merchant: merchant,
    date: DateTime(2026, 8, day),
    currency: 'MYR',
    total: total,
    category: 'dining',
    lineItems: const [],
    source: ExpenseSource.manual,
    needsReview: false,
  );

  ({LedgerBloc bloc, FakeModelGateway model}) opened(
    List<Expense> ledger, {
    FakeModelGateway? model,
    String language = defaultLanguage,
  }) {
    final gateway = model ?? FakeModelGateway();
    final bloc = LedgerBloc(
      InMemoryLedgerStore(ledger),
      gateway,
      now: august,
      language: language,
      homeCurrency: 'MYR',
    )..add(const LedgerOpened());
    return (bloc: bloc, model: gateway);
  }

  Future<LedgerReady> settled(LedgerBloc bloc) async {
    for (var turn = 0; turn < 5; turn++) {
      await Future<void>.delayed(Duration.zero);
    }
    return bloc.state as LedgerReady;
  }

  test('the Model is asked to write in the language the app is in', () async {
    final (:bloc, :model) = opened(seedLedger(around: august), language: 'zh');

    await settled(bloc);

    expect(model.recappedIn, ['zh']);
    await bloc.close();
  });

  test('an app that has not been told a language asks in English', () async {
    final (:bloc, :model) = opened(seedLedger(around: august));

    await settled(bloc);

    expect(model.recappedIn, ['en']);
    await bloc.close();
  });

  test('the month on screen is read back in words', () async {
    final (:bloc, :model) = opened(
      seedLedger(around: august),
      model: FakeModelGateway(
        recapAnswer: FakeModelGateway.wrote('Groceries took the most of it.'),
      ),
    );

    final state = await settled(bloc);

    expect(state.recap, isA<RecapOnScreen>());
    expect(
      (state.recap as RecapOnScreen).text,
      'Groceries took the most of it.',
    );
    expect(model.rollupsAsked, hasLength(1));
    await bloc.close();
  });

  test('the month the user is in gets one, incomplete as it is', () async {
    final (:bloc, model: _) = opened(seedLedger(around: august));
    final state = await settled(bloc);

    expect(state.rollup.month, 8);
    expect(state.recap, isA<RecapOnScreen>());
    await bloc.close();
  });

  test('reopening a month nobody has touched costs nothing', () async {
    final (:bloc, :model) = opened(seedLedger(around: august));
    await settled(bloc);
    expect(model.rollupsAsked, hasLength(1));

    bloc.add(const MonthPicked(2026, 7));
    await settled(bloc);
    bloc.add(const MonthPicked(2026, 8));
    final state = await settled(bloc);

    expect(state.rollup.month, 8);
    expect(state.recap, isA<RecapOnScreen>());
    expect(
      model.rollupsAsked.where((sent) => sent.contains('"month":8')),
      hasLength(1),
      reason: 'the Rollup had not changed, so there was nothing to ask',
    );
    await bloc.close();
  });

  test('adding an Expense makes the next open ask again', () async {
    final store = InMemoryLedgerStore(seedLedger(around: august));
    final model = FakeModelGateway();
    final bloc = LedgerBloc(store, model, now: august, homeCurrency: 'MYR')
      ..add(const LedgerOpened());
    await settled(bloc);
    expect(model.rollupsAsked, hasLength(1));

    await store.add(spent('Family Mart', 12.30));
    await settled(bloc);

    expect(model.rollupsAsked, hasLength(2));
    await bloc.close();
  });

  test('deleting an Expense makes the next open ask again', () async {
    final ledger = seedLedger(around: august);
    final store = InMemoryLedgerStore(ledger);
    final model = FakeModelGateway();
    final bloc = LedgerBloc(store, model, now: august, homeCurrency: 'MYR')
      ..add(const LedgerOpened());
    await settled(bloc);
    expect(model.rollupsAsked, hasLength(1));

    final duplicate = ledger.firstWhere((e) => e.merchant == 'Ikea Damansara');
    bloc.add(ExpenseDeleted(duplicate.id));
    await settled(bloc);

    expect(store.contents.map((e) => e.id), isNot(contains(duplicate.id)));
    expect(model.rollupsAsked, hasLength(2));
    await bloc.close();
  });

  test('correcting an Expense makes the next open ask again', () async {
    final ledger = seedLedger(around: august);
    final store = InMemoryLedgerStore(ledger);
    final model = FakeModelGateway();
    final bloc = LedgerBloc(store, model, now: august, homeCurrency: 'MYR')
      ..add(const LedgerOpened());
    await settled(bloc);

    final wrong = ledger.firstWhere((e) => e.merchant == 'Ikea Damansara');
    await store.add(
      Expense(
        id: wrong.id,
        merchant: wrong.merchant,
        date: wrong.date,
        currency: wrong.currency,
        total: 389.90,
        category: wrong.category,
        lineItems: wrong.lineItems,
        source: wrong.source,
        needsReview: wrong.needsReview,
      ),
    );
    await settled(bloc);

    expect(model.rollupsAsked, hasLength(2));
    await bloc.close();
  });

  test('three receipts are not asked to mean anything', () async {
    final (:bloc, :model) = opened([
      spent('Kopitiam', 12.00, day: 2),
      spent('Grab', 8.40, day: 3),
      spent('Guardian', 21.90, day: 4),
    ]);

    final state = await settled(bloc);

    expect(state.recap, isA<RecapTooFewExpenses>());
    expect(model.rollupsAsked, isEmpty);
    await bloc.close();
  });

  test('an empty month says so rather than asking', () async {
    final (:bloc, :model) = opened(const []);
    final state = await settled(bloc);

    expect(state.recap, isA<RecapTooFewExpenses>());
    expect(model.rollupsAsked, isEmpty);
    await bloc.close();
  });

  test('only the Rollup is sent, never the Ledger under it', () async {
    final (:bloc, :model) = opened(seedLedger(around: august));
    await settled(bloc);

    final sent = model.rollupsAsked.single;
    expect(sent, isNot(contains('Guardian Pharmacy')));
    expect(sent, isNot(contains('line_items')));
    expect(sent.length, lessThan(2000));
    await bloc.close();
  });

  test('what is sent is the arithmetic the charts drew', () async {
    final (:bloc, :model) = opened(seedLedger(around: august));
    final state = await settled(bloc);

    final sent = jsonDecode(model.rollupsAsked.single) as Map<String, dynamic>;
    expect(sent['total'], closeTo(state.rollup.total, 0.01));
    expect(sent['year'], state.rollup.year);
    expect(sent['month'], state.rollup.month);
    expect(
      (sent['by_category'] as List).first,
      containsPair('category', state.rollup.byCategory.first.category),
    );
    await bloc.close();
  });

  test(
    'a Recap that could not be written leaves the charts standing',
    () async {
      final (:bloc, model: _) = opened(
        seedLedger(around: august),
        model: FakeModelGateway(
          recapAnswer: const ModelOutOfReach('no signal'),
        ),
      );

      final state = await settled(bloc);

      expect(state.recap, isA<RecapUnavailable>());
      expect(state.rollup.hasSpending, isTrue);
      expect(state.rollup.byCategory, isNotEmpty);
      expect(state.inMonth, isNotEmpty);
      await bloc.close();
    },
  );

  test('a Model that refused is not asked the same thing again', () async {
    final (:bloc, :model) = opened(
      seedLedger(around: august),
      model: FakeModelGateway(recapAnswer: FakeModelGateway.recapRefused),
    );
    await settled(bloc);

    bloc.add(const MonthPicked(2026, 7));
    await settled(bloc);
    bloc.add(const MonthPicked(2026, 8));
    final state = await settled(bloc);

    expect(state.recap, isA<RecapUnavailable>());
    expect(
      model.rollupsAsked.where((sent) => sent.contains('"month":8')),
      hasLength(1),
      reason: 'a refusal is an answer, and asking it again would cost money',
    );
    await bloc.close();
  });

  /// The gateway promises a typed answer for every failure it knows about, and
  /// keeps that promise for everything it reaches over the wire. It fetches an
  /// ID token first, though, outside its own `try`, and Firebase throws there
  /// on a dead connection or a revoked token. A month that hits that used to
  /// sit on a spinner nothing could clear: the hash stayed claimed, no answer
  /// was ever kept, and the retry below does nothing while the state is
  /// pending.
  test(
    'a Model call that throws leaves the month somewhere it can leave',
    () async {
      final model = FakeModelGateway()..throws = StateError('no token');
      final (:bloc, model: _) = opened(
        seedLedger(around: august),
        model: model,
      );

      final state = await settled(bloc);

      expect(state.recap, const RecapUnavailable(WhyNoRecap.modelUnavailable));
      await bloc.close();
    },
  );

  test('a month whose Model call threw can be asked about again', () async {
    final model = FakeModelGateway()..throws = StateError('no token');
    final (:bloc, model: _) = opened(seedLedger(around: august), model: model);
    expect((await settled(bloc)).recap, isA<RecapUnavailable>());

    model.throws = null;
    model.recapAnswer = FakeModelGateway.wrote('August came to MYR 1806.75.');
    bloc.add(const RecapAskedAgain());
    final state = await settled(bloc);

    expect((state.recap as RecapOnScreen).text, 'August came to MYR 1806.75.');
    await bloc.close();
  });

  test('asking again is something the user can do', () async {
    final model = FakeModelGateway(
      recapAnswer: const ModelOutOfReach('no signal'),
    );
    final (:bloc, model: _) = opened(seedLedger(around: august), model: model);
    expect((await settled(bloc)).recap, isA<RecapUnavailable>());

    model.recapAnswer = FakeModelGateway.wrote('August came to MYR 1806.75.');
    bloc.add(const RecapAskedAgain());
    final state = await settled(bloc);

    expect((state.recap as RecapOnScreen).text, 'August came to MYR 1806.75.');
    await bloc.close();
  });

  test(
    'changing the language asks for the month again, in the new one',
    () async {
      final (:bloc, :model) = opened(seedLedger(around: august));
      await settled(bloc);
      expect(model.recappedIn, ['en']);

      model.recapAnswer = FakeModelGateway.wrote('八月花得不算少。');
      bloc.add(const LanguageChanged('zh'));
      final state = await settled(bloc);

      expect(model.recappedIn, ['en', 'zh']);
      expect((state.recap as RecapOnScreen).text, '八月花得不算少。');
      await bloc.close();
    },
  );

  // Nothing cached needs invalidating by hand: `rollupHash` already hashes the
  // currency the month was computed in, so a change simply misses.
  test('changing the Home Currency re-keys the month and asks again', () async {
    // Enough spending in each currency for either to be worth writing up, so
    // the second ask is the re-key rather than a month that only just got big
    // enough.
    final abroad = [
      for (var day = 1; day <= minimumExpensesForRecap; day++)
        spent('Kopitiam SS2', 12.00, day: day).copyWith(currency: 'SGD'),
    ];
    final (:bloc, :model) = opened([...seedLedger(around: august), ...abroad]);
    await settled(bloc);
    expect(model.rollupsAsked, hasLength(1));

    bloc.add(const HomeCurrencyChanged('SGD'));
    await settled(bloc);

    expect(model.rollupsAsked, hasLength(2));
    expect(model.rollupsAsked.last, contains('SGD'));
    await bloc.close();
  });

  test('changing back serves the Recap already paid for', () async {
    final (:bloc, :model) = opened(seedLedger(around: august));
    await settled(bloc);
    final english = (await settled(bloc)).recap as RecapOnScreen;

    model.recapAnswer = FakeModelGateway.wrote('八月花得不算少。');
    bloc.add(const LanguageChanged('zh'));
    await settled(bloc);

    // A third answer, so serving either of the first two is distinguishable
    // from asking again.
    model.recapAnswer = FakeModelGateway.wrote(
      'A third answer nobody asked for.',
    );
    bloc.add(const LanguageChanged('en'));
    final state = await settled(bloc);

    expect((state.recap as RecapOnScreen).text, english.text);
    expect(model.recappedIn, [
      'en',
      'zh',
    ], reason: 'the English Recap was already paid for');
    await bloc.close();
  });

  test('changing the language does not reload the Ledger', () async {
    final store = InMemoryLedgerStore(seedLedger(around: august));
    final bloc = LedgerBloc(
      store,
      FakeModelGateway(),
      now: august,
      homeCurrency: 'MYR',
    )..add(const LedgerOpened());
    final before = (await settled(bloc)).expenses;

    final seen = <LedgerState>[];
    bloc.stream.listen(seen.add);
    bloc.add(const LanguageChanged('zh'));
    final state = await settled(bloc);

    expect(state.expenses, before);
    expect(
      seen.whereType<LedgerLoading>(),
      isEmpty,
      reason: 'a UI preference is no reason to fetch the Ledger over again',
    );
    await bloc.close();
  });

  test('the same month sends the same prompt in either language', () async {
    final english = opened(seedLedger(around: august));
    await settled(english.bloc);
    await english.bloc.close();

    final chinese = opened(seedLedger(around: august), language: 'zh');
    await settled(chinese.bloc);

    expect(
      chinese.model.rollupsAsked.single,
      english.model.rollupsAsked.single,
      reason:
          'the prompt carries slugs and numbers, so the Language rides '
          'beside it rather than inside it (ADR-0007)',
    );
    expect(chinese.model.rollupsAsked.single, isNot(contains('Groceries')));
    await chinese.bloc.close();
  });

  test(
    'a month already in the language asked for is not asked again',
    () async {
      final (:bloc, :model) = opened(
        seedLedger(around: august),
        language: 'zh',
      );
      await settled(bloc);

      bloc.add(const LanguageChanged('zh'));
      await settled(bloc);

      expect(model.recappedIn, ['zh']);
      await bloc.close();
    },
  );

  for (final (name, answer, why) in [
    ('a refusal', FakeModelGateway.recapRefused, WhyNoRecap.refused),
    (
      'reasoning that ate the whole budget',
      FakeModelGateway.recapSilence,
      WhyNoRecap.nothingToSay,
    ),
    ("the day's allowance", const AllowanceSpent(), WhyNoRecap.allowanceSpent),
    ('a refused token', const TokenRefused('expired'), WhyNoRecap.tokenRefused),
    (
      'a dead network',
      const ModelOutOfReach('SocketException'),
      WhyNoRecap.outOfReach,
    ),
    (
      'the Model being down at the far end',
      const ModelUnavailable('model_unavailable'),
      WhyNoRecap.modelUnavailable,
    ),
  ]) {
    test('$name is a kind rather than a sentence', () async {
      final (:bloc, model: _) = opened(
        seedLedger(around: august),
        model: FakeModelGateway(recapAnswer: answer),
      );

      final state = await settled(bloc);

      expect((state.recap as RecapUnavailable).why, why);
      await bloc.close();
    });
  }

  test('the Recap is never written to the Ledger', () async {
    final store = InMemoryLedgerStore(seedLedger(around: august));
    final before = store.contents.length;
    final bloc = LedgerBloc(
      store,
      FakeModelGateway(),
      now: august,
      homeCurrency: 'MYR',
    )..add(const LedgerOpened());
    await settled(bloc);

    expect(store.contents.length, before);
    expect(store.waiting, isEmpty);
    await bloc.close();
  });
}
