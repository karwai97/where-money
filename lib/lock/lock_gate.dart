import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/device_preferences.dart';
import '../l10n/app_localizations.dart';
import 'device_lock.dart';
import 'lock_bloc.dart';
import 'lock_screen.dart';

/// Sits above the Navigator rather than beside the Ledger, so that a phone
/// locked while the user was reading an Expense covers that too. Below the
/// Navigator the lock would be a screen the user had already walked past.
class LockGate extends StatefulWidget {
  const LockGate({
    super.key,
    required this.lock,
    required this.preferences,
    required this.child,
  });

  final DeviceLock lock;
  final DevicePreferences preferences;
  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  late final LockBloc _lock = LockBloc(
    widget.lock,
    widget.preferences,
    () => _reason,
  )..add(const LockOpened());

  /// What the phone's own prompt will be told to say. Read here rather than in
  /// `build` because this is the callback the Language change arrives on, and
  /// it runs before the first frame — so the bloc, which is not built until
  /// then, can never read this unset.
  late String _reason;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reason = AppLocalizations.of(context).lockReason;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lock.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final at = DateTime.now();
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _lock.add(WentAway(at));
      case AppLifecycleState.resumed:
        _lock.add(CameBack(at));
      case _:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _lock,
      child: BlocBuilder<LockBloc, LockState>(
        builder: (context, state) {
          final locked = state is! Unlocked;
          return Stack(
            children: [
              // Kept mounted under the lock, so unlocking puts the user back
              // where they were rather than at the top of the Ledger. Covered
              // opaquely and taken out of the semantics tree meanwhile, so a
              // screen reader cannot read out what the screen will not show.
              ExcludeSemantics(
                excluding: locked,
                child: AbsorbPointer(absorbing: locked, child: widget.child),
              ),
              if (locked) Positioned.fill(child: LockScreen(state: state)),
            ],
          );
        },
      ),
    );
  }
}
