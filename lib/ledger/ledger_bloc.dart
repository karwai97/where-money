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

/// A month named outright rather than stepped to — the user tapping a bar in
/// the trend. Absolute because that is what the tap means: the bar knows which
/// month it drew, and making the screen subtract that from the month on screen
/// would put calendar arithmetic in a widget to reach an event that then has
/// to add it back.
final class MonthPicked extends LedgerEvent {
  const MonthPicked(this.year, this.month);

  final int year;
  final int month;

  @override
  List<Object?> get props => [year, month];
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

/// The Home Currency arrived, either learned from the first Expense or chosen
/// in Settings. Carried the same way [LanguageChanged] is, and for the same
/// reason: re-keying the bloc would throw away a loaded Ledger because a
/// preference moved.
final class HomeCurrencyChanged extends LedgerEvent {
  const HomeCurrencyChanged(this.currency);

  final String currency;

  @override
  List<Object?> get props => [currency];
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

  /// The whole Ledger, newest first, and empty on a state that has not read
  /// one. Here rather than on the two states that hold it so that a reader
  /// wanting only the Expenses does not have to know which of them it has.
  List<Expense> get expenses => const [];

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
    required this.opened,
    required this.recap,
  });

  /// The whole Ledger, newest first. The month on screen is [inMonth].
  @override
  final List<Expense> expenses;

  /// The month the user is looking at. Computed here and nowhere else, so the
  /// charts, the list and — later — the Recap cannot disagree.
  final Rollup rollup;

  /// Six months around [rollup], oldest first and always including it —
  /// months after it too, wherever there are any, because tapping a column is
  /// how the reader moves and a window that stopped at [rollup] only went back.
  final List<Rollup> trend;

  /// The first of the month the app was opened in: the ceiling nothing can
  /// move past, and so which months a reader is offered. Carried rather than
  /// read off the end of [trend], which is not the same thing — the window
  /// stops short of the opened month wherever the reader has walked back.
  final DateTime opened;

  /// The same month said in words, or why it is not.
  final RecapState recap;

  List<Expense> get inMonth =>
      expensesIn(expenses, year: rollup.year, month: rollup.month);

  @override
  List<Object?> get props => [
    expenses,
    rollup.year,
    rollup.month,
    // The axis the month was computed on. Without it a Home Currency changed
    // in Settings recomputes an identical-looking state that Equatable then
    // swallows, and the charts stay in the old currency.
    rollup.homeCurrency,
    // Where the trend window sits. The same month can be reached with the
    // window in two places, and without this Equatable swallows the second of
    // them — leaving the header's bars showing months the reader has walked
    // away from.
    trend.last.year,
    trend.last.month,
    opened,
    recap,
  ];
}

/// The Ledger is readable and there is no Home Currency to aggregate it in
/// yet, so there is no Rollup and nothing has been asked of the Model. A phase
/// of the interface rather than a shape of the domain: it ends at the first
/// commit, and nothing below this file knows it exists (ADR-0009).
final class LedgerWithoutHomeCurrency extends LedgerState {
  const LedgerWithoutHomeCurrency(this.expenses);

