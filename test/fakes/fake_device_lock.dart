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

  /// What the last prompt was told to say. The platform's own window is the
  /// one thing on the Lock a widget test cannot read, so this is where its
  /// words are asserted.
  String? reason;

  @override
  Future<LockAvailability> availability() async {
    if (broken case final failure?) throw failure;
    return available;
  }

  @override
  Future<Unlocking> unlock(String reason) async {
    this.reason = reason;
    if (broken case final failure?) throw failure;
    return answer;
  }
}
