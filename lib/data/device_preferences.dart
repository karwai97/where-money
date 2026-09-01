/// The few choices that belong to this phone rather than to the Ledger.
///
/// Not in Firestore on purpose: whether this device asks for a fingerprint is
/// a fact about this device, and it should not follow the user onto a phone
/// they never chose it for.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class DevicePreferences {
  /// Whether the app is drawn light, dark, or however the phone is set.
  /// Follows the phone unless the user has said otherwise.
  Future<ThemeMode> theme();

  Future<void> setTheme(ThemeMode value);

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
  Future<ThemeMode> theme() async {
    // Stored by name rather than by index, so reordering the enum cannot
    // quietly hand somebody a theme they never chose. A name this version does
    // not know is one a newer version wrote: fall back rather than fail.
    final stored = await _preferences.getString('theme');
    return ThemeMode.values.where((mode) => mode.name == stored).firstOrNull ??
        ThemeMode.system;
  }

  @override
  Future<void> setTheme(ThemeMode value) =>
      _preferences.setString('theme', value.name);

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
