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
  ) async {
    emit(const SigningIn());
    try {
      await _gateway.signIn();
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
