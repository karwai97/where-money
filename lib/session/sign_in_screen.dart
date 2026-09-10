import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../a_form_of_rows.dart';
import '../l10n/app_localizations.dart';
import '../on_screen.dart';
import '../settings/themes.dart';
import 'receipt_mark.dart';
import 'session_bloc.dart';

/// The last screen before the Ledger: the launcher's receipt over the name and
/// the pitch, and the two ways in at the foot of the screen in the strip
/// Review's commit button wears — Google filled, guest outlined, because one
/// is what the screen is for and the other is the way round it.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key, required this.state});

  final SessionState state;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Expanded(
          // Centred in whatever the strip leaves, and scrolled rather than
          // clipped when the text is turned up far enough to outgrow it.
          //
          // The minimum height is said out loud because a
          // `SingleChildScrollView` lays its child out at whatever height it
          // asks for and aligns it at the top: without this the block sits
          // hard against the top of the screen at every text size, and the
          // `Center` inside it has nothing to centre in.
          child: LayoutBuilder(
            builder: (context, space) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: space.maxHeight),
                child: const Center(child: _Identity()),
              ),
            ),
          ),
        ),
        _WaysIn(state),
      ],
    ),
  );
}

/// The mark, the name and the pitch. Nothing here is a heading: the name is
/// the product's, not the screen's.
class _Identity extends StatelessWidget {
  const _Identity();

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ReceiptMark(),
          const SizedBox(height: 28),
          // The product's own name, which is the same word in every
          // language; both ARB files carry it.
          Text(
            words.appName,
            textAlign: TextAlign.center,
            style: atItsWeight(
              theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            words.signInTagline,
            textAlign: TextAlign.center,
            // `bodyMedium` is the one reading slot the theme does not mute,
            // and this is a supporting line — so it is coloured here, the way
            // `asARow` colours its hint.
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The strip. Nothing in it animates: each state is a different set of
/// children at held heights, so the strip only changes height when the failure
/// sentence appears.
class _WaysIn extends StatelessWidget {
  const _WaysIn(this.state);

  final SessionState state;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bloc = context.read<SessionBloc>();
    final signingIn = state is SigningIn;
    final failure = switch (state) {
      SignedOut(:final failure) => failure,
      _ => null,
    };

    return Foot(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          if (failure != null) _WhatWentWrong(words.signInFailed(failure)),
          // The spinner sits in this button's slot rather than beside it, at
          // the height the button was, so nothing under it moves.
          if (signingIn)
            SizedBox(
              height: 48,
              child: Center(
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    semanticsLabel: words.signInInFlight,
                  ),
                ),
              ),
            )
          else
            FilledButton(
              onPressed: () => bloc.add(const SignInRequested()),
              style: asTheOneAction(theme),
              child: Text(cased(words, words.signInWithGoogle)),
            ),
          OutlinedButton(
            // Closed while a sign-in is being tried, for the reason
            // [GuestRequested] gives.
            onPressed: signingIn
                ? null
                : () => bloc.add(const GuestRequested()),
            style: asTheWayRound(theme),
            child: Text(cased(words, words.signInAsGuest)),
          ),
        ],
      ),
    );
  }
}

/// What the phone said, transcribed. Over the buttons rather than under them,
/// because the app says things under or beside what they are about and the
/// buttons are what this is about.
class _WhatWentWrong extends StatelessWidget {
  const _WhatWentWrong(this.said);

  final String said;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      // Announced when it appears, so a screen reader is not left to hunt for
      // what changed. It is in colour and in position as well, so nothing
      // here is said in colour alone.
      liveRegion: true,
      child: Text(
        said,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}
