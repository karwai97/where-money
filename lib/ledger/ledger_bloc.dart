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
  const LedgerReady(this.expenses);

  final List<Expense> expenses;

  @override
  List<Object?> get props => [expenses];
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
    on<_LedgerChanged>((event, emit) => emit(LedgerReady(event.expenses)));
    on<_LedgerFailed>((event, emit) => emit(LedgerUnavailable(event.reason)));
  }

  final LedgerStore _store;
  StreamSubscription<List<Expense>>? _watching;

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
