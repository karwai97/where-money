import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/ledger/ledger_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/in_memory_ledger_store.dart';

void main() {
  final august = seedLedger(around: DateTime(2026, 8, 23));

  blocTest<LedgerBloc, LedgerState>(
    'opening an empty Ledger settles on nothing rather than on a spinner',
    build: () => LedgerBloc(InMemoryLedgerStore()),
    act: (bloc) => bloc.add(const LedgerOpened()),
    expect: () => [const LedgerReady([])],
  );

  blocTest<LedgerBloc, LedgerState>(
    'an existing Ledger arrives newest first',
    build: () => LedgerBloc(InMemoryLedgerStore(august)),
    act: (bloc) => bloc.add(const LedgerOpened()),
    verify: (bloc) {
      final expenses = (bloc.state as LedgerReady).expenses;
      expect(expenses, hasLength(august.length));
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
    final bloc = LedgerBloc(store)..add(const LedgerOpened());
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
    build: () =>
        LedgerBloc(InMemoryLedgerStore()..refuseReads = StateError('denied')),
    act: (bloc) => bloc.add(const LedgerOpened()),
    expect: () => [isA<LedgerUnavailable>()],
  );
}
