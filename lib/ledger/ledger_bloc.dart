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

/// The debug affordance that stands in for the camera until ticket 04 exists.
final class DebugExpenseWritten extends LedgerEvent {
  const DebugExpenseWritten();
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
  const LedgerReady({required this.expenses, this.refusal});

  final List<Expense> expenses;

  /// Set when the last write was turned away — by the security rules, or by a
  /// network that was not there. The Ledger itself is still on screen.
  final String? refusal;

  @override
  List<Object?> get props => [expenses, refusal];
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
  LedgerBloc(this._store) : super(const LedgerLoading()) {
    on<LedgerOpened>(_onOpened);
    on<DebugExpenseWritten>(_onDebugExpenseWritten);
    on<_LedgerChanged>(
      (event, emit) => emit(LedgerReady(expenses: event.expenses)),
    );
    on<_LedgerFailed>((event, emit) => emit(LedgerUnavailable(event.reason)));
  }

  final LedgerStore _store;
  StreamSubscription<List<Expense>>? _watching;
  var _written = 0;

  void _onOpened(LedgerOpened event, Emitter<LedgerState> emit) {
    _watching?.cancel();
    _watching = _store.ledger().listen(
      (expenses) => add(_LedgerChanged(expenses)),
      onError: (Object error) => add(_LedgerFailed(error.toString())),
    );
  }

  Future<void> _onDebugExpenseWritten(
    DebugExpenseWritten event,
    Emitter<LedgerState> emit,
  ) async {
    _written++;
    try {
      await _store.add(
        Expense.fromExtraction(
          cleanExtraction,
          id: 'debug-${DateTime.now().microsecondsSinceEpoch}-$_written',
          now: fixtureNow,
        ),
      );
    } catch (error) {
      final current = state;
      emit(
        LedgerReady(
          expenses: current is LedgerReady ? current.expenses : const [],
          refusal: error.toString(),
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _watching?.cancel();
    return super.close();
  }
}
