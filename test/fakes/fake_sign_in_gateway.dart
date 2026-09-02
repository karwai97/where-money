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

  final _changes = StreamController<SignedInUser?>.broadcast();
  SignedInUser? _current;

  /// Set either of these to have the matching call throw instead of
  /// succeeding.
  Object? refuse;
  Object? refuseSignOut;

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
  Future<void> signOut() async {
    if (refuseSignOut case final failure?) throw failure;
    _current = null;
    _changes.add(null);
  }
}
