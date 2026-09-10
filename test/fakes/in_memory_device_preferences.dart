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
    String? erasureUnderWay,
  }) : _erasing = erasureUnderWay,
       _locks = locksOnOpen,
       _allowance = scanAllowance,
       _mode = theme;

  bool _locks;
  ThemeMode _mode;
  String _language;
  String? _homeCurrency;
  Allowance? _allowance;
  String? _erasing;
  final _explained = <String>{};

  /// Every uid this phone has been told to forget, so a test can ask whether
  /// an erasure reached the preferences as well as the Ledger.
  final forgotten = <String>{};

  /// Set to have [forget] refuse. Best effort like the Scans are, and for
  /// the same reason: what a phone remembers is local and invisible.
  Object? refuseForgetting;

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

  @override
  Future<String?> erasureUnderWay() async => _erasing;

  @override
  Future<void> rememberErasureUnderWay(String uid) async => _erasing = uid;

  @override
  Future<void> forgetErasureUnderWay() async => _erasing = null;

  @override
  Future<void> forget(String uid) async {
    if (refuseForgetting case final failure?) throw failure;
    forgotten.add(uid);
    _explained.remove(uid);
    _allowance = null;
    _homeCurrency = null;
  }
}