  /// Ordinarily empty. Not always: a Ledger restored onto a new phone arrives
  /// full with the preference unset, and this is what it is learned from.
  @override
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
  LedgerBloc(
    this._store,
    this._model, {
    DateTime? now,
    this._language = defaultLanguage,
    this._homeCurrency,
  }) : _opened = _firstOf(now ?? DateTime.now()),
       super(const LedgerLoading()) {
    _month = _opened;
    _windowEnd = _opened;
    on<LedgerOpened>(_onOpened);
    on<MonthPicked>(_onPicked);
    on<RecapAskedAgain>(_onAskedAgain);
    on<LanguageChanged>(_onLanguageChanged);
    on<HomeCurrencyChanged>(_onHomeCurrencyChanged);
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

  /// The currency every Rollup here is computed in, or null until the app has
  /// been told one. Read off the phone before the first frame like the theme
  /// and the language, and kept up to date through [HomeCurrencyChanged].
  String? _homeCurrency;

  /// The month the app was opened in, which is as far forward as there is
  /// anything to see.
  final DateTime _opened;

  late DateTime _month;

  /// The newest month the trend draws. Held apart from [_month] because the
  /// trend is the only way through the months: a window that always ended at
  /// the month on screen put that month against the right-hand edge, and a
  /// reader who stepped back then had nothing on screen leading forward again.
  late DateTime _windowEnd;

  List<Expense> _expenses = const [];
  StreamSubscription<List<Expense>>? _watching;

  final Recaps _recaps = Recaps();

  void _onPicked(MonthPicked event, Emitter<LedgerState> emit) {
    _moveMonthTo(DateTime(event.year, event.month), emit);
  }

  /// The one place the month on screen moves, so the ceiling at [_opened] is
  /// stated once and holds however the user got there.
  void _moveMonthTo(DateTime month, Emitter<LedgerState> emit) {
    _month = month.isAfter(_opened) ? _opened : month;
    _windowEnd = _windowEndingFor(_month);
    if (state is LedgerReady) _show(emit);
  }

  /// Where the trend should end for a month, given where it ends now.
  ///
  /// The rule is one line: the month on screen never sits on an edge of the
  /// window unless there is nothing past that edge. So a month picked from
  /// inside the window leaves the window where it is, and one picked off
  /// either end slides it by just enough to keep a month showing beyond —
  /// which is what makes the trend a way forward as well as back. The ceiling
  /// at [_opened] is the one edge allowed to hold the month against it: there
  /// is no spending to look at after today.
  DateTime _windowEndingFor(DateTime month) {
    final start = DateTime(_windowEnd.year, _windowEnd.month - trendMonths + 1);
    final end = switch (month) {
      _ when !month.isAfter(start) => DateTime(
        month.year,
        month.month + trendMonths - 2,
      ),
      _ when !month.isBefore(_windowEnd) => DateTime(
        month.year,
        month.month + 1,
      ),
      _ => _windowEnd,
    };

    return end.isAfter(_opened) ? _opened : end;
  }

  /// The month on screen, and then whatever it still needs. The two halves are
  /// two statements on purpose: building a [LedgerReady] costs nothing and
  /// starts nothing, and this is the only place a month gets paid for.
  void _show(Emitter<LedgerState> emit) {
    final home = _homeCurrency;
    // Nothing is aggregated and nothing is asked for until the app knows what
    // this Ledger's money is. Asking the Model to write up a month computed on
    // a currency nobody chose would be paying for a guess.
    if (home == null) {
      emit(LedgerWithoutHomeCurrency(_expenses));
      return;
    }

    final ready = _ready(home);
    emit(ready);
    _wantRecap(ready.rollup);
  }

  LedgerReady _ready(String homeCurrency) {
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
        year: _windowEnd.year,
        month: _windowEnd.month,
        months: trendMonths,
        homeCurrency: homeCurrency,
      ),
      opened: _opened,
      recap: _recapFor(rollup),
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

  /// The charts are recomputed and the Recaps re-key themselves: [rollupHash]
  /// already hashes the currency, so a month written up in the old one is
  /// still held under its own key and the new one simply misses.
  void _onHomeCurrencyChanged(
    HomeCurrencyChanged event,
    Emitter<LedgerState> emit,
  ) {
    if (event.currency == _homeCurrency) return;
    _homeCurrency = event.currency;
    if (state is! LedgerLoading && state is! LedgerUnavailable) _show(emit);
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

/// What a Ledger teaches the app its money is: the oldest Expense carrying a
/// code the app knows, or null when there is nothing to learn from. A code the
/// app cannot place is no basis for an aggregation axis — an Expense committed
/// as `???` would leave every Rollup empty for good.
///
/// Read in two places, which is why it is one function: the listener that
/// learns it, and the Settings row that says a Home Currency came from there.
String? learnableCurrency(List<Expense> expenses) => expenses.reversed
    .map((expense) => expense.currency)
    .where(isoCurrencies.contains)
    .firstOrNull;

/// Enough months for a direction to be visible without the bars turning into
/// a stripe on a phone.
const int trendMonths = 6;
