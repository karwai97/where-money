import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import 'clock.dart';
import 'data/device_preferences.dart';
import 'data/erasing_a_ledger.dart';
import 'data/stores.dart';
import 'l10n/app_localizations.dart';
import 'ledger/ledger_screen.dart';
import 'lock/device_lock.dart';
import 'lock/lock_gate.dart';
import 'scan/model_gateway.dart';
import 'scan/photographer.dart';
import 'session/session_bloc.dart';
import 'session/sign_in_gateway.dart';
import 'session/sign_in_screen.dart';
import 'session/trading_a_guest_for_an_account.dart';
import 'session/signed_in_scope.dart';
import 'settings/settings_cubit.dart';
import 'settings/themes.dart';

/// A Ledger belongs to exactly one user, and so does the directory their
/// Receipts sit in, so all three seams are built from the uid rather than told
/// about it — which is all the app ever wants from signing in.
typedef StoresFor = Stores Function(String uid);

class WhereMoneyApp extends StatelessWidget {
  const WhereMoneyApp({
    super.key,
    required this.signIn,
    required this.storesFor,
    required this.model,
    required this.lock,
    required this.preferences,
    this.knobs = const Knobs(),
    this.theme = ThemeMode.system,
    this.language = defaultLanguage,
    this.homeCurrency,
    this.clock = DateTime.now,
    this.photograph,
    this.erasureUnderWay,
  });

  final SignInGateway signIn;
  final StoresFor storesFor;

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

  /// The Home Currency this launch opens with, already read off the phone, or
  /// null on a Ledger that has not had its first Expense yet. Handed down like
  /// [theme] and [language]: the first frame is drawn knowing whether there
  /// are totals to show (ADR-0009).
  final String? homeCurrency;

  /// The uid of a Ledger a guest asked to be rid of and whose erasure was
  /// interrupted, or null when there is none. Read off the phone before the
  /// first frame like [theme] and [language] are, and for the same reason:
  /// the app has to know before it draws whether it is opening a Ledger or
  /// finishing the deletion of one.
  ///
  /// The read is what happens early. The erasure itself runs over the
  /// network and runs here, because blocking startup on it would give a guest
  /// on a bad connection a black screen with no way past it.
  final String? erasureUnderWay;

  /// What a console has to say about how a receipt is read. Plain values,
  /// handed down: nothing below here asks anything for them.
  final Knobs knobs;

  /// Which month the Ledger opens on. Injected for the same reason as
  /// [photograph]: a widget test that seeds a Ledger at a fixed date has to be
  /// able to say when "now" is, or it passes until the calendar moves and then
  /// fails for a reason that has nothing to do with the code.
  final Clock clock;

  /// Injected so tests can hand down bytes: the camera is the one thing above
  /// the tested surface, and this is the line it sits on. The device's own
  /// camera is built from [knobs] rather than defaulted to, so the size a
  /// console asks for is the size the picker is given.
  final Photographer? photograph;

