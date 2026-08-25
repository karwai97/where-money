import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/data/device_preferences.dart';
import 'package:where_money/lock/device_lock.dart';
import 'package:where_money/lock/lock_bloc.dart';

import '../fakes/fake_device_lock.dart';
import '../fakes/in_memory_device_preferences.dart';

void main() {
  late FakeDeviceLock lock;
  late DevicePreferences preferences;

  setUp(() {
    lock = FakeDeviceLock();
    preferences = InMemoryDevicePreferences();
  });

  LockBloc open() => LockBloc(lock, preferences);

  final nineOClock = DateTime(2026, 8, 25, 9);

  blocTest<LockBloc, LockState>(
    'opening the app asks for a fingerprint before showing anything',
    build: open,
    act: (bloc) => bloc.add(const LockOpened()),
    expect: () => [const Locked(), const Unlocked()],
  );

  blocTest<LockBloc, LockState>(
    'a phone with no fingerprint enrolled is still asked, and asks for the PIN',
    build: () {
      lock.available = LockAvailability.deviceCredential;
      return open();
    },
    act: (bloc) => bloc.add(const LockOpened()),
    expect: () => [const Locked(), const Unlocked()],
  );

  blocTest<LockBloc, LockState>(
    'a phone with no screen lock at all opens the Ledger rather than sealing it',
    build: () {
      lock
        ..available = LockAvailability.none
        // Would refuse if it were asked, so reaching Unlocked can only mean
        // it never was.
        ..answer = Unlocking.refused;
      return open();
    },
    act: (bloc) => bloc.add(const LockOpened()),
    expect: () => [const Unlocked()],
  );

  blocTest<LockBloc, LockState>(
    'a screen lock removed after the setting was turned on does not strand the user',
    build: () {
      lock.answer = Unlocking.unavailable;
      return open();
    },
    act: (bloc) => bloc.add(const LockOpened()),
    expect: () => [const Locked(), const Unlocked()],
  );

  blocTest<LockBloc, LockState>(
    'a wrong finger leaves the app locked, with something to try again',
    build: () {
      lock.answer = Unlocking.refused;
      return open();
    },
    act: (bloc) => bloc.add(const LockOpened()),
    expect: () => [const Locked(), const Locked(refused: true)],
  );

  blocTest<LockBloc, LockState>(
    'trying again after a refusal unlocks',
    build: () {
      lock.answer = Unlocking.refused;
      return open();
    },
    act: (bloc) async {
      bloc.add(const LockOpened());
      await Future<void>.delayed(Duration.zero);
      lock.answer = Unlocking.unlocked;
      bloc.add(const UnlockRequested());
    },
    skip: 2,
    expect: () => [const Unlocked()],
  );

  blocTest<LockBloc, LockState>(
    'the user having turned the lock off opens straight into the Ledger',
    build: () {
      preferences = InMemoryDevicePreferences(locksOnOpen: false);
      lock.answer = Unlocking.refused;
      return open();
    },
    act: (bloc) => bloc.add(const LockOpened()),
    expect: () => [const Unlocked()],
  );

  blocTest<LockBloc, LockState>(
    'answering a message for ten seconds does not cost a fingerprint',
    build: open,
    act: (bloc) async {
      bloc.add(const LockOpened());
      await Future<void>.delayed(Duration.zero);
      // Asking again would now be refused, so staying Unlocked is the claim.
      lock.answer = Unlocking.refused;
      bloc.add(WentAway(nineOClock));
      bloc.add(CameBack(nineOClock.add(const Duration(seconds: 10))));
    },
    skip: 2,
    expect: () => <LockState>[],
  );

  blocTest<LockBloc, LockState>(
    'a phone put down for ten minutes is locked again on picking it up',
    build: open,
    act: (bloc) async {
      bloc.add(const LockOpened());
      await Future<void>.delayed(Duration.zero);
      bloc.add(WentAway(nineOClock));
      bloc.add(CameBack(nineOClock.add(const Duration(minutes: 10))));
    },
    skip: 2,
    expect: () => [const Locked(), const Unlocked()],
  );

  blocTest<LockBloc, LockState>(
    'the second going-away Android reports on the way back is not the moment '
    'the user left',
    build: open,
    act: (bloc) async {
      bloc.add(const LockOpened());
      await Future<void>.delayed(Duration.zero);
      bloc.add(WentAway(nineOClock));
      // Android says `hidden` a second time on its way to `resumed`. Taking
      // that as the moment they left would make ten minutes look instant.
      final back = nineOClock.add(const Duration(minutes: 10));
      bloc.add(WentAway(back));
      bloc.add(CameBack(back));
    },
    skip: 2,
    expect: () => [const Locked(), const Unlocked()],
  );

  blocTest<LockBloc, LockState>(
    'coming back to an app the user never left is not a lock',
    build: open,
    act: (bloc) async {
      bloc.add(const LockOpened());
      await Future<void>.delayed(Duration.zero);
      bloc.add(CameBack(nineOClock.add(const Duration(hours: 3))));
    },
    skip: 2,
    expect: () => <LockState>[],
  );

  blocTest<LockBloc, LockState>(
    'a platform that is not there at all opens the Ledger rather than hanging',
    build: () {
      lock.broken = MissingPluginException('local_auth');
      return open();
    },
    act: (bloc) => bloc.add(const LockOpened()),
    expect: () => [const Unlocked()],
  );

  blocTest<LockBloc, LockState>(
    'turning the lock off in settings means putting the phone down costs nothing',
    build: open,
    act: (bloc) async {
      bloc.add(const LockOpened());
      await Future<void>.delayed(Duration.zero);
      await preferences.setLocksOnOpen(false);
      lock.answer = Unlocking.refused;
      bloc.add(WentAway(nineOClock));
      bloc.add(CameBack(nineOClock.add(const Duration(minutes: 10))));
    },
    skip: 2,
    expect: () => <LockState>[],
  );
}
