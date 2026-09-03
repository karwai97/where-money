import 'ledger_bloc.dart';

/// The Recaps a Ledger has been given and the ones it is still waiting on,
/// kept against the hash of the Rollup and the language that produced them. An
/// unchanged hash is an unchanged Recap, which is what makes reopening a month
/// free and the still-changing current month correct. A Recap that could not be
/// written is kept here too, so a refusal is not paid for again on every
/// rebuild.
///
/// It is its own object because reading it must never ask for anything.
/// `LedgerBloc` used to decide what to show and start paying for a Recap in the
/// same expression, inside the function that builds its state, and the only
/// thing stopping a month being bought on every rebuild was three early-returns
/// spread across two fields and two methods. That is one invariant, so it lives
/// in one place: [claim] is the only door a Model call goes through.
class Recaps {
  final Map<String, RecapState> _answers = {};
  final Set<String> _inFlight = {};

  /// What is known about [hash] without asking anybody — an answer, or
  /// [RecapPending] while one is on its way, or null when nobody has asked at
  /// all.
  RecapState? held(String hash) =>
      _answers[hash] ??
      (_inFlight.contains(hash) ? const RecapPending() : null);

  /// Takes on the asking, and answers false if the month is already answered
  /// or already being asked about. The one place that decides a Model call is
  /// going to happen, and so the one place the user's allowance is spent.
  bool claim(String hash) => !_answers.containsKey(hash) && _inFlight.add(hash);

  /// The answer, kept whether or not it is one the user wanted: a month that
  /// was asked about has been paid for either way.
  void keep(String hash, RecapState answer) {
    _inFlight.remove(hash);
    _answers[hash] = answer;
  }

  /// Lets go of a month, so that the next look at it asks again. The user
  /// asking for a Recap the Model would not write is the only caller.
  void forget(String hash) {
    _inFlight.remove(hash);
    _answers.remove(hash);
  }
}
