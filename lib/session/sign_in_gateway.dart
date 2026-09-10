/// Identity, and nothing more. The domain wants a uid out of signing in; the
/// name and the email are here only so the app can say who is signed in.
library;

import 'package:equatable/equatable.dart';

class SignedInUser extends Equatable {
  const SignedInUser({required this.uid, this.name, this.email});

  final String uid;
  final String? name;
  final String? email;

  @override
  List<Object?> get props => [uid, name, email];
}

abstract interface class SignInGateway {
  /// Who is signed in, updating as that changes. Emits null when nobody is,
  /// and emits the restored user on launch without any UI being shown.
  Stream<SignedInUser?> changes();

  /// Throws [SignInAbandoned] if the user backs out of the account picker.
  Future<void> signIn();

  /// A session with no account behind it. Still a uid, because the Ledger, the
  /// Receipts directory and the Worker's token are all keyed by one — what a
  /// guest is told they keep, and how they later trade it for an account, is
  /// an open question and a ticket of its own.
  ///
  /// No abandoning to do: there is no picker to back out of.
  Future<void> continueAsGuest();

  Future<void> signOut();
}

/// The user dismissed the account picker. Not a failure — there is nothing to
/// tell them that they do not already know.
class SignInAbandoned implements Exception {
  const SignInAbandoned();
}
