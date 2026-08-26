import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../session/session_bloc.dart';
import 'lock_bloc.dart';

/// What is on screen instead of the Ledger while the app is locked. Opaque on
/// purpose: it covers whatever the user was reading when they put the phone
/// down, rather than replacing it.
class LockScreen extends StatelessWidget {
  const LockScreen({super.key, required this.state});

  final LockState state;

  @override
  Widget build(BuildContext context) {
    final refused = switch (state) {
      Locked(:final refused) => refused,
      _ => false,
    };

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'where_money is locked',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Your spending is on this phone. Unlock it to read it.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              if (refused) ...[
                Text(
                  'That did not unlock it.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      context.read<LockBloc>().add(const UnlockRequested()),
                  child: const Text('Unlock'),
                ),
              ] else
                const CircularProgressIndicator(),
              const SizedBox(height: 24),
              // The way out for someone whose fingerprint has stopped being
              // recognised. It gives up the session rather than the data,
              // which is the only trade this screen can honestly offer.
              TextButton(
                onPressed: () =>
                    context.read<SessionBloc>().add(const SignOutRequested()),
                child: const Text('Sign out instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
