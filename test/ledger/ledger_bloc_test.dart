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
    expect: () => [const LedgerReady(expenses: [])],
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

  blocTest<LedgerBloc, LedgerState>(
    'an Expense written to the store appears in the Ledger',
    build: () => LedgerBloc(InMemoryLedgerStore()),
    act: (bloc) async {
      bloc.add(const LedgerOpened());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const DebugExpenseWritten());
    },
    skip: 1,
    expect: () => [
      isA<LedgerReady>().having(
        (state) => state.expenses.single.merchant,
        'the one Expense',
        'Village Grocer Bangsar',
      ),
    ],
  );

  test('the debug Expense is a real Expense, not a placeholder', () async {
    final store = InMemoryLedgerStore();
    final bloc = LedgerBloc(store)..add(const LedgerOpened());
    await Future<void>.delayed(Duration.zero);

    bloc.add(const DebugExpenseWritten());
    await Future<void>.delayed(Duration.zero);

    final written = store.contents.single;
    expect(written.total, 44.10);
    expect(written.currency, 'MYR');
    expect(written.category, 'groceries');
    expect(written.lineItems, hasLength(4));
    expect(written.needsReview, isFalse);
    await bloc.close();
  });

  test('two debug taps write two Expenses, not one overwritten twice', () async {
    final store = InMemoryLedgerStore();
    final bloc = LedgerBloc(store)..add(const LedgerOpened());
    await Future<void>.delayed(Duration.zero);

    bloc.add(const DebugExpenseWritten());
    await Future<void>.delayed(Duration.zero);
    bloc.add(const DebugExpenseWritten());
    await Future<void>.delayed(Duration.zero);

    expect(store.contents, hasLength(2));
    expect(
      store.contents.map((expense) => expense.id).toSet(),
      hasLength(2),
      reason: 'each write needs its own document id',
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

  blocTest<LedgerBloc, LedgerState>(
    'a refused write is reported, and the Ledger stays on screen',
    build: () => LedgerBloc(
      InMemoryLedgerStore(august)..refuseWrites = StateError('denied'),
    ),
    act: (bloc) async {
      bloc.add(const LedgerOpened());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const DebugExpenseWritten());
    },
    skip: 1,
    expect: () => [
      isA<LedgerReady>()
          .having((state) => state.refusal, 'refusal', isNotNull)
          .having((state) => state.expenses, 'expenses', hasLength(august.length)),
    ],
  );
}
