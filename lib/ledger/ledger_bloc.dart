import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../data/ledger_store.dart';
import '../scan/model_gateway.dart';

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

/// The user asking for a Recap the Model could not write the first time. The
/// only way one is ever asked for twice: an answer, including a refusal, is
/// cached against the Rollup that produced it, so nothing else re-asks.
final class RecapAskedAgain extends LedgerEvent {
  const RecapAskedAgain();
}

final class _RecapWanted extends LedgerEvent {
  const _RecapWanted(this.hash, this.prompt);

  final String hash;
  final String prompt;

  @override
  List<Object?> get props => [hash];
}

/// Confirmed on screen before it gets here.
final class ExpenseDeleted extends LedgerEvent {
  const ExpenseDeleted(this.expenseId);

  final String expenseId;

  @override
  List<Object?> get props => [expenseId];
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

/// Where the month's Recap has got to. A Recap is a pure function of a Rollup,
/// so which of these the month is in follows from the Rollup and from nothing
/// else — there is no staleness to remember because there is nowhere for it to
/// hide.
sealed class RecapState extends Equatable {
  const RecapState();

  @override
  List<Object?> get props => const [];
}

/// The Model has been asked and has not answered yet.
final class RecapPending extends RecapState {
  const RecapPending();
}

final class RecapOnScreen extends RecapState {
  const RecapOnScreen(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// Too little spending to say anything about. Nothing is asked and nothing is
/// spent: the app does not ask a Model to find meaning in three receipts.
final class RecapTooFewExpenses extends RecapState {
  const RecapTooFewExpenses(this.needed);

  final int needed;

  @override
  List<Object?> get props => [needed];
}

/// The month has no Recap and the charts are unaffected. [why] is the Model's
/// answer or the reason nothing got through, in the user's words.
final class RecapUnavailable extends RecapState {
  const RecapUnavailable(this.why);

  final String why;

  @override
  List<Object?> get props => [why];
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
    required this.recap,
    required this.hasLaterMonth,
  });

  /// The whole Ledger, newest first. The month on screen is [inMonth].
  final List<Expense> expenses;

  /// The month the user is looking at. Computed here and nowhere else, so the
  /// charts, the list and — later — the Recap cannot disagree.
  final Rollup rollup;

  /// The months leading up to [rollup], oldest first and including it.
  final List<Rollup> trend;

  /// The same month said in words, or why it is not.
  final RecapState recap;

  /// False in the month the Ledger opened in: there is no spending to look at
  /// after today.
  final bool hasLaterMonth;

  List<Expense> get inMonth =>
      expensesIn(expenses, year: rollup.year, month: rollup.month);

  @override
  List<Object?> get props => [expenses, rollup.year, rollup.month, recap];
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
  LedgerBloc(this._store, this._model, {DateTime? now})
    : _opened = _firstOf(now ?? DateTime.now()),
      super(const LedgerLoading()) {
    _month = _opened;
    on<LedgerOpened>(_onOpened);
    on<MonthStepped>(_onStepped);
    on<RecapAskedAgain>(_onAskedAgain);
    on<ExpenseDeleted>(_onDeleted);
    on<_RecapWanted>(_onRecapWanted);
    on<_LedgerChanged>((event, emit) {
      _expenses = event.expenses;
      emit(_ready());
    });
    on<_LedgerFailed>((event, emit) => emit(LedgerUnavailable(event.reason)));
  }

  final LedgerStore _store;

  /// The Worker, for the one thing on this screen that is not arithmetic.
  final ModelGateway _model;

  /// The month the app was opened in, which is as far forward as there is
  /// anything to see.
  final DateTime _opened;

  late DateTime _month;
  List<Expense> _expenses = const [];
  StreamSubscription<List<Expense>>? _watching;

  /// Answers, kept against the hash of the Rollup that produced them. An
  /// unchanged hash is an unchanged Recap, which is what makes reopening a
  /// month free and the still-changing current month correct. A Recap that
  /// could not be written is kept here too, so a refusal is not paid for again
  /// on every rebuild.
  final Map<String, RecapState> _recaps = {};
  final Set<String> _asking = {};

