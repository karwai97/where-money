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

  @override
  Future<LockAvailability> availability() async {
    if (broken case final failure?) throw failure;
    return available;
  }

  @override
  Future<Unlocking> unlock() async {
    if (broken case final failure?) throw failure;
    return answer;
  }
}
