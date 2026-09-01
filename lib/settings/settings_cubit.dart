import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/device_preferences.dart';

/// The Settings this launch is running under.
class Settings extends Equatable {
  const Settings({this.theme = ThemeMode.system});

  final ThemeMode theme;

  @override
  List<Object?> get props => [theme];
}

/// Holds the Settings the app is drawn with and writes each change back to the
/// phone. Seeded with what was already read rather than reading storage
/// itself, so the first frame is the one the user chose.
class SettingsCubit extends Cubit<Settings> {
  SettingsCubit(this._preferences, {Settings from = const Settings()})
    : super(from);

  final DevicePreferences _preferences;

  Future<void> chooseTheme(ThemeMode theme) async {
    emit(Settings(theme: theme));
    await _preferences.setTheme(theme);
  }
}
