import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/ledger/ledger_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/fake_model_gateway.dart';
import '../fakes/in_memory_ledger_store.dart';

void main() {
  final august = DateTime(2026, 8, 23);
  final augustLedger = seedLedger(around: august);

  blocTest<LedgerBloc, LedgerState>(
    'opening an empty Ledger settles on nothing rather than on a spinner',
    build: () =>
        LedgerBloc(InMemoryLedgerStore(), FakeModelGateway(), homeCurrency: 'MYR'),
    act: (bloc) => bloc.add(const LedgerOpened()),
    expect: () => [
      isA<LedgerReady>().having((state) => state.expenses, 'expenses', isEmpty),
    ],
  );

  blocTest<LedgerBloc, LedgerState>(
    'an existing Ledger arrives newest first',
    build: () =>
        LedgerBloc(
          InMemoryLedgerStore(augustLedger),
          FakeModelGateway(),
          homeCurrency: 'MYR',
        ),
    act: (bloc) => bloc.add(const LedgerOpened()),
    verify: (bloc) {
      final expenses = (bloc.state as LedgerReady).expenses;
      expect(expenses, hasLength(augustLedger.length));
      expect(
        expenses.first.date.isAfter(expenses.last.date),
        isTrue,
        reason: 'the newest Expense should be at the top of the list',
      );
    },
  );

  test('an Expense committed elsewhere turns up in the Ledger without it '
      'being asked again', () async {
    final store = InMemoryLedgerStore();
    final bloc = LedgerBloc(store, FakeModelGateway(), homeCurrency: 'MYR')
      ..add(const LedgerOpened());
    await Future<void>.delayed(Duration.zero);

    await store.add(
      Expense.fromExtraction(cleanExtraction, id: 'a', now: fixtureNow),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      (bloc.state as LedgerReady).expenses.single.merchant,
      'Village Grocer Bangsar',
    );
    await bloc.close();
  });

  blocTest<LedgerBloc, LedgerState>(
    'a Ledger the rules refuse to read says so instead of showing an empty list',
    build: () => LedgerBloc(
      InMemoryLedgerStore()..refuseReads = StateError('denied'),
      FakeModelGateway(),
      homeCurrency: 'MYR',
    ),
    act: (bloc) => bloc.add(const LedgerOpened()),
    expect: () => [isA<LedgerUnavailable>()],
  );

  LedgerBloc opened(InMemoryLedgerStore store) =>
      LedgerBloc(store, FakeModelGateway(), now: august, homeCurrency: 'MYR')
        ..add(const LedgerOpened());

  Future<LedgerReady> settled(LedgerBloc bloc) async {
    await Future<void>.delayed(Duration.zero);
    return bloc.state as LedgerReady;
  }

  test('the Ledger opens on the month the user is in', () async {
    final bloc = opened(InMemoryLedgerStore(seedLedger(around: august)));

    expect((await settled(bloc)).rollup.month, 8);
    await bloc.close();
  });

  test(
    'a month shows what was spent in it and nothing from any other',
    () async {
      final bloc = opened(InMemoryLedgerStore(seedLedger(around: august)));
      final state = await settled(bloc);

      expect(
        state.inMonth.every((e) => e.date.month == 8 && e.date.year == 2026),
        isTrue,
      );
      expect(state.inMonth.map((e) => e.merchant), contains('Ikea Damansara'));
      expect(state.inMonth.map((e) => e.merchant), isNot(contains('AirAsia')));
      await bloc.close();
    },
  );

  test(
    'stepping back lands on the month before, with its own Expenses',
    () async {
      final bloc = opened(InMemoryLedgerStore(seedLedger(around: august)));
      await settled(bloc);

      bloc.add(const MonthStepped(-1));
      final state = await settled(bloc);

      expect(state.rollup.month, 7);
      expect(state.inMonth.map((e) => e.merchant), contains('AirAsia'));
      expect(
        state.inMonth.map((e) => e.merchant),
        isNot(contains('Ikea Damansara')),
      );
      await bloc.close();
    },
  );

  test(
    'a month nobody spent anything in is empty rather than an error',
    () async {
      final bloc = opened(InMemoryLedgerStore(seedLedger(around: august)));
      await settled(bloc);

      bloc.add(const MonthStepped(-4));
      final state = await settled(bloc);

      expect(state.rollup.month, 4);
      expect(state.inMonth, isEmpty);
      expect(state.rollup.hasSpending, isFalse);
      expect(state.rollup.byCategory, isEmpty);
      await bloc.close();
    },
  );

  test('the trend reaches back far enough to show a direction', () async {
    final bloc = opened(InMemoryLedgerStore(seedLedger(around: august)));
    final state = await settled(bloc);

    expect(state.trend.map((r) => (r.year, r.month)), [
      (2026, 3),
      (2026, 4),
      (2026, 5),
      (2026, 6),
      (2026, 7),
      (2026, 8),
    ]);
    await bloc.close();
  });

  test('the trend and the month on screen are the same arithmetic', () async {
    final bloc = opened(InMemoryLedgerStore(seedLedger(around: august)));
    final state = await settled(bloc);

    expect(state.trend.last.total, state.rollup.total);
    await bloc.close();
  });

  test(
    'spending in another currency is left out of the month and counted',
    () async {
      final bloc = opened(InMemoryLedgerStore(seedLedger(around: august)));
      final state = await settled(bloc);

      expect(state.rollup.excludedCount, 1);
      expect(state.rollup.excludedCurrencies, {'USD'});
      expect(
        state.rollup.total,
        isNot(state.inMonth.fold<double>(0, (sum, e) => sum + e.total)),
      );
      await bloc.close();
    },
  );

  test('there is no month after the one the Ledger opened in', () async {
    final bloc = opened(InMemoryLedgerStore(seedLedger(around: august)));

    expect((await settled(bloc)).hasLaterMonth, isFalse);

    bloc.add(const MonthStepped(-1));
    expect((await settled(bloc)).hasLaterMonth, isTrue);
    await bloc.close();
  });

  test('an empty Ledger opens on this month with nothing in it', () async {
    final bloc = opened(InMemoryLedgerStore());
    final state = await settled(bloc);

    expect(state.rollup.month, 8);
    expect(state.inMonth, isEmpty);
    expect(state.rollup.hasSpending, isFalse);
    expect(state.hasLaterMonth, isFalse);
    await bloc.close();
  });

  test('looking at a month writes nothing back to the Ledger', () async {
    final store = InMemoryLedgerStore(seedLedger(around: august));
    final before = store.contents.length;
    final bloc = opened(store);
    await settled(bloc);

    bloc.add(const MonthStepped(-1));
    await settled(bloc);

    expect(store.contents.length, before);
    expect(store.waiting, isEmpty);
    await bloc.close();
  });
}
