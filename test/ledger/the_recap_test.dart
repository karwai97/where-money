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
  }) {
    final gateway = model ?? FakeModelGateway();
    final bloc = LedgerBloc(InMemoryLedgerStore(ledger), gateway, now: august)
      ..add(const LedgerOpened());
    return (bloc: bloc, model: gateway);
  }

  Future<LedgerReady> settled(LedgerBloc bloc) async {
    for (var turn = 0; turn < 5; turn++) {
      await Future<void>.delayed(Duration.zero);
    }
    return bloc.state as LedgerReady;
  }

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

    expect(state.rollup.monthLabel, 'August 2026');
    expect(state.recap, isA<RecapOnScreen>());
    await bloc.close();
  });

  test('reopening a month nobody has touched costs nothing', () async {
    final (:bloc, :model) = opened(seedLedger(around: august));
    await settled(bloc);
    expect(model.rollupsAsked, hasLength(1));

    bloc.add(const MonthStepped(-1));
    await settled(bloc);
    bloc.add(const MonthStepped(1));
    final state = await settled(bloc);

    expect(state.rollup.monthLabel, 'August 2026');
    expect(state.recap, isA<RecapOnScreen>());
    expect(
      model.rollupsAsked.where((sent) => sent.contains('August 2026')),
      hasLength(1),
      reason: 'the Rollup had not changed, so there was nothing to ask',
    );
    await bloc.close();
  });

  test('adding an Expense makes the next open ask again', () async {
    final store = InMemoryLedgerStore(seedLedger(around: august));
    final model = FakeModelGateway();
    final bloc = LedgerBloc(store, model, now: august)
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
    final bloc = LedgerBloc(store, model, now: august)
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
    final bloc = LedgerBloc(store, model, now: august)
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
    expect(sent['month'], state.rollup.monthLabel);
    expect(
      (sent['by_category'] as List).first,
      containsPair('category', state.rollup.byCategory.first.label),
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

    bloc.add(const MonthStepped(-1));
    await settled(bloc);
    bloc.add(const MonthStepped(1));
    final state = await settled(bloc);

    expect(state.recap, isA<RecapUnavailable>());
    expect(
      model.rollupsAsked.where((sent) => sent.contains('August 2026')),
      hasLength(1),
      reason: 'a refusal is an answer, and asking it again would cost money',
    );
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

  test('the Recap is never written to the Ledger', () async {
    final store = InMemoryLedgerStore(seedLedger(around: august));
    final before = store.contents.length;
    final bloc = LedgerBloc(store, FakeModelGateway(), now: august)
      ..add(const LedgerOpened());
    await settled(bloc);

    expect(store.contents.length, before);
    expect(store.waiting, isEmpty);
    await bloc.close();
  });
}
