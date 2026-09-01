import 'package:flutter/material.dart';
import 'package:where_money/data/device_preferences.dart';

class InMemoryDevicePreferences implements DevicePreferences {
  InMemoryDevicePreferences({
    bool locksOnOpen = true,
    ThemeMode theme = ThemeMode.system,
  }) : _locks = locksOnOpen,
       _mode = theme;

  bool _locks;
  ThemeMode _mode;
  final _explained = <String>{};

  @override
  Future<ThemeMode> theme() async => _mode;

  @override
  Future<void> setTheme(ThemeMode value) async => _mode = value;

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
}
