import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'session_bloc.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key, required this.state});

  final SessionState state;

  @override
  Widget build(BuildContext context) {
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
              Text(
                'where_money',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Photograph a receipt, put the phone away.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              if (state is SigningIn)
                const CircularProgressIndicator()
              else
                FilledButton(
                  onPressed: () =>
                      context.read<SessionBloc>().add(const SignInRequested()),
                  child: const Text('Continue with Google'),
                ),
              if (failure != null) ...[
                const SizedBox(height: 24),
                Text(
                  'Signing in did not work. $failure',
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
