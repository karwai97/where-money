import 'package:local_auth/local_auth.dart';

import 'device_lock.dart';

/// [DeviceLock] over the platform's own prompt. `biometricOnly` is left false
/// so that a phone with nothing enrolled asks for the PIN, pattern or password
/// instead of refusing — one prompt covers both, and the platform decides
/// which it is.
class LocalAuthLock implements DeviceLock {
  LocalAuthLock([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<LockAvailability> availability() async {
    try {
      // True when there is either a biometric or a screen lock to fall back
      // to; false when the phone has no secure lock at all.
      if (!await _auth.isDeviceSupported()) return LockAvailability.none;

      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isEmpty
          ? LockAvailability.deviceCredential
          : LockAvailability.biometrics;
    } on Exception {
      // Including a plugin that is not registered at all. A phone that cannot
      // answer the question is a phone with no Lock.
      return LockAvailability.none;
    }
  }

  @override
  Future<Unlocking> unlock(String reason) async {
    try {
      final passed = await _auth.authenticate(localizedReason: reason);
      return passed ? Unlocking.unlocked : Unlocking.refused;
    } on LocalAuthException catch (refusal) {
      return switch (refusal.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout ||
        LocalAuthExceptionCode.userRequestedFallback ||
        // A prompt is already up; the answer to it is the one that counts.
        LocalAuthExceptionCode.authInProgress => Unlocking.refused,
        // Everything else is the phone being unable to ask.
        _ => Unlocking.unavailable,
      };
    } on Exception {
      return Unlocking.unavailable;
    }
  }
}