  void _onStepped(MonthStepped event, Emitter<LedgerState> emit) {
    _month = DateTime(_month.year, _month.month + event.by);
    if (_month.isAfter(_opened)) _month = _opened;
    if (state is LedgerReady) emit(_ready());
  }

  LedgerReady _ready() {
    final rollup = Rollup.forMonth(
      _expenses,
      year: _month.year,
      month: _month.month,
      homeCurrency: homeCurrency,
    );

    return LedgerReady(
      _expenses,
      rollup: rollup,
      trend: Rollup.trailing(
        _expenses,
        year: _month.year,
        month: _month.month,
        months: trendMonths,
        homeCurrency: homeCurrency,
      ),
      recap: _recapFor(rollup),
      hasLaterMonth: _month.isBefore(_opened),
    );
  }

  RecapState _recapFor(Rollup rollup) {
    if (rollup.expenseCount < minimumExpensesForRecap) {
      return const RecapTooFewExpenses(minimumExpensesForRecap);
    }

    final hash = rollupHash(rollup);
    final held = _recaps[hash];
    if (held != null) return held;

    add(_RecapWanted(hash, jsonEncode(rollupPrompt(rollup))));
    return const RecapPending();
  }

  Future<void> _onRecapWanted(
    _RecapWanted event,
    Emitter<LedgerState> emit,
  ) async {
    if (_recaps.containsKey(event.hash) || !_asking.add(event.hash)) return;

    final answer = await _model.recap(event.prompt);
    _asking.remove(event.hash);
    _recaps[event.hash] = _recapFrom(answer);
    // The user can leave the screen while the Model is still writing, and a
    // Recap that arrives after that has nowhere to go.
    if (emit.isDone || state is! LedgerReady) return;
    emit(_ready());
  }

  /// A refused delete needs no words of its own: the list is a live stream, so
  /// an Expense that did not go is still sitting in it, which is both true and
  /// the whole of what the user needs to know.
  Future<void> _onDeleted(
    ExpenseDeleted event,
    Emitter<LedgerState> emit,
  ) async {
    try {
      await _store.remove(event.expenseId);
    } on Object catch (_) {
      return;
    }
  }

  void _onAskedAgain(RecapAskedAgain event, Emitter<LedgerState> emit) {
    if (state case final LedgerReady ready
        when ready.recap is RecapUnavailable) {
      _recaps.remove(rollupHash(ready.rollup));
      emit(_ready());
    }
  }

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

/// The Model's answer as the screen has to render it. A Recap the Model would
/// not write is not a Failure in this project's sense — nothing is stuck and
/// nothing needs retrying on a schedule — so the charts carry on and the words
/// say why they are missing.
RecapState _recapFrom(RecapAnswer answer) => switch (answer) {
  RecapAnswered(outcome: RecapWritten(:final text)) => RecapOnScreen(text),
  RecapAnswered(outcome: RecapRefused()) => const RecapUnavailable(
    'The Model would not write up this month.',
  ),
  RecapAnswered(outcome: RecapNoOutput()) => const RecapUnavailable(
    'The Model had nothing to say about this month.',
  ),
  AllowanceSpent() => const RecapUnavailable(
    "That is today's allowance. There will be a Recap tomorrow.",
  ),
  TokenRefused() => const RecapUnavailable(
    'Sign in again and the Recap will come back.',
  ),
  ModelOutOfReach() => const RecapUnavailable(
    'No Recap without a connection. The charts do not need one.',
  ),
  ModelUnavailable() => const RecapUnavailable(
    'The Model could not be reached. The charts do not need it.',
  ),
};

DateTime _firstOf(DateTime at) => DateTime(at.year, at.month);

/// The currency the Rollup aggregates in. Everything else is stored faithfully
/// and left out of the totals, with the count shown (ADR-0006). There is no
/// settings screen yet, so this is one constant in one place rather than a
/// preference the user can move.
const String homeCurrency = 'MYR';

/// Enough months for a direction to be visible without the bars turning into
/// a stripe on a phone.
const int trendMonths = 6;
