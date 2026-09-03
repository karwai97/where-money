import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../data/ledger_store.dart';
import '../scan/model_gateway.dart';
import 'recaps.dart';

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
  const _RecapWanted(this.hash, this.prompt, this.language);

  final String hash;
  final String prompt;

  /// Carried rather than read off the bloc when the answer comes back: the
  /// user can change language while the Model is writing, and the answer
  /// belongs to the hash that asked for it.
  final String language;

  @override
  List<Object?> get props => [hash];
}

/// The user picked a language in Settings. Carries the tag rather than
/// re-keying the bloc: re-keying would throw away a loaded Ledger and fetch it
/// again over the network because somebody changed a UI preference. This way
/// the hash simply misses, one Recap is paid for, and the old one is still held
/// under its own key — so switching twice costs nothing.
final class LanguageChanged extends LedgerEvent {
  const LanguageChanged(this.language);

  final String language;

  @override
  List<Object?> get props => [language];
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

/// Where the month's Recap has got to. A Recap is a pure function of a Rollup
/// and the Language it was asked for in, so which of these the month is in
/// follows from those two and from nothing else — there is no staleness to
/// remember because there is nowhere for it to hide.
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

/// Why a month has no Recap. A kind rather than a sentence, so the words for
/// it are assembled on the screen that shows them and this file stays wordless
/// (ADR-0007) — which is also what lets the reason be read in the language the
/// interface is in rather than the one the Recap was asked for.
enum WhyNoRecap {
  /// The Model read the month and declined to write it up.
  refused,

  /// The Model answered and the answer had no prose in it — reasoning that ate
  /// the whole output budget.
  nothingToSay,

  allowanceSpent,
  tokenRefused,
  outOfReach,
  modelUnavailable,
}

/// The month has no Recap and the charts are unaffected.
final class RecapUnavailable extends RecapState {
  const RecapUnavailable(this.why);

  final WhyNoRecap why;

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
  LedgerBloc(
    this._store,
    this._model, {
    DateTime? now,
    this._language = defaultLanguage,
  }) : _opened = _firstOf(now ?? DateTime.now()),
       super(const LedgerLoading()) {
    _month = _opened;
    on<LedgerOpened>(_onOpened);
    on<MonthStepped>(_onStepped);
    on<RecapAskedAgain>(_onAskedAgain);
    on<LanguageChanged>(_onLanguageChanged);
    on<ExpenseDeleted>(_onDeleted);
    on<_RecapWanted>(_onRecapWanted);
    on<_LedgerChanged>((event, emit) {
      _expenses = event.expenses;
      _show(emit);
    });
    on<_LedgerFailed>((event, emit) => emit(LedgerUnavailable(event.reason)));
  }

  final LedgerStore _store;

  /// The Worker, for the one thing on this screen that is not arithmetic.
  final ModelGateway _model;

  /// The language the Recap is written in, which the Setting keeps up to date
  /// through [LanguageChanged]. The constructor takes the one the app opened in
  /// so the first Recap is not asked for in English and then replaced.
  String _language;

  /// The month the app was opened in, which is as far forward as there is
  /// anything to see.
  final DateTime _opened;

  late DateTime _month;
  List<Expense> _expenses = const [];
  StreamSubscription<List<Expense>>? _watching;

  final Recaps _recaps = Recaps();

  void _onStepped(MonthStepped event, Emitter<LedgerState> emit) {
    _month = DateTime(_month.year, _month.month + event.by);
    if (_month.isAfter(_opened)) _month = _opened;
    if (state is LedgerReady) _show(emit);
  }

