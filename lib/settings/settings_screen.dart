import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../a_form_of_rows.dart';
import '../choosing_a_currency.dart';
import '../data/device_preferences.dart';
import '../l10n/app_localizations.dart';
import '../ledger/ledger_bloc.dart';
import '../on_screen.dart';
import '../lock/device_lock.dart';
import '../session/session_bloc.dart';
import 'settings_cubit.dart';
import 'themes.dart';

/// The Settings, in Review's hand: the Setting's name in the tracked label
/// column, its value in a filled cell beside it, the sentence about it
/// indented under the cell, and a hairline between rows.
///
/// One table, with no heads over it. Review has heads because it has two
/// dozen fields and a reader needs telling where the receipt stops and the
/// money starts; four rows do not, and a strip over three of them said the
/// split ADR-0009 draws out loud without anybody asking it to. What each
/// Setting is for is under the row it is about, which is where this app says
/// things.
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
    final words = AppLocalizations.of(context);

    return Scaffold(
      appBar: barNamed(context, words.settingsTitle),
      body: ListView(
        children: [
          const _ThemeChoice(),
          const _LanguageChoice(),
          _Lock(availability: _availability, locks: _locks, onWanted: _want),
          const _HomeCurrencyChoice(),
          // The one gap on the screen. Everything above it is a table and is
          // ruled rather than spaced; this is not part of the table.
          const SizedBox(height: 24),
          _SignOut(onPressed: _signOut),
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

    return Ruled(
      child: Closed<ThemeMode>(
        name: 'theme',
        label: words.settingsTheme,
        value: context.watch<SettingsCubit>().state.theme,
        // Material's own order, which is also the order of the choice: follow
        // the phone, or override it one way or the other.
        options: ThemeMode.values,
        // Exhaustive, so this is never reached — but the Theme still has a
        // default, and it is the same one the Settings start on.
        whenUnrecognised: ThemeMode.system,
        copy: (theme) => switch (theme) {
          ThemeMode.system => words.settingsThemeSystem,
          ThemeMode.light => words.settingsThemeLight,
          ThemeMode.dark => words.settingsThemeDark,
        },
        onChosen: context.read<SettingsCubit>().chooseTheme,
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

/// Beside the Theme one, and the same shape: two choices of the same kind
/// should look like the same kind of thing.
class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice();

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);

    return Ruled(
      child: Closed<String>(
        name: 'language',
        label: words.settingsLanguage,
        value: context.watch<SettingsCubit>().state.language,
        // The order is the domain's closed set, so a third language is a list
        // entry there and nothing here.
        options: languages,
        // A language this build does not have is read in the one it falls back
        // to, which is the language it is already being read in.
        whenUnrecognised: defaultLanguage,
        copy: (language) => _named(words, language),
        onChosen: context.read<SettingsCubit>().chooseLanguage,
      ),
    );
  }
}

/// The one Setting that is a switch rather than a value. Composed here rather
/// than out of [Closed] or [Chosen]: a switch is its own shape and gets no
/// cell behind it, and its name has to be read out with its state.
class _Lock extends StatelessWidget {
  const _Lock({
    required this.availability,
    required this.locks,
    required this.onWanted,
  });

  /// Both null until the phone has said what it can ask. The row is drawn as
  /// its name and nothing else in the meantime — a switch arriving is better
  /// than a row arriving, and nothing else on this screen waits on this read.
  final LockAvailability? availability;
  final bool? locks;

  final ValueChanged<bool> onWanted;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = inTheLabelColumn(context, words.settingsLock);

    return Ruled(
      // One thing to a screen reader, so the switch is announced with its name
      // and its state and the sentence is read with it. That sentence is the
      // whole of the row in two of its three states.
      //
      // The [Semantics] inside is what supplies the name, and on its own it
      // would merge the subtree too — a `Semantics` without `container: true`
      // does. This says the intent rather than leaning on that; the claim
      // itself is pinned by `settings_in_graphite_test.dart`.
      child: MergeSemantics(
        child: Semantics(
          label: words.settingsLock,
          child: switch ((availability, locks)) {
            (final LockAvailability can, final bool locking) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    name,
                    const SizedBox(width: labelGap),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Switch(
                          // A phone with nothing to ask cannot make the
                          // promise, and a switch that says it does would be a
                          // lie. Drawn all the same: the sentence under it is
                          // how the user finds out what to do about that.
                          value: locking && can != LockAvailability.none,
                          onChanged: can == LockAvailability.none
                              ? null
                              : onWanted,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(left: sayingIndent(context), top: 2),
                  child: Text(switch (can) {
                    LockAvailability.biometrics => words.settingsLockBiometrics,
                    LockAvailability.deviceCredential =>
                      words.settingsLockDeviceCredential,
                    LockAvailability.none => words.settingsLockUnavailable,
                  }, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
            _ => Row(children: [name]),
          },
        ),
      ),
    );
  }
}

/// The one Setting that is about the money rather than about this phone
/// (ADR-0009). It changes freely and says so in place: no dialog asking
/// whether the user meant it, because the house style says things where they
/// happen, and the line under the row already says what it governs.
class _HomeCurrencyChoice extends StatelessWidget {
  const _HomeCurrencyChoice();

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    final currency = context.watch<SettingsCubit>().state.homeCurrency;
    // Where it came from, worked out rather than remembered: it was taken from
    // the first Expense exactly when it still matches what that Expense would
    // teach. Somebody who has since chosen a different one is not told a
    // provenance that stopped being true when they changed it.
    final learned = learnableCurrency(
      context.watch<LedgerBloc>().state.expenses,
    );

    return Ruled(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Chosen(
            label: words.settingsHomeCurrency,
            // Empty rather than a dash or a placeholder: a code the app does
            // not have is not a thing to draw, and the sentence under the cell
            // says what will set it.
            value: currency ?? '',
            onTap: () async {
              final cubit = context.read<SettingsCubit>();
              final chosen = await chooseACurrency(context);
              if (chosen != null) await cubit.chooseHomeCurrency(chosen);
            },
          ),
          Padding(
            padding: EdgeInsets.only(left: sayingIndent(context), top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currency == null)
                  Text(words.settingsHomeCurrencyNone, style: small)
                else if (currency == learned)
                  Text(words.settingsHomeCurrencyInferred, style: small),
                Text(words.settingsHomeCurrencyGoverns, style: small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Ledger's small FAB stretched to the height of Review's commit button,
/// and then muted: signing out is a way out of the screen rather than what the
/// screen is for, so it is outlined where the one action a screen exists for
/// is filled.
class _SignOut extends StatelessWidget {
  const _SignOut({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colours = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: colours.surfaceContainer,
          foregroundColor: colours.onSurfaceVariant,
          side: BorderSide(color: colours.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: asScreenName(theme.textTheme.labelLarge, tracking: 1.2),
        ),
        icon: const Icon(Icons.logout, size: 18),
        label: Text(cased(words, words.settingsSignOut)),
      ),
    );
  }
}
