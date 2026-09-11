import 'dart:async';

import 'package:where_money/session/sign_in_gateway.dart';

class FakeSignInGateway implements SignInGateway {
  FakeSignInGateway({SignedInUser? alreadySignedIn})
    : _current = alreadySignedIn;

  static const kai = SignedInUser(
    uid: 'kai-uid',
    name: 'Kai',
    email: 'kai@example.com',
  );

  /// An account Google returned no display name for, which it can do
  /// (ADR-0010). A constant of its own rather than a mutated [kai], so a test
  /// that wants a named account and a test that wants a nameless one cannot
  /// take each other's.
  static const nameless = SignedInUser(
    uid: 'nameless-uid',
    email: 'nameless@example.com',
  );

  /// Who a guest is, which is a uid and nothing else — an anonymous account
  /// has no name and no address to report.
  static const guest = SignedInUser(uid: 'guest-uid', guest: true);

  /// The credential a refused link hands back, so a test can watch it reach
  /// the sign-in that follows the collision.
  static const theOtherAccount = 'the-other-account';

  final _changes = StreamController<SignedInUser?>.broadcast();
  SignedInUser? _current;

  /// Set any of these to have the matching call throw instead of succeeding.
  Object? refuse;
  Object? refuseGuest;
  Object? refuseSignOut;
  Object? refuseLink;

  /// Set to have [linkWithGoogle] find the chosen account already taken, the
  /// way Firebase does when the credential belongs to somebody.
  bool collides = false;

  /// What [signInWith] was handed, so a test can assert the user was not
  /// asked to choose the same account twice.
  Object? signedInWith;

  /// Set when the account itself is deleted, which is the last thing an
  /// erasure does and the one part of it this fake owns.
  var deleted = false;

  /// Set this to keep a sign-in in flight, so a test can hold the screen
  /// still and read what it says while it waits.
  Completer<void>? holds;

  @override
  Stream<SignedInUser?> changes() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<void> signIn() async {
    if (holds case final held?) await held.future;
    if (refuse case final failure?) throw failure;
    _current = kai;
    _changes.add(_current);
  }

  @override
  Future<void> continueAsGuest() async {
    if (holds case final held?) await held.future;
    if (refuseGuest case final failure?) throw failure;
    _current = guest;
    _changes.add(_current);
  }

  @override
  Future<void> linkWithGoogle() async {
    if (holds case final held?) await held.future;
    if (refuseLink case final failure?) throw failure;
    if (collides) throw const AccountAlreadyHasALedger(theOtherAccount);
    // The uid does not change: the same guest now has an account behind them.
    _current = SignedInUser(
      uid: _current?.uid ?? guest.uid,
      name: kai.name,
      email: kai.email,
    );
    _changes.add(_current);
  }

  @override
  Future<void> signInWith(Object credential) async {
    signedInWith = credential;
    _current = kai;
    _changes.add(_current);
  }

  @override
  Future<void> deleteAccount() async {
    deleted = true;
    _current = null;
    _changes.add(null);
  }

  @override
  Future<void> signOut() async {
    if (refuseSignOut case final failure?) throw failure;
    _current = null;
    _changes.add(null);
  }
}