  /// The month on screen, and then whatever it still needs. The two halves are
  /// two statements on purpose: building a [LedgerReady] costs nothing and
  /// starts nothing, and this is the only place a month gets paid for.
  void _show(Emitter<LedgerState> emit) {
    final ready = _ready();
    emit(ready);
    _wantRecap(ready.rollup);
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

  /// What the month has to say for itself, asking nothing. A month nobody has
  /// asked about yet reads as pending because [_wantRecap] is about to ask —
  /// which is true of every path here, because [_show] is the only way a
  /// [LedgerReady] reaches the screen.
  RecapState _recapFor(Rollup rollup) {
    if (rollup.expenseCount < minimumExpensesForRecap) {
      return const RecapTooFewExpenses(minimumExpensesForRecap);
    }

    return _recaps.held(rollupHash(rollup, language: _language)) ??
        const RecapPending();
  }

  /// Asks for anything the month on screen still needs. Cheap and idempotent:
  /// the event is only the request, and [Recaps.claim] is what decides whether
  /// a Model is actually called.
  void _wantRecap(Rollup rollup) {
    if (rollup.expenseCount < minimumExpensesForRecap) return;

    final hash = rollupHash(rollup, language: _language);
    if (_recaps.held(hash) != null) return;

    add(_RecapWanted(hash, jsonEncode(rollupPrompt(rollup)), _language));
  }

  Future<void> _onRecapWanted(
    _RecapWanted event,
    Emitter<LedgerState> emit,
  ) async {
    if (!_recaps.claim(event.hash)) return;

    _recaps.keep(event.hash, await _answerTo(event));
    // The user can leave the screen while the Model is still writing, and a
    // Recap that arrives after that has nowhere to go.
    if (emit.isDone || state is! LedgerReady) return;
    _show(emit);
  }

  /// What the Model had to say, including when it says it by throwing. The
  /// gateway promises a typed answer for every failure it knows about, and a
  /// caller that trusts that absolutely is a caller that hangs: the real one
  /// fetches an ID token before its own `try`, and Firebase throws there on a
  /// dead connection or a revoked token. A month claimed and never answered
  /// sits on a spinner nothing can clear, because [RecapAskedAgain] only acts
  /// on a month that failed out loud.
  Future<RecapState> _answerTo(_RecapWanted event) async {
    final RecapAnswer answer;
    try {
      answer = await _model.recap(event.prompt, language: event.language);
    } on Object catch (_) {
      return const RecapUnavailable(WhyNoRecap.modelUnavailable);
    }

    // Outside the `try` on purpose. Reading an answer wrong is this app's
    // mistake, and dressing it up as the far end's would hand the user a
    // retry that fails the same way every time.
    return _recapFrom(answer);
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

  /// Nothing here touches the Ledger stream. The hash misses, `_show` asks for
  /// one Recap in the new language, and the old one stays in [_recaps] under
  /// the key it was paid for.
  void _onLanguageChanged(LanguageChanged event, Emitter<LedgerState> emit) {
    if (event.language == _language) return;
    _language = event.language;
    if (state is LedgerReady) _show(emit);
  }

  void _onAskedAgain(RecapAskedAgain event, Emitter<LedgerState> emit) {
    if (state case final LedgerReady ready
        when ready.recap is RecapUnavailable) {
      _recaps.forget(rollupHash(ready.rollup, language: _language));
      _show(emit);
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
/// nothing needs retrying on a schedule — so the charts carry on and the screen
/// says why the words are missing.
RecapState _recapFrom(RecapAnswer answer) => switch (answer) {
  RecapAnswered(outcome: RecapWritten(:final text)) => RecapOnScreen(text),
  RecapAnswered(outcome: RecapRefused()) => const RecapUnavailable(
    WhyNoRecap.refused,
  ),
  RecapAnswered(outcome: RecapNoOutput()) => const RecapUnavailable(
    WhyNoRecap.nothingToSay,
  ),
  AllowanceSpent() => const RecapUnavailable(WhyNoRecap.allowanceSpent),
  TokenRefused() => const RecapUnavailable(WhyNoRecap.tokenRefused),
  ModelOutOfReach() => const RecapUnavailable(WhyNoRecap.outOfReach),
  ModelUnavailable() => const RecapUnavailable(WhyNoRecap.modelUnavailable),
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
