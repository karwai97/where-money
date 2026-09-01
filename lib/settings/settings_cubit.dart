import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../data/device_preferences.dart';

/// The Settings this launch is running under.
class Settings extends Equatable {
  const Settings({
    this.theme = ThemeMode.system,
    this.language = defaultLanguage,
  });

  final ThemeMode theme;

  /// The language the app is read in, as its code. Not a `Locale`: what is
  /// stored on the phone and what the Worker is told are both the code, and
  /// building the Locale is the one place that needs one.
  final String language;

  /// Copied rather than rebuilt, so choosing one Setting cannot quietly reset
  /// the one beside it.
  Settings copyWith({ThemeMode? theme, String? language}) =>
      Settings(theme: theme ?? this.theme, language: language ?? this.language);

  @override
  List<Object?> get props => [theme, language];
}

/// Holds the Settings the app is drawn with and writes each change back to the
/// phone. Seeded with what was already read rather than reading storage
/// itself, so the first frame is the one the user chose.
///
/// **Both writes emit before they persist, and both callers drop the Future.**
/// The Lock toggle in `settings_screen.dart` does the same, so this is the
/// house pattern rather than an oversight in one place — but it is a pattern
/// with a cost: a preference store that refuses the write leaves the user
/// looking at a change that reverts on the next launch, and the rejection
/// surfaces as an unhandled async error rather than as anything they can see.
/// The read side of the same store *is* guarded, in `main.dart`. Deciding what
/// a failed write should say is a change to all three at once, and it has not
/// been made.
class SettingsCubit extends Cubit<Settings> {
  SettingsCubit(this._preferences, {Settings from = const Settings()})
    : super(from);

  final DevicePreferences _preferences;

  Future<void> chooseTheme(ThemeMode theme) async {
    emit(state.copyWith(theme: theme));
    await _preferences.setTheme(theme);
  }

  Future<void> chooseLanguage(String language) async {
    emit(state.copyWith(language: language));
    await _preferences.setLanguage(language);
  }
}
