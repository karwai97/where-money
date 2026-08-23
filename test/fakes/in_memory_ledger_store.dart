import 'dart:async';

import 'package:where_money/data/ledger_store.dart';
import 'package:where_money_core/where_money_core.dart';

/// The LedgerStore seam's fake: one of the two things this project fakes.
class InMemoryLedgerStore implements LedgerStore {
  InMemoryLedgerStore([List<Expense> initial = const []])
    : _expenses = [...initial];

  final List<Expense> _expenses;
  final _changes = StreamController<List<Expense>>.broadcast();

  /// Set either of these to have the store refuse, standing in for a rules
  /// refusal or a dead network.
  Object? refuseReads;
  Object? refuseWrites;

  @override
  Stream<List<Expense>> ledger() async* {
    if (refuseReads case final failure?) throw failure;
    yield _newestFirst;
    yield* _changes.stream;
  }

  @override
  Future<void> add(Expense expense) async {
    if (refuseWrites case final failure?) throw failure;
    _expenses.add(expense);
    _changes.add(_newestFirst);
  }

  List<Expense> get contents => _newestFirst;

  List<Expense> get _newestFirst =>
      [..._expenses]..sort((a, b) => b.date.compareTo(a.date));
}
