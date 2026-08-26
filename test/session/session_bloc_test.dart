import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/session/session_bloc.dart';
import 'package:where_money/session/sign_in_gateway.dart';

import '../fakes/fake_sign_in_gateway.dart';

void main() {
  blocTest<SessionBloc, SessionState>(
    'a first-time user is asked to sign in',
    build: () => SessionBloc(FakeSignInGateway()),
    act: (bloc) => bloc.add(const SessionOpened()),
    expect: () => [const SignedOut()],
  );

  blocTest<SessionBloc, SessionState>(
    'a returning user is signed in without seeing the account picker',
    build: () =>
        SessionBloc(FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai)),
    act: (bloc) => bloc.add(const SessionOpened()),
    expect: () => [const SignedIn(FakeSignInGateway.kai)],
  );

  blocTest<SessionBloc, SessionState>(
    'signing in shows progress and then the account',
    build: () => SessionBloc(FakeSignInGateway()),
    act: (bloc) async {
      bloc.add(const SessionOpened());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SignInRequested());
    },
    skip: 1,
    expect: () => [const SigningIn(), const SignedIn(FakeSignInGateway.kai)],
  );

  blocTest<SessionBloc, SessionState>(
    'backing out of the account picker explains nothing, because nothing failed',
    build: () => SessionBloc(FakeSignInGateway()..refuse = const SignInAbandoned()),
    act: (bloc) async {
      bloc.add(const SessionOpened());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SignInRequested());
    },
    skip: 1,
    expect: () => [const SigningIn(), const SignedOut()],
  );

  blocTest<SessionBloc, SessionState>(
    'a sign-in that actually failed says so',
    build: () =>
        SessionBloc(FakeSignInGateway()..refuse = StateError('no network')),
    act: (bloc) async {
      bloc.add(const SessionOpened());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SignInRequested());
    },
    skip: 1,
    expect: () => [
      const SigningIn(),
      isA<SignedOut>().having((state) => state.failure, 'failure', isNotNull),
    ],
  );

  blocTest<SessionBloc, SessionState>(
    'signing out ends the session even when Google will not forget the account',
    build: () {
      final gateway = FakeSignInGateway(
        alreadySignedIn: FakeSignInGateway.kai,
      )..refuseSignOut = StateError('no play services');
      return SessionBloc(gateway);
    },
    act: (bloc) async {
      bloc.add(const SessionOpened());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SignOutRequested());
    },
    skip: 1,
    expect: () => [const SignedOut()],
  );

  blocTest<SessionBloc, SessionState>(
    'signing out ends the session',
    build: () =>
        SessionBloc(FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai)),
    act: (bloc) async {
      bloc.add(const SessionOpened());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SignOutRequested());
    },
    skip: 1,
    expect: () => [const SignedOut()],
  );
}
