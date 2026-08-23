import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/ledger_store.dart';
import 'ledger/ledger_screen.dart';
import 'session/session_bloc.dart';
import 'session/sign_in_gateway.dart';
import 'session/sign_in_screen.dart';

/// A Ledger belongs to exactly one user, so the store is built from the uid
/// rather than told about it — which is all the app ever wants from signing in.
typedef LedgerFor = LedgerStore Function(String uid);

class WhereMoneyApp extends StatelessWidget {
  const WhereMoneyApp({
    super.key,
    required this.signIn,
    required this.ledgerFor,
  });

  final SignInGateway signIn;
  final LedgerFor ledgerFor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'where_money',
      theme: ThemeData(useMaterial3: true),
      home: BlocProvider(
        create: (_) => SessionBloc(signIn)..add(const SessionOpened()),
        child: BlocBuilder<SessionBloc, SessionState>(
          builder: (context, state) => switch (state) {
            SessionUnknown() => const _Opening(),
            SignedOut() || SigningIn() => SignInScreen(state: state),
            SignedIn(:final user) => LedgerScreen(
              // Keyed by uid so a second account never inherits the first
              // account's Ledger bloc.
              key: ValueKey(user.uid),
              store: ledgerFor(user.uid),
              debugWrites: kDebugMode,
            ),
          },
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
