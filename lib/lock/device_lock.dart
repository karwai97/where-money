/// The phone's own lock, borrowed. This app never sees a fingerprint or a PIN;
/// it asks Android whether the person holding the phone is the one who set it
/// up, and gets back a yes or a no.
///
/// Deliberately not signing in. Signing in says who the user is to the Worker
/// so their Scan allowance can be counted; this says whether the data already
/// on this phone may be read. Neither stands in for the other.
library;

/// What this phone is able to ask for.
enum LockAvailability {
  /// A fingerprint or a face is enrolled, with the screen lock behind it.
  biometrics,

  /// No biometrics are enrolled, but a PIN, pattern or password is set, so
  /// that is what the user will be asked for.
  deviceCredential,

  /// No screen lock at all. There is nothing to ask, and asking anyway would
  /// shut the user out of their own Ledger.
  none,
}

/// How an attempt to unlock ended.
enum Unlocking {
  unlocked,

  /// The wrong finger, a cancelled prompt, too many tries. The user may go
  /// again.
  refused,

  /// The phone could not put the question — the screen lock was removed after
  /// the setting was turned on, the sensor is busy, the prompt could not be
  /// shown. The app opens rather than stranding someone behind a question
  /// nobody can answer.
  unavailable,
}

abstract interface class DeviceLock {
  Future<LockAvailability> availability();

  /// [reason] is what the phone's own prompt says it is asking for, in the
  /// language the user has chosen. It arrives here rather than being written
  /// here because this file is below the app's words.
  Future<Unlocking> unlock(String reason);
}
