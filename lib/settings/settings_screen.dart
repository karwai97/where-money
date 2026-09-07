import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../choosing_a_currency.dart';
import '../data/device_preferences.dart';
import '../l10n/app_localizations.dart';
import '../ledger/ledger_bloc.dart';
import '../lock/device_lock.dart';
import '../session/session_bloc.dart';
import 'settings_cubit.dart';
import 'themes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  LockAvailability? _availability;
  bool? _locks;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    final preferences = context.read<DevicePreferences>();
    final availability = await context.read<DeviceLock>().availability();
    final locks = await preferences.locksOnOpen();
    if (mounted) {
      setState(() {
        _availability = availability;
        _locks = locks;
      });
    }
  }

  Future<void> _want(bool locks) async {
    setState(() => _locks = locks);
    await context.read<DevicePreferences>().setLocksOnOpen(locks);
  }

  void _signOut() {
    final session = context.read<SessionBloc>();
    Navigator.of(context).pop();
    session.add(const SignOutRequested());
  }

  @override
  Widget build(BuildContext context) {
    final availability = _availability;
    final locks = _locks;
    final words = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(words.settingsTitle)),
      body: ListView(
        children: [
          const _ThemeChoice(),
          const _LanguageChoice(),
          const _HomeCurrencyChoice(),
          if (availability == null || locks == null)
            ListTile(title: Text(words.settingsLock))
          else
            SwitchListTile(
              title: Text(words.settingsLock),
              subtitle: Text(switch (availability) {
                LockAvailability.biometrics => words.settingsLockBiometrics,
                LockAvailability.deviceCredential =>
                  words.settingsLockDeviceCredential,
                LockAvailability.none => words.settingsLockUnavailable,
              }),
              // A phone with nothing to ask cannot make the promise, and a
              // switch that says it does would be a lie.
              value: locks && availability != LockAvailability.none,
              onChanged: availability == LockAvailability.none ? null : _want,
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(words.settingsSignOut),
            onTap: _signOut,
          ),
        ],
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice();

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);

    return ListTile(
      title: Text(words.settingsTheme),
      trailing: DropdownButton<ThemeMode>(
        value: context.watch<SettingsCubit>().state.theme,
        onChanged: (theme) => context.read<SettingsCubit>().chooseTheme(
          theme ?? ThemeMode.system,
        ),
        items: [
          DropdownMenuItem(
            value: ThemeMode.system,
            child: Text(words.settingsThemeSystem),
          ),
          DropdownMenuItem(
            value: ThemeMode.light,
            child: Text(words.settingsThemeLight),
          ),
          DropdownMenuItem(
            value: ThemeMode.dark,
            child: Text(words.settingsThemeDark),
          ),
        ],
      ),
    );
  }
}

/// Each language named in its own language, so somebody can find theirs without
/// already reading the other one — which is why these two entries are identical
/// in every ARB file. A code with no name beside it reads as itself rather than
/// as somebody else's language; `choosing_a_language_test.dart` is what fails
/// when a language is added here and not named.
String _named(AppLocalizations words, String language) => switch (language) {
  'en' => words.settingsLanguageEnglish,
  'zh' => words.settingsLanguageChinese,
  _ => language,
};

/// The one Setting that is about the money rather than about this phone
/// (ADR-0009). It changes freely and says so in place: no dialog asking
/// whether the user meant it, because the house style says things where they
/// happen, and the line under the row already says what it governs.
class _HomeCurrencyChoice extends StatelessWidget {
  const _HomeCurrencyChoice();

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final currency = context.watch<SettingsCubit>().state.homeCurrency;
    // Where it came from, worked out rather than remembered: it was taken from
    // the first Expense exactly when it still matches what that Expense would
    // teach. Somebody who has since chosen a different one is not told a
    // provenance that stopped being true when they changed it.
    final learned = learnableCurrency(
      context.watch<LedgerBloc>().state.expenses,
    );

    return ListTile(
      title: Text(words.settingsHomeCurrency),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (currency == null)
            Text(words.settingsHomeCurrencyNone)
          else if (currency == learned)
            Text(words.settingsHomeCurrencyInferred),
          Text(words.settingsHomeCurrencyGoverns),
        ],
      ),
      isThreeLine: true,
      trailing: Text(
        currency ?? '',
        style: asFigures(Theme.of(context).textTheme.titleMedium),
      ),
      onTap: () async {
        final cubit = context.read<SettingsCubit>();
        final chosen = await chooseACurrency(context);
        if (chosen != null) await cubit.chooseHomeCurrency(chosen);
      },
    );
  }
}

/// Beside the Theme one, and the same shape: two choices of the same kind
/// should look like the same kind of thing.
class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice();

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);

    return ListTile(
      title: Text(words.settingsLanguage),
      trailing: DropdownButton<String>(
        value: context.watch<SettingsCubit>().state.language,
        onChanged: (language) => context.read<SettingsCubit>().chooseLanguage(
          language ?? defaultLanguage,
        ),
        // The order is the domain's closed set, so a third language is a list
        // entry there and nothing here.
        items: [
          for (final language in languages)
            DropdownMenuItem(
              value: language,
              child: Text(_named(words, language)),
            ),
        ],
      ),
    );
  }
}
