import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../clock.dart';
import '../data/device_preferences.dart';
import '../data/receipt_store.dart';
import '../data/stores.dart';
import '../ledger/ledger_bloc.dart';
import '../ledger/photos_stayed_behind.dart';
import '../review/review_bloc.dart';
import '../scan/inbox_bloc.dart';
import '../scan/model_gateway.dart';
import '../session/session_bloc.dart';
import '../settings/settings_cubit.dart';

/// Everything one signed-in user's screens read, held above the `MaterialApp`
/// and so above the Navigator. A pushed route is a sibling of the route it was
/// pushed from, not a child of it, so anything provided inside a screen is out
/// of reach of every screen that screen opens. These four are provided here
/// instead, and the routes below simply find them.
///
/// Above the `MaterialApp` rather than inside its `builder`, which is where
/// [LockGate] sits for the same "above the Navigator" reason. The difference is
/// that `builder` runs again for every Setting, and [storesFor] must not: a
/// second set of Stores built over the ones the blocs are already reading is
/// the bug the composition in `app.dart` has always been arranged to avoid. Up
/// here the session is the only thing that rebuilds it.
///
/// The cost of being above the `MaterialApp` is that there is no
/// `AppLocalizations` in scope. Nothing here needs one: the blocs are wordless,
/// and there are tests that say so.
class SignedInScope extends StatelessWidget {
  const SignedInScope({
    super.key,
    required this.storesFor,
    required this.model,
    required this.knobs,
    required this.clock,
    required this.child,
  });

  /// All three seams are built from the uid rather than told about it, which is
  /// the whole of what this scope wants from signing in.
  final Stores Function(String uid) storesFor;

  final ModelGateway model;
  final Knobs knobs;
  final Clock clock;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The uid alone, rather than the session it sits in: a guest keeping
    // their Ledger keeps their uid and changes everything else about the user
    // (ADR-0010), and watching the whole state would answer that by building
    // a second set of Stores over the ones the blocs are already reading.
    // Nothing in this scope is about the user beyond the uid.
    final uid = context.select<SessionBloc, String?>((session) {
      final state = session.state;
      return state is SignedIn ? state.user.uid : null;
    });
    // Nobody to build them for. The sign-in screen reads none of these, and a
    // Ledger with no uid is not a thing.
    if (uid == null) return child;

    final stores = storesFor(uid);
    // Read once, for the blocs that are about to be built. After this the
    // Setting reaches them as events rather than as a rebuild — see
    // [_FollowsTheLanguage].
    final settings = context.read<SettingsCubit>().state;
    // Held rather than looked up later: what remembers the allowance is called
    // from a bloc long after the element that found it may have gone.
    final preferences = context.read<DevicePreferences>();
    final language = settings.language;
    final homeCurrency = settings.homeCurrency;

    return MultiBlocProvider(
      // Keyed by uid so a second account never inherits the first account's
      // blocs. This used to key `LedgerScreen`, which no longer holds anything
      // worth throwing away.
      key: ValueKey(uid),
      providers: [
        // The Receipt is a file on this phone rather than anything the
        // Ledger's states carry, so its seam has to be reachable from the
        // Expense a user opens.
        RepositoryProvider<ReceiptStore>.value(value: stores.receipts),
        BlocProvider(
          create: (_) => LedgerBloc(
            stores.ledger,
            model,
            language: language,
            homeCurrency: homeCurrency,
            now: clock(),
          )..add(const LedgerOpened()),
        ),
        // Held above the Review route, so leaving Review and coming back finds
        // the work still there.
        BlocProvider(
          create: (_) => ReviewBloc(
            stores.ledger,
            stores.scans,
            stores.receipts,
            clock: clock,
            homeCurrency: homeCurrency,
          ),
        ),
        BlocProvider(
          create: (_) => InboxBloc(
            stores.scans,
            model,
            knobs: knobs,
            language: language,
            // Bound to the account here, because the bloc is wordless about
            // who is signed in and the allowance is not.
            remembers: (allowance) =>
                preferences.rememberScanAllowance(uid, allowance),
          )..add(const InboxOpened()),
        ),
        BlocProvider(
          create: (_) => PhotosStayedBehind(stores.receipts, preferences, uid),
        ),
      ],
      child: _FollowsTheSettings(child: _LearnsItsHomeCurrency(child: child)),
    );
  }
}

/// Hands a Setting to the blocs that read it. They are keyed by the user
/// rather than by the Setting on purpose: re-keying would drop a loaded Ledger
/// and an Inbox mid-Scan because somebody changed a preference. So the Setting
/// arrives as an event, and each bloc decides what it costs.
class _FollowsTheSettings extends StatelessWidget {
  const _FollowsTheSettings({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<SettingsCubit, Settings>(
        listenWhen: (before, after) => before.language != after.language,
        listener: (context, settings) {
          context.read<LedgerBloc>().add(LanguageChanged(settings.language));
          context.read<InboxBloc>().add(
            InboxLanguageChanged(settings.language),
          );
        },
      ),
      BlocListener<SettingsCubit, Settings>(
        listenWhen: (before, after) =>
            before.homeCurrency != after.homeCurrency,
        listener: (context, settings) {
          final currency = settings.homeCurrency;
          if (currency == null) return;
          context.read<LedgerBloc>().add(HomeCurrencyChanged(currency));
          context.read<ReviewBloc>().add(ReviewHomeCurrencyChanged(currency));
        },
      ),
    ],
    child: child,
  );
}

/// The other direction: the first Expense saying what this Ledger's money is.
/// Here rather than on a screen, because the Ledger can arrive while the user
/// is anywhere in the app, and a Setting learned only when the charts happen
/// to be open is one the user has to go and find.
///
/// The oldest Expense, which on an ordinary Ledger is the only one. A Ledger
/// restored onto a new phone arrives full with the preference unset, and the
/// first thing that user ever spent is still the right answer.
class _LearnsItsHomeCurrency extends StatelessWidget {
  const _LearnsItsHomeCurrency({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => BlocListener<LedgerBloc, LedgerState>(
    listener: (context, state) {
      if (state is! LedgerWithoutHomeCurrency) return;
      final learned = learnableCurrency(state.expenses);
      if (learned == null) return;
      context.read<SettingsCubit>().learnHomeCurrency(learned);
    },
    child: child,
  );
}
