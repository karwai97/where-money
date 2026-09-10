import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'sign_in_gateway.dart';

sealed class SessionEvent extends Equatable {
  const SessionEvent();

  @override
  List<Object?> get props => const [];
}

final class SessionOpened extends SessionEvent {
  const SessionOpened();
}

final class SignInRequested extends SessionEvent {
  const SignInRequested();
}

/// The way round the account: a session with no Google behind it. What a
/// guest keeps is not settled — see the gateway.
final class GuestRequested extends SessionEvent {
  const GuestRequested();
}

final class SignOutRequested extends SessionEvent {
  const SignOutRequested();
}

final class _UserChanged extends SessionEvent {
  const _UserChanged(this.user);

  final SignedInUser? user;

  @override
  List<Object?> get props => [user];
}

sealed class SessionState extends Equatable {
  const SessionState();

  @override
  List<Object?> get props => const [];
}

/// Before the restored session, if there is one, has been read.
final class SessionUnknown extends SessionState {
  const SessionUnknown();
}

final class SignedOut extends SessionState {
  const SignedOut({this.failure});

  /// Why the last attempt did not work. Null after an abandoned one, because
  /// the user closed the picker themselves and knows it.
  final String? failure;

  @override
  List<Object?> get props => [failure];
}

final class SigningIn extends SessionState {
  const SigningIn();
}

final class SignedIn extends SessionState {
  const SignedIn(this.user);

  final SignedInUser user;

  @override
  List<Object?> get props => [user];
}

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc(this._gateway) : super(const SessionUnknown()) {
    on<SessionOpened>(_onOpened);
    on<SignInRequested>(_onSignInRequested);
    on<GuestRequested>(_onGuestRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<_UserChanged>((event, emit) {
      final user = event.user;
      emit(user == null ? const SignedOut() : SignedIn(user));
    });
  }

  final SignInGateway _gateway;
  StreamSubscription<SignedInUser?>? _watching;

  void _onOpened(SessionOpened event, Emitter<SessionState> emit) {
    _watching?.cancel();
    _watching = _gateway.changes().listen((user) => add(_UserChanged(user)));
  }

  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<SessionState> emit,
  ) async {
    try {
      await _gateway.signOut();
    } catch (_) {
      // Google can refuse to forget the account — no network, no Play
      // services — but this device is done with the session either way, and
      // the changes stream will not fire on its own.
      emit(const SignedOut());
    }
  }

  Future<void> _onSignInRequested(
    SignInRequested event,
    Emitter<SessionState> emit,
  ) => _waitOn(_gateway.signIn, emit);

  Future<void> _onGuestRequested(
    GuestRequested event,
    Emitter<SessionState> emit,
  ) => _waitOn(_gateway.continueAsGuest, emit);

  /// Either way in, waited on the same way: in flight until it answers, then
  /// whatever the gateway's stream says, or the reason it will not.
  ///
  /// One [SigningIn] for both, deliberately. There is no guest-specific state
  /// because the screen has nothing different to say while it waits, and a
  /// guest has no picker to back out of — so [SignInAbandoned] simply never
  /// comes from that side.
  Future<void> _waitOn(
    Future<void> Function() attempt,
    Emitter<SessionState> emit,
  ) async {
    emit(const SigningIn());
    try {
      await attempt();
    } on SignInAbandoned {
      emit(const SignedOut());
    } catch (error) {
      emit(SignedOut(failure: error.toString()));
    }
  }

  @override
  Future<void> close() {
    _watching?.cancel();
    return super.close();
  }
}
