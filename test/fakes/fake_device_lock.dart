import 'dart:async';

import 'package:where_money/lock/device_lock.dart';

/// A phone that answers however the test needs it to. Defaults to the ordinary
/// case: a fingerprint is enrolled and the person holding it is the owner.
class FakeDeviceLock implements DeviceLock {
  FakeDeviceLock({
    this.available = LockAvailability.biometrics,
    this.answer = Unlocking.unlocked,
  });

  LockAvailability available;
  Unlocking answer;

  /// Set this to have both calls throw, standing in for a plugin that is not
  /// registered or a platform channel that is not there.
  Object? broken;

  /// Set this to never say what this phone can ask, standing in for a platform
  /// call that is taking its time. Settings draws the Lock's row named and
  /// empty until the answer arrives, and this is how a test holds it there.
  Completer<void>? holdsTheAnswer;

  /// Set this to leave the prompt up without an answer, standing in for a
  /// finger that has not been put on the sensor yet. That wait is the only
  /// time the Lock's spinner is on screen.
  Completer<void>? holdsThePrompt;

  /// What the last prompt was told to say. The platform's own window is the
  /// one thing on the Lock a widget test cannot read, so this is where its
  /// words are asserted.
  String? reason;

  @override
  Future<LockAvailability> availability() async {
    if (broken case final failure?) throw failure;
    await holdsTheAnswer?.future;
    return available;
  }

  @override
  Future<Unlocking> unlock(String reason) async {
    this.reason = reason;
    if (broken case final failure?) throw failure;
    await holdsThePrompt?.future;
    return answer;
  }
}
