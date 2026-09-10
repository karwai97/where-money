/// Identity, and nothing more. The domain wants a uid out of signing in; the
/// name and the email are here only so the app can say who is signed in.
library;

import 'package:equatable/equatable.dart';

class SignedInUser extends Equatable {
  const SignedInUser({
    required this.uid,
    this.name,
    this.email,
    this.guest = false,
  });

  final String uid;
  final String? name;
  final String? email;

  /// Whether this is a session rather than an account: a uid with nothing
  /// behind it that can be signed into again. Identity like the uid is, and
  /// here rather than inferred from a missing name — an account can have none
  /// (ADR-0010).
  final bool guest;

  @override
  List<Object?> get props => [uid, name, email, guest];
}

abstract interface class SignInGateway {
  /// Who is signed in, updating as that changes. Emits null when nobody is,
  /// and emits the restored user on launch without any UI being shown.
  ///
  /// Reports a guest trading their session for an account as well, which is
  /// why this cannot be built on auth state alone: linking leaves the uid
  /// exactly as it was, so nothing about the *state* of being signed in
  /// changes, only who the user now is.
  Stream<SignedInUser?> changes();

  /// Throws [SignInAbandoned] if the user backs out of the account picker.
  Future<void> signIn();

  /// A session with no account behind it: an anonymous account, so the Ledger,
  /// the Receipts directory and the Worker's token are all keyed by a real uid
  /// (ADR-0010). Keepable later through [linkWithGoogle], and unrecoverable
  /// until then, which is why leaving one erases it.
  ///
  /// No abandoning to do: there is no picker to back out of.
  Future<void> continueAsGuest();

  /// A guest trading their session for an account, keeping the uid and
  /// therefore the Ledger. Nothing moves: the same uid signs the same
  /// documents afterwards.
  ///
  /// Throws [SignInAbandoned] if the picker is dismissed, exactly as [signIn]
  /// does, and [AccountAlreadyHasALedger] when the chosen account is already
  /// its own user. Callers are given that as a named thing rather than a
  /// platform error code to recognise.
  Future<void> linkWithGoogle();

  /// Signing in as the account a link was refused for, with the credential
  /// that refusal carried, so the user is not asked to choose it twice.
  Future<void> signInWith(Object credential);

  /// Ending an identity rather than leaving it: the account itself goes, and
  /// nobody signs into that uid again. Only a guest is ever deleted this way
  /// — an account holder signs out — and the data keyed by the uid must be
  /// gone first, because the token that authorises deleting it dies here.
  Future<void> deleteAccount();

  Future<void> signOut();
}

/// The user dismissed the account picker. Not a failure — there is nothing to
/// tell them that they do not already know.
class SignInAbandoned implements Exception {
  const SignInAbandoned();
}

/// The account a guest chose is already somebody: it has its own uid and its
/// own Ledger, and the two cannot be made one by linking.
///
/// Carries the credential to sign in with once the user has said which Ledger
/// they are keeping, because the alternative is opening the picker again and
/// asking for an answer they have already given.
class AccountAlreadyHasALedger implements Exception {
  const AccountAlreadyHasALedger(this.credential);

  final Object credential;
}
