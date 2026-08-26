/// The few choices that belong to this phone rather than to the Ledger.
///
/// Not in Firestore on purpose: whether this device asks for a fingerprint is
/// a fact about this device, and it should not follow the user onto a phone
/// they never chose it for.
library;

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class DevicePreferences {
  /// Whether the app asks for a fingerprint or the device PIN when it opens.
  /// On unless the user has said otherwise.
  Future<bool> locksOnOpen();

  Future<void> setLocksOnOpen(bool value);

  /// Whether this device has already told [uid] that their Expenses came back
  /// and their receipt photos did not. Said once per account per device.
  Future<bool> hasExplainedMissingPhotos(String uid);

  Future<void> rememberExplainingMissingPhotos(String uid);
}

class StoredDevicePreferences implements DevicePreferences {
  StoredDevicePreferences([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<bool> locksOnOpen() async =>
      await _preferences.getBool('locksOnOpen') ?? true;

  @override
  Future<void> setLocksOnOpen(bool value) =>
      _preferences.setBool('locksOnOpen', value);

  @override
  Future<bool> hasExplainedMissingPhotos(String uid) async =>
      await _preferences.getBool(_missingPhotos(uid)) ?? false;

  @override
  Future<void> rememberExplainingMissingPhotos(String uid) =>
      _preferences.setBool(_missingPhotos(uid), true);

  static String _missingPhotos(String uid) => 'explainedMissingPhotos:$uid';
}