  @override
  Widget build(BuildContext context) {
    // Composed here rather than handed in: everything it needs is already a
    // seam this widget holds, so a second injection point would only be a
    // second way to wire the same three objects together.
    ErasingALedger erasesFor(String uid) => ErasingWhatAUidOwns(
      uid: uid,
      stores: storesFor(uid),
      preferences: preferences,
      identity: signIn,
    );

    // Built once and handed to every MaterialApp a Setting rebuilds, so
    // changing the theme or the language is not also a reason to build a second
    // screen over the top of the one the user is looking at.
    final Widget signedInOrNot = BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) => switch (state) {
        SessionUnknown() => const _Opening(),
        SignedOut() || SigningIn() => SignInScreen(state: state),
        SignedIn() => LedgerScreen(
          photograph:
              photograph ??
              (from) => photographWithDevice(from, longEdge: knobs.longEdge),
          knobs: knobs,
          clock: clock,
        ),
      },
    );

    // Only in the tree when there is something to finish. An app with nothing
    // to erase is not made to wait on finding that out — and a wrapper that
    // held every launch back would put the Ledger on screen after its first
    // arrival rather than before it.
    final home = erasureUnderWay == null
        ? signedInOrNot
        : _FinishingAnErasure(
            erasing: erasureUnderWay!,
            preferences: preferences,
            erasesFor: erasesFor,
            child: signedInOrNot,
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
          // Above the MaterialApp with the others, because Settings is a
          // pushed route: a route is a sibling of the screen that pushed it,
          // and this is the only place both of them can see.
          BlocProvider(
            create: (_) =>
                TradingAGuestForAnAccount(identity: signIn, erases: erasesFor),
          ),
          BlocProvider(
            create: (_) => SettingsCubit(
              preferences,
              from: Settings(
                theme: theme,
                language: language,
                homeCurrency: homeCurrency,
              ),
            ),
          ),
        ],
        // Above the MaterialApp, so every route the Navigator holds is under
        // one signed-in user's blocs rather than beside them, and so that a
        // Setting rebuilding the MaterialApp is not also a reason to build a
        // second set of Stores over the ones those blocs are reading.
        child: SignedInScope(
          storesFor: storesFor,
          model: model,
          knobs: knobs,
          clock: clock,
          child: BlocBuilder<SettingsCubit, Settings>(
            builder: (context, settings) => MaterialApp(
              // `onGenerateTitle` rather than `title`, because the name is an
              // ARB key and the delegate that reads it is installed by this
              // same MaterialApp.
              onGenerateTitle: (context) =>
                  AppLocalizations.of(context).appName,
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
                  ? LockGate(
                      lock: lock,
                      preferences: preferences,
                      child: child!,
                    )
                  : child!,
              home: home,
            ),
          ),
        ),
      ),
    );
  }
}

/// The first frame, before the app knows whether anybody is signed in. It has
/// nothing to show, so the words it carries are the ones a screen reader is
/// given rather than any a user reads.
/// A Ledger a guest asked to be rid of, and a phone that killed the app
/// before it was. The record of it is read once on launch and finished before
/// anything else is drawn, so the user lands where they meant to rather than
/// on half a Ledger they never asked to keep.
///
/// Silent on purpose: they confirmed a deletion and are about to see the
/// sign-in screen, which is what they asked for. Nothing here is worth
/// narrating.
///
/// Not done before `runApp`: an erasure runs over the network, and blocking
/// startup on it gives a guest on a bad connection a black screen with no way
/// past it.
class _FinishingAnErasure extends StatefulWidget {
  const _FinishingAnErasure({
    required this.erasing,
    required this.preferences,
    required this.erasesFor,
    required this.child,
  });

  /// The uid the record names. The only one that can be erased: the token
  /// that authorises it belongs to that account.
  final String erasing;

  final DevicePreferences preferences;
  final ErasesFor erasesFor;
  final Widget child;

  @override
  State<_FinishingAnErasure> createState() => _FinishingAnErasureState();
}

class _FinishingAnErasureState extends State<_FinishingAnErasure> {
  var _finished = false;

  /// The record is acted on once. The session can resolve before this mounts
  /// or after it, so both paths reach [_finish] and this is what stops the
  /// second one running it twice.
  var _started = false;

  @override
  void initState() {
    super.initState();
    // The session may already have resolved, in which case no change is
    // coming and the listener below would never fire.
    final session = context.read<SessionBloc>().state;
    if (session is! SessionUnknown) _finish(session);
  }

  /// Signed in as anybody but the uid in the record — or as nobody, which is
  /// what an interruption after the account was deleted looks like — there is
  /// nothing left to do but forget the record.
  Future<void> _finish(SessionState session) async {
    if (_started) return;
    _started = true;
    final erasing = widget.erasing;

    final signedIn = session is SignedIn && session.user.uid == erasing;
    try {
      if (signedIn) {
        await widget.erasesFor(erasing).erase();
      } else {
        await widget.preferences.forgetErasureUnderWay();
      }
    } catch (_) {
      // Left set, deliberately: the next launch tries again. The user is
      // shown their Ledger in the meantime, which is the truth — it is still
      // there.
    }
    if (mounted) setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return widget.child;

    return BlocConsumer<SessionBloc, SessionState>(
      // Once the session has resolved, the record can be acted on. Until
      // then there is nobody to act as.
      listenWhen: (_, state) => state is! SessionUnknown,
      listener: (context, state) => _finish(state),
      builder: (context, _) => const _Opening(),
    );
  }
}

class _Opening extends StatelessWidget {
  const _Opening();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: CircularProgressIndicator(
        semanticsLabel: AppLocalizations.of(context).openingWait,
      ),
    ),
  );
}
