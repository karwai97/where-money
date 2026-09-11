import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money/lock/device_lock.dart';
import 'package:where_money/session/sign_in_gateway.dart';
import 'package:where_money_core/where_money_core.dart';

import '../as_drawn.dart';
import '../fakes/every_picture_loads.dart';
import '../fakes/fake_device_lock.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';

void main() {
  late FakeDeviceLock lock;
  late InMemoryDevicePreferences preferences;
  late InMemoryLedgerStore store;

  setUp(() {
    lock = FakeDeviceLock();
    preferences = InMemoryDevicePreferences();
    store = InMemoryLedgerStore(seedLedger(around: DateTime(2026, 8, 23)));
    // The image cache outlives a test. Without this, the one test that lets a
    // picture load leaves it decoded for the test that is about a picture
    // that never arrives, and that test silently stops testing anything.
    imageCache.clear();
    imageCache.clearLiveImages();
  });

  Future<void> openSettings(
    WidgetTester tester, {
    SignedInUser who = FakeSignInGateway.kai,
  }) async {
    await tester.pumpWidget(
      WhereMoneyApp(
        signIn: FakeSignInGateway(alreadySignedIn: who),
        storesFor: (_) => store.stores,
        model: FakeModelGateway(),
        lock: lock,
        preferences: preferences,
        photograph: (_) async => null,
        clock: () => DateTime(2026, 8, 23),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

  testWidgets('the lock can be turned off, and the choice sticks', (
    tester,
  ) async {
    await openSettings(tester);

    // The switch rather than the words beside it: the label sits in the row's
    // own column now, not inside the control.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(await preferences.locksOnOpen(), isFalse);
  });

  testWidgets('a phone with no fingerprint says it will ask for the PIN', (
    tester,
  ) async {
    lock.available = LockAvailability.deviceCredential;

    await openSettings(tester);

    expect(find.textContaining('asks for your PIN'), findsOneWidget);
  });

  testWidgets('a phone with no screen lock says what to do about it', (
    tester,
  ) async {
    lock.available = LockAvailability.none;

    await openSettings(tester);

    expect(find.textContaining('no screen lock'), findsOneWidget);

    // Nothing to switch on: there is no question this phone could ask.
    await tester.tap(find.byType(Switch), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(await preferences.locksOnOpen(), isTrue);
  });

  testWidgets('an account holder is told whose Ledger this is', (tester) async {
    await openSettings(tester);

    expect(find.text('Kai'), findsOneWidget);
    expect(find.text('kai@example.com · Google'), findsOneWidget);
    // The disc says the same thing a second time and is decoration; the two
    // lines beside it are what a screen reader is given.
    expect(find.text('K'), findsOneWidget);
  });

  testWidgets('an account Google named nobody reads as its address', (
    tester,
  ) async {
    await openSettings(tester, who: FakeSignInGateway.nameless);

    // The address takes the first line rather than a made-up name, and the
    // line under it is left with the product name alone.
    expect(find.text('nameless@example.com'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.textContaining('nameless@example.com ·'), findsNothing);
  });

  testWidgets('an account with neither says the one thing there is to say', (
    tester,
  ) async {
    // Not a state Google sign-in produces, but both fields are nullable, and
    // the lane a nullable field opens is a lane somebody eventually lands in.
    await openSettings(tester, who: const SignedInUser(uid: 'anonymous-uid'));

    // On the first line rather than under a blank one, which is what a
    // fallback chain that ran out would otherwise draw. Said as where it sits
    // against the disc, because finding the word says nothing about which of
    // the two lines it landed on.
    expect(find.text('Google'), findsOneWidget);
    expect(
      tester.getRect(find.text('Google')).center.dy,
      closeTo(tester.getRect(theDisc).center.dy, 2),
      reason: 'it is under a blank first line rather than on one',
    );
    expect(find.text('Guest'), findsNothing);
  });

  testWidgets("an account's own picture takes the disc", (tester) async {
    await whileEveryPictureLoads(() async {
      await openSettings(tester, who: FakeSignInGateway.pictured);
      // Fetching and decoding are real asynchronous work off the frame loop,
      // which pumping frames does not advance. Without this the picture is
      // still in flight and the test would pin the fallback while claiming to
      // pin the picture.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      // The initials are what the disc holds when there is no picture. There
      // is one, so they are not drawn under it or beside it.
      expect(find.text('K'), findsNothing);
      // The lines say who this is; the disc never did.
      expect(find.text('Kai'), findsOneWidget);
    });
  });

  testWidgets('a picture that never arrives leaves the initials', (
    tester,
  ) async {
    // No `whileEveryPictureLoads`: the harness answers 400, which is exactly
    // the phone with no network that this fallback exists for.
    await openSettings(tester, who: FakeSignInGateway.pictured);

    expect(find.text('K'), findsOneWidget);
    expect(find.text('Kai'), findsOneWidget);
  });

  testWidgets('a guest has no picture to draw and keeps the figure', (
    tester,
  ) async {
    await whileEveryPictureLoads(() async {
      await openSettings(tester, who: FakeSignInGateway.guest);

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.text('Guest'), findsOneWidget);
    });
  });
}
