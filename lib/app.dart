import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import 'data/device_preferences.dart';
import 'data/stores.dart';
import 'ledger/ledger_screen.dart';
import 'lock/device_lock.dart';
import 'lock/lock_gate.dart';
import 'scan/model_gateway.dart';
import 'scan/photographer.dart';
import 'session/session_bloc.dart';
import 'session/sign_in_gateway.dart';
import 'session/sign_in_screen.dart';

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
    this.photograph,
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
    // Above the MaterialApp, so the lock and the Settings route reach these
    // without being handed down through every screen in between.
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<DeviceLock>.value(value: lock),
        RepositoryProvider<DevicePreferences>.value(value: preferences),
      ],
      child: BlocProvider(
        create: (_) => SessionBloc(signIn)..add(const SessionOpened()),
        child: MaterialApp(
          title: 'where_money',
          theme: ThemeData(useMaterial3: true),
          // The charts take their one hue from the scheme, so a phone in dark
          // mode needs a scheme built for a dark surface. Without this there
          // is no dark theme to be legible in.
          darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
          // Above the Navigator rather than inside `home`, so a phone locked
          // while an Expense was open covers that route too. There is nothing
          // to lock when nobody is signed in.
          builder: (context, child) =>
              context.watch<SessionBloc>().state is SignedIn
              ? LockGate(lock: lock, preferences: preferences, child: child!)
              : child!,
          home: BlocBuilder<SessionBloc, SessionState>(
            builder: (context, state) => switch (state) {
              SessionUnknown() => const _Opening(),
              SignedOut() || SigningIn() => SignInScreen(state: state),
              SignedIn(:final user) => LedgerScreen(
                // Keyed by uid so a second account never inherits the first
                // account's Ledger bloc.
                key: ValueKey(user.uid),
                uid: user.uid,
                stores: storesFor(user.uid),
                model: model,
                knobs: knobs,
                photograph:
                    photograph ??
                    (from) =>
                        photographWithDevice(from, longEdge: knobs.longEdge),
              ),
            },
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
