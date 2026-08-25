import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/device_preferences.dart';
import 'device_lock.dart';

sealed class LockEvent extends Equatable {
  const LockEvent();

  @override
  List<Object?> get props => const [];
}

final class LockOpened extends LockEvent {
  const LockOpened();
}

final class UnlockRequested extends LockEvent {
  const UnlockRequested();
}

/// The phone went to the launcher, another app, or the lock screen.
final class WentAway extends LockEvent {
  const WentAway(this.at);

  final DateTime at;

  @override
  List<Object?> get props => [at];
}

final class CameBack extends LockEvent {
  const CameBack(this.at);

  final DateTime at;

  @override
  List<Object?> get props => [at];
}

sealed class LockState extends Equatable {
  const LockState();

  @override
  List<Object?> get props => const [];
}

/// Before the phone has been asked anything. Shows nothing of the Ledger,
/// because the answer might be no.
final class LockUnknown extends LockState {
  const LockUnknown();
}

final class Locked extends LockState {
  const Locked({this.refused = false});

  /// Whether the last attempt was turned away. Distinguishes a prompt in
  /// flight from one the user has to start again themselves.
  final bool refused;

  @override
  List<Object?> get props => [refused];
}

final class Unlocked extends LockState {
  const Unlocked();
}

class LockBloc extends Bloc<LockEvent, LockState> {
  LockBloc(this._lock, this._preferences) : super(const LockUnknown()) {
    on<LockOpened>(_onOpened);
    on<UnlockRequested>(_onUnlockRequested);
    // The first one wins. Coming back, Android says `hidden` again on its way
    // to `resumed`, and taking that as the moment the user left would make
    // every return look instant.
    on<WentAway>((event, emit) => _leftAt ??= event.at);
    on<CameBack>(_onCameBack);
  }

  /// Long enough that answering a message or reading a notification does not
  /// cost a fingerprint; short enough that a phone left on a table is shut.
  static const forgiven = Duration(seconds: 30);

  final DeviceLock _lock;
  final DevicePreferences _preferences;

  DateTime? _leftAt;
  var _asking = false;

  Future<void> _onOpened(LockOpened event, Emitter<LockState> emit) async {
    if (!await _wanted()) {
      emit(const Unlocked());
      return;
    }
    emit(const Locked());
    add(const UnlockRequested());
  }

  Future<void> _onUnlockRequested(
    UnlockRequested event,
    Emitter<LockState> emit,
  ) async {
    if (_asking) return;
    _asking = true;
    try {
      switch (await _asked()) {
        // A phone that cannot ask opens anyway. The promise this makes is
        // worth less to the user than their own Ledger is.
        case Unlocking.unlocked || Unlocking.unavailable:
          emit(const Unlocked());
        case Unlocking.refused:
          emit(const Locked(refused: true));
      }
    } finally {
      _asking = false;
    }
  }

  Future<void> _onCameBack(CameBack event, Emitter<LockState> emit) async {
    final left = _leftAt;
    _leftAt = null;
    if (state is! Unlocked) return;
    if (left == null || event.at.difference(left) < forgiven) return;
    if (!await _wanted()) return;

    emit(const Locked());
    add(const UnlockRequested());
  }

  Future<Unlocking> _asked() async {
    try {
      return await _lock.unlock();
    } on Exception {
      return Unlocking.unavailable;
    }
  }

  /// The setting the user chose, and whether this phone can honour it. Read
  /// afresh every time, so turning the lock off in settings takes effect on
  /// the next return rather than on the next launch.
  ///
  /// A seam that throws answers no. Every failure here has to fall towards
  /// the user reaching their own Ledger, not away from it.
  Future<bool> _wanted() async {
    try {
      return await _preferences.locksOnOpen() &&
          await _lock.availability() != LockAvailability.none;
    } on Exception {
      return false;
    }
  }
}
