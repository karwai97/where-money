import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../data/ledger_store.dart';

sealed class LedgerEvent extends Equatable {
  const LedgerEvent();

  @override
  List<Object?> get props => const [];
}

final class LedgerOpened extends LedgerEvent {
  const LedgerOpened();
}

final class MonthStepped extends LedgerEvent {
  const MonthStepped(this.by);

  final int by;

  @override
  List<Object?> get props => [by];
}

final class _LedgerChanged extends LedgerEvent {
  const _LedgerChanged(this.expenses);

  final List<Expense> expenses;

  @override
  List<Object?> get props => [expenses];
}

final class _LedgerFailed extends LedgerEvent {
  const _LedgerFailed(this.reason);

  final String reason;

  @override
  List<Object?> get props => [reason];
}

sealed class LedgerState extends Equatable {
  const LedgerState();

  @override
  List<Object?> get props => const [];
}

final class LedgerLoading extends LedgerState {
  const LedgerLoading();
}

final class LedgerReady extends LedgerState {
  const LedgerReady(
    this.expenses, {
    required this.rollup,
    required this.trend,
    required this.hasLaterMonth,
  });

  /// The whole Ledger, newest first. The month on screen is [inMonth].
  final List<Expense> expenses;

  /// The month the user is looking at. Computed here and nowhere else, so the
  /// charts, the list and — later — the Recap cannot disagree.
  final Rollup rollup;

  /// The months leading up to [rollup], oldest first and including it.
  final List<Rollup> trend;

  /// False in the month the Ledger opened in: there is no spending to look at
  /// after today.
  final bool hasLaterMonth;

  List<Expense> get inMonth =>
      expensesIn(expenses, year: rollup.year, month: rollup.month);

  @override
  List<Object?> get props => [expenses, rollup.year, rollup.month];
}

/// The Ledger could not be read at all, which on a signed-in user means the
/// rules said no.
final class LedgerUnavailable extends LedgerState {
  const LedgerUnavailable(this.reason);

  final String reason;

  @override
  List<Object?> get props => [reason];
}

class LedgerBloc extends Bloc<LedgerEvent, LedgerState> {
  LedgerBloc(this._store, {DateTime? now})
    : _opened = _firstOf(now ?? DateTime.now()),
       super(const LedgerLoading()) {
    _month = _opened;
    on<LedgerOpened>(_onOpened);
    on<MonthStepped>(_onStepped);
    on<_LedgerChanged>((event, emit) {
      _expenses = event.expenses;
      emit(_ready());
    });
    on<_LedgerFailed>((event, emit) => emit(LedgerUnavailable(event.reason)));
  }

  final LedgerStore _store;

  /// The month the app was opened in, which is as far forward as there is
  /// anything to see.
  final DateTime _opened;

  late DateTime _month;
  List<Expense> _expenses = const [];
  StreamSubscription<List<Expense>>? _watching;

  void _onStepped(MonthStepped event, Emitter<LedgerState> emit) {
    _month = DateTime(_month.year, _month.month + event.by);
    if (_month.isAfter(_opened)) _month = _opened;
    if (state is LedgerReady) emit(_ready());
  }

  LedgerReady _ready() => LedgerReady(
    _expenses,
    rollup: Rollup.forMonth(
      _expenses,
      year: _month.year,
      month: _month.month,
      homeCurrency: homeCurrency,
    ),
    trend: Rollup.trailing(
      _expenses,
      year: _month.year,
      month: _month.month,
      months: trendMonths,
      homeCurrency: homeCurrency,
    ),
    hasLaterMonth: _month.isBefore(_opened),
  );

  void _onOpened(LedgerOpened event, Emitter<LedgerState> emit) {
    _watching?.cancel();
    _watching = _store.ledger().listen(
      (expenses) => add(_LedgerChanged(expenses)),
      onError: (Object error) => add(_LedgerFailed(error.toString())),
    );
  }

  @override
  Future<void> close() {
    _watching?.cancel();
    return super.close();
  }
}

DateTime _firstOf(DateTime at) => DateTime(at.year, at.month);

/// The currency the Rollup aggregates in. Everything else is stored faithfully
/// and left out of the totals, with the count shown (ADR-0006). There is no
/// settings screen yet, so this is one constant in one place rather than a
/// preference the user can move.
const String homeCurrency = 'MYR';

/// Enough months for a direction to be visible without the bars turning into
/// a stripe on a phone.
const int trendMonths = 6;
