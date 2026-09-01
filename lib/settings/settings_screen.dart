import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../data/device_preferences.dart';
import '../lock/device_lock.dart';
import '../session/session_bloc.dart';
import 'how_scans_are_read.dart';
import 'settings_cubit.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.knobs});

  /// Handed down rather than looked up: knobs are plain values everywhere else
  /// they go, and this is the last place they land.
  final Knobs knobs;

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
    final availability = _availability;
    final locks = _locks;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _ThemeChoice(),
          if (availability == null || locks == null)
            const ListTile(title: Text('Lock where_money'))
          else
            SwitchListTile(
              title: const Text('Lock where_money'),
              subtitle: Text(switch (availability) {
                LockAvailability.biometrics =>
                  'Ask for your fingerprint or face, or this phone\u2019s PIN, '
                      'before showing your spending.',
                LockAvailability.deviceCredential =>
                  'No fingerprint is set up on this phone, so it asks for your '
                      'PIN before showing your spending.',
                LockAvailability.none =>
                  'This phone has no screen lock. Set one in Android settings '
                      'to use this.',
              }),
              // A phone with nothing to ask cannot make the promise, and a
              // switch that says it does would be a lie.
              value: locks && availability != LockAvailability.none,
              onChanged: availability == LockAvailability.none ? null : _want,
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: _signOut,
          ),
          // Below what the user came here for. This half is for whoever is
          // diagnosing a Scan, not for whoever is using the app.
          const Divider(),
          HowScansAreRead(knobs: widget.knobs),
          const Divider(),
          const WhatReviewHadToCorrect(),
        ],
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice();

  @override
  Widget build(BuildContext context) => ListTile(
    title: const Text('Theme'),
    trailing: DropdownButton<ThemeMode>(
      value: context.watch<SettingsCubit>().state.theme,
      onChanged: (theme) =>
          context.read<SettingsCubit>().chooseTheme(theme ?? ThemeMode.system),
      items: const [
        DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
        DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
        DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
      ],
    ),
  );
}
