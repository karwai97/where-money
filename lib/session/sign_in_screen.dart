import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/app_localizations.dart';
import 'session_bloc.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key, required this.state});

  final SessionState state;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final failure = switch (state) {
      SignedOut(:final failure) => failure,
      _ => null,
    };

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The product's own name, which is the same word in every
              // language; both ARB files carry it.
              Text(
                words.appName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                words.signInTagline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              if (state is SigningIn)
                CircularProgressIndicator(semanticsLabel: words.signInInFlight)
              else
                FilledButton(
                  onPressed: () =>
                      context.read<SessionBloc>().add(const SignInRequested()),
                  child: Text(words.signInWithGoogle),
                ),
              if (failure != null) ...[
                const SizedBox(height: 24),
                Text(
                  words.signInFailed(failure),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
