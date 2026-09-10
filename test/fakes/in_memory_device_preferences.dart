import 'package:flutter/material.dart';
import 'package:where_money/data/device_preferences.dart';
import 'package:where_money_core/where_money_core.dart';

class InMemoryDevicePreferences implements DevicePreferences {
  InMemoryDevicePreferences({
    bool locksOnOpen = true,
    ThemeMode theme = ThemeMode.system,
    this._language = defaultLanguage,
    this._homeCurrency,
    Allowance? scanAllowance,
  }) : _locks = locksOnOpen,
       _allowance = scanAllowance,
       _mode = theme;

  bool _locks;
  ThemeMode _mode;
  String _language;
  String? _homeCurrency;
  Allowance? _allowance;
  final _explained = <String>{};

  @override
  Future<ThemeMode> theme() async => _mode;

  @override
  Future<void> setTheme(ThemeMode value) async => _mode = value;

  @override
  Future<String> language() async => _language;

  @override
  Future<void> setLanguage(String value) async => _language = value;

  @override
  Future<String?> homeCurrency() async => _homeCurrency;

  @override
  Future<void> setHomeCurrency(String value) async => _homeCurrency = value;

  @override
  Future<bool> locksOnOpen() async => _locks;

  @override
  Future<void> setLocksOnOpen(bool value) async => _locks = value;

  @override
  Future<bool> hasExplainedMissingPhotos(String uid) async =>
      _explained.contains(uid);

  @override
  Future<void> rememberExplainingMissingPhotos(String uid) async =>
      _explained.add(uid);

  /// Seeded and read without a uid: no test here signs two accounts into the
  /// same phone, and the interface's promise about that is
  /// `device_preferences_test.dart`'s to keep.
  @override
  Future<Allowance?> scanAllowance(String uid) async => _allowance;

  @override
  Future<void> rememberScanAllowance(String uid, Allowance allowance) async =>
      _allowance = allowance;
}
