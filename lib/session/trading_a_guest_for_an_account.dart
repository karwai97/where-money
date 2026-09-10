/// A guest's two exits, and the sequencing each one needs: keeping the Ledger
/// by putting a Google account behind it, or leaving and taking it with them.
///
/// A cubit rather than events on [SessionBloc], for two reasons that are not
/// preferences. The bloc's `SigningIn` state routes the app to the sign-in
/// screen, so any in-flight state expressed there would unmount Settings
/// mid-flow; and the collision path has to stop and ask the user which Ledger
/// they are keeping, which a bloc cannot do — it cannot await a dialog. Here
/// the whole of each flow reads top to bottom in one method.
///
/// It tells [SessionBloc] nothing. Identity changes reach it on their own,
/// through the gateway's stream.
library;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/erasing_a_ledger.dart';
import 'sign_in_gateway.dart';

sealed class Trade extends Equatable {
  const Trade();

  @override
  List<Object?> get props => const [];
}

final class NoTrade extends Trade {
  const NoTrade();
}

/// A link or an erasure is in flight. What the screen draws for this differs
/// between the two — a spinner in the row for one, a modal over the screen
/// for the other — which is the screen's business rather than this one's.
final class TradeUnderWay extends Trade {
  const TradeUnderWay();
}

final class TradeRefused extends Trade {
  const TradeRefused(this.detail);

  /// What the phone said, transcribed. Never truncated: it is the only thing
  /// the user has to go on.
  final String detail;

  @override
  List<Object?> get props => [detail];
}

/// Asked when the account a guest chose is already somebody. Answering true
/// keeps that account's Ledger and deletes this one.
typedef AsksAboutTheOtherLedger = Future<bool> Function();

class TradingAGuestForAnAccount extends Cubit<Trade> {
  TradingAGuestForAnAccount({required this.identity, required this.erases})
    : super(const NoTrade());

  final SignInGateway identity;
  final ErasesFor erases;

  /// Keeping the Ledger. The uid does not change, so nothing moves: the same
  /// documents have an account behind them afterwards.
  ///
  /// [askAboutTheOtherLedger] is only reached when the chosen account already
  /// has a Ledger of its own. Nothing is deleted before it answers.
  Future<void> keep(
    String uid,
    AsksAboutTheOtherLedger askAboutTheOtherLedger,
  ) async {
    emit(const TradeUnderWay());
    try {
      await identity.linkWithGoogle();
      // Kept. The row goes when the gateway's stream says this uid is no
      // longer a guest; nothing further to do here.
      emit(const NoTrade());
    } on SignInAbandoned {
      // The user closed the picker. They know.
      emit(const NoTrade());
    } on AccountAlreadyHasALedger catch (collision) {
      await _theOtherLedger(uid, collision.credential, askAboutTheOtherLedger);
    } catch (error) {
      emit(TradeRefused(error.toString()));
    }
  }

  /// Leaving, which for a guest is the end of the account: the uid is
  /// unrecoverable, so a Ledger left behind is one nobody can ever reach
  /// (ADR-0010).
  ///
  /// The caller confirms first. This does not ask, because the two callers
  /// ask different questions.
  Future<void> leave(String uid) async {
    emit(const TradeUnderWay());
    try {
      await erases(uid).erase();
      emit(const NoTrade());
    } catch (error) {
      // Still signed in, and told. Anything else would break the promise the
      // dialog made and take away the only identity that could try again.
      emit(TradeRefused(error.toString()));
    }
  }

  /// Two Ledgers and one user. The guest's goes, and the account they chose
  /// is signed into with the credential the refusal carried — so they are not
  /// asked to pick the same account twice.
  Future<void> _theOtherLedger(
    String uid,
    Object credential,
    AsksAboutTheOtherLedger asks,
  ) async {
    if (!await asks()) {
      // Reading a warning is free: still a guest, Ledger untouched.
      emit(const NoTrade());
      return;
    }

    try {
      await erases(uid).erase();
      await identity.signInWith(credential);
      emit(const NoTrade());
    } catch (error) {
      emit(TradeRefused(error.toString()));
    }
  }
}
