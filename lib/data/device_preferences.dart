/// The few choices that belong to this phone rather than to the Ledger.
///
/// Not in Firestore on purpose: whether this device asks for a fingerprint is
/// a fact about this device, and it should not follow the user onto a phone
/// they never chose it for.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:where_money_core/where_money_core.dart';

abstract interface class DevicePreferences {
  /// Whether the app is drawn light, dark, or however the phone is set.
  /// Follows the phone unless the user has said otherwise.
  Future<ThemeMode> theme();

  Future<void> setTheme(ThemeMode value);

  /// Which language the app is read in. On this phone rather than on the
  /// account, because the sign-in screen has to be drawn in some language
  /// before the app knows who is signing in.
  Future<String> language();

  Future<void> setLanguage(String value);

  /// The currency this Ledger's totals are computed in, or null until the
  /// first Expense is committed and it is learned from that. Here rather than
  /// on the account, which is where it belongs: see ADR-0009.
  Future<String?> homeCurrency();

  Future<void> setHomeCurrency(String value);

  /// Whether the app asks for a fingerprint or the device PIN when it opens.
  /// On unless the user has said otherwise.
  Future<bool> locksOnOpen();

  Future<void> setLocksOnOpen(bool value);

  /// Whether this device has already told [uid] that their Expenses came back
  /// and their receipt photos did not. Said once per account per device.
  Future<bool> hasExplainedMissingPhotos(String uid);

  Future<void> rememberExplainingMissingPhotos(String uid);

  /// What the Worker last told [uid] about the day's Scans, or null before it
  /// has ever answered on this phone. Per account like
  /// [hasExplainedMissingPhotos]: the allowance is the account's, and a second
  /// account on the same phone has its own.
  Future<Allowance?> scanAllowance(String uid);

  Future<void> rememberScanAllowance(String uid, Allowance allowance);
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
  Future<String> language() async {
    // Read against the closed set for the same reason the theme is read by
    // name: a code this version does not know is one a newer version wrote,
    // and English is a better answer than a crash.
    final stored = await _preferences.getString('language');
    return languages.contains(stored) ? stored! : defaultLanguage;
  }

  @override
  Future<void> setLanguage(String value) =>
      _preferences.setString('language', value);

  @override
  Future<String?> homeCurrency() async {
    // Read against the set for the same reason the language is: a code this
    // version does not know is one a newer version wrote, and having none is
    // a state the app already handles.
    final stored = await _preferences.getString('homeCurrency');
    return isoCurrencies.contains(stored) ? stored : null;
  }

  @override
  Future<void> setHomeCurrency(String value) =>
      _preferences.setString('homeCurrency', value);

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

  @override
  Future<Allowance?> scanAllowance(String uid) async {
    final stored = await _preferences.getString(_scanAllowance(uid));
    if (stored == null) return null;

    // One string rather than three keys, so a half-written allowance is not a
    // state anything has to read. Anything that does not parse was written by
    // a version that wrote it differently, and having none is a state the row
    // already draws.
    try {
      final held = jsonDecode(stored) as Map<String, dynamic>;
      return Allowance(
        used: held['used'] as int,
        limit: held['limit'] as int,
        resetsAt: DateTime.parse(held['resetsAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> rememberScanAllowance(String uid, Allowance allowance) =>
      _preferences.setString(
        _scanAllowance(uid),
        jsonEncode({
          'used': allowance.used,
          'limit': allowance.limit,
          'resetsAt': allowance.resetsAt.toIso8601String(),
        }),
      );

  static String _missingPhotos(String uid) => 'explainedMissingPhotos:$uid';

  static String _scanAllowance(String uid) => 'scanAllowance:$uid';
}
