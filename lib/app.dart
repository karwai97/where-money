import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import 'data/device_preferences.dart';
import 'l10n/app_localizations.dart';
import 'data/ledger_store.dart';
import 'ledger/ledger_screen.dart';
import 'lock/device_lock.dart';
import 'lock/lock_gate.dart';
import 'scan/model_gateway.dart';
import 'scan/photographer.dart';
import 'session/session_bloc.dart';
import 'session/sign_in_gateway.dart';
import 'session/sign_in_screen.dart';
import 'settings/settings_cubit.dart';
import 'settings/themes.dart';

/// A Ledger belongs to exactly one user, so the store is built from the uid
/// rather than told about it — which is all the app ever wants from signing in.
typedef LedgerFor = LedgerStore Function(String uid);

class WhereMoneyApp extends StatelessWidget {
  const WhereMoneyApp({
    super.key,
    required this.signIn,
    required this.ledgerFor,
    required this.model,
    required this.lock,
    required this.preferences,
    this.knobs = const Knobs(),
    this.theme = ThemeMode.system,
    this.language = defaultLanguage,
    this.photograph,
  });

  final SignInGateway signIn;
  final LedgerFor ledgerFor;

  /// The Worker, or its fake. Not built per uid: the ID token the Worker reads
  /// is what says who is calling.
  final ModelGateway model;

  /// The phone's own lock. Nothing to do with signing in: that says who the
  /// user is to the Worker, this says whether the data already on this phone
  /// may be read.
  final DeviceLock lock;

  final DevicePreferences preferences;

  /// The theme this launch opens with, already read off the phone. Handed
  /// down as a plain value like the Knobs beside it, so the first frame is
  /// drawn in the theme the user chose rather than in whatever was quickest to
  /// reach.
  final ThemeMode theme;

  /// The language this launch opens with, already read off the phone, for the
  /// same reason as [theme]: the first frame is drawn in the language the user
  /// chose rather than in whichever one was compiled in.
  final String language;

  /// What a console has to say about how a receipt is read. Plain values,
  /// handed down: nothing below here asks anything for them.
  final Knobs knobs;

  /// Injected so tests can hand down bytes: the camera is the one thing above
  /// the tested surface, and this is the line it sits on. The device's own
  /// camera is built from [knobs] rather than defaulted to, so the size a
  /// console asks for is the size the picker is given.
  final Photographer? photograph;

  @override
  Widget build(BuildContext context) {
    // Built once and handed to every MaterialApp a Setting rebuilds, so
    // changing the theme is not also a reason to build a second LedgerStore
    // over the top of the one the blocs are already reading.
    final home = BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) => switch (state) {
        SessionUnknown() => const _Opening(),
        SignedOut() || SigningIn() => SignInScreen(state: state),
        SignedIn(:final user) => LedgerScreen(
          // Keyed by uid so a second account never inherits the first
          // account's Ledger bloc.
          key: ValueKey(user.uid),
          uid: user.uid,
          store: ledgerFor(user.uid),
          model: model,
          knobs: knobs,
          photograph:
              photograph ??
              (from) => photographWithDevice(from, longEdge: knobs.longEdge),
        ),
      },
    );

    // Above the MaterialApp, so the lock and the Settings route reach these
    // without being handed down through every screen in between.
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<DeviceLock>.value(value: lock),
        RepositoryProvider<DevicePreferences>.value(value: preferences),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => SessionBloc(signIn)..add(const SessionOpened()),
          ),
          BlocProvider(
            create: (_) => SettingsCubit(
              preferences,
              from: Settings(theme: theme, language: language),
            ),
          ),
        ],
        child: BlocBuilder<SettingsCubit, Settings>(
          builder: (context, settings) => MaterialApp(
            title: 'where_money',
            locale: Locale(settings.language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            themeMode: settings.theme,
            theme: themeFor(Brightness.light),
            // The charts take their one hue from the scheme, so a phone in dark
            // mode needs a scheme built for a dark surface. Without this there
            // is no dark theme to be legible in.
            darkTheme: themeFor(Brightness.dark),
            // Above the Navigator rather than inside `home`, so a phone locked
            // while an Expense was open covers that route too. There is nothing
            // to lock when nobody is signed in.
            builder: (context, child) =>
                context.watch<SessionBloc>().state is SignedIn
                ? LockGate(lock: lock, preferences: preferences, child: child!)
                : child!,
            home: home,
          ),
        ),
      ),
    );
  }
}

class _Opening extends StatelessWidget {
  const _Opening();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
