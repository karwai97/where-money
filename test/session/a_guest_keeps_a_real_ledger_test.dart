import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/app.dart';
import 'package:where_money/session/sign_in_gateway.dart';
import 'package:where_money_core/where_money_core.dart';

import '../as_drawn.dart';
import '../fakes/fake_device_lock.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';

/// A guest is an anonymous account with a real Ledger behind it (ADR-0010),
/// which is what makes both of its exits worth pinning: keeping the Ledger by
/// putting an account behind it, and leaving, which deletes it.
///
/// Driven through the whole app rather than through the cubit that runs the
/// flows. What matters is what the screen offers and what is left afterwards;
/// that a cubit exists is not a fact any of these tests should know.
void main() {
  late FakeSignInGateway signIn;
  late InMemoryLedgerStore store;
  late InMemoryDevicePreferences preferences;

  final onTheLedger = Expense(
    id: 'seed-1',
    merchant: 'Village Grocer',
    date: DateTime(2026, 8, 21),
    currency: 'MYR',
    total: 42.10,
    category: 'groceries',
    lineItems: const [],
    source: ExpenseSource.scanned,
    needsReview: false,
  );

  setUp(() {
    signIn = FakeSignInGateway();
    store = InMemoryLedgerStore([onTheLedger]);
    preferences = InMemoryDevicePreferences(locksOnOpen: false);
  });

  Future<void> open(
    WidgetTester tester, {
    String? erasureUnderWay,
    String language = 'en',
  }) async {
    await tester.pumpWidget(
      WhereMoneyApp(
        language: language,
        signIn: signIn,
        storesFor: (_) => store.stores,
        model: FakeModelGateway(),
        lock: FakeDeviceLock(),
        preferences: preferences,
        photograph: (_) async => null,
        erasureUnderWay: erasureUnderWay,
        clock: () => DateTime(2026, 8, 23),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> continueAsGuest(WidgetTester tester) async {
    await tester.tap(markSaying('Continue as guest'));
    await tester.pumpAndSettle();
  }

  /// The app opened again from cold, carrying whatever the phone now
  /// remembers. Pumping the app a second time on its own would keep the
  /// element tree and the pushed Settings route with it, which is not what a
  /// launch is; the blank frame in between is what makes it one.
  Future<void> relaunch(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await open(tester, erasureUnderWay: await preferences.erasureUnderWay());
  }

  Future<void> openSettings(
    WidgetTester tester, {
    String named = 'Settings',
  }) async {
    await tester.tap(find.byTooltip(named));
    await tester.pumpAndSettle();
  }

  /// Scrolled to before it is tapped. The foot of Settings sits below the
  /// fold once a guest's row is on it, and a tap dispatched at an offset
  /// outside the viewport lands on nothing at all rather than failing.
  Future<void> tapOn(WidgetTester tester, Finder what) async {
    await tester.ensureVisible(what);
    await tester.pumpAndSettle();
    await tester.tap(what);
    await tester.pumpAndSettle();
  }

  /// For the taps that leave a spinner on screen. A spinner animates
  /// forever, so nothing settles while one is drawn — a dialog waiting over
  /// the row's spinner never would, and neither would the modal a deletion
  /// runs under.
  Future<void> tapAndWait(WidgetTester tester, Finder what) async {
    await tester.ensureVisible(what);
    await tester.pump();
    await tester.tap(what);
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('the way in', () {
    testWidgets('a guest reaches the Ledger, and it is a real one', (
      tester,
    ) async {
      await open(tester);
      await continueAsGuest(tester);

      expect(markSaying('Ledger'), findsOneWidget);
      expect(find.text('Village Grocer'), findsWidgets);
    });

    testWidgets('a guest commits an Expense like anyone else', (tester) async {
      store = InMemoryLedgerStore();

      await open(tester);
      await continueAsGuest(tester);
      await store.add(onTheLedger);
      await tester.pumpAndSettle();

      // Nothing about the Ledger is withheld from a guest: the uid is real,
      // so the seam an Expense is written through is the same one.
      expect(find.text('Village Grocer'), findsWidgets);
      expect(store.contents, [onTheLedger]);
    });

    testWidgets('a guest sign-in that failed is explained, and both ways in '
        'come back', (tester) async {
      signIn.refuseGuest = StateError('no network');

      await open(tester);
      await continueAsGuest(tester);

      expect(find.textContaining('no network'), findsOneWidget);
      expect(markSaying('Continue as guest'), findsOneWidget);
      expect(markSaying('Continue with Google'), findsOneWidget);
    });
  });

  group('in Chinese', () {
    testWidgets('a guest is offered the row and warned in their own '
        'language', (tester) async {
      await open(tester, language: 'zh');
      await tester.tap(find.text('以访客身份继续'));
      await tester.pumpAndSettle();
      await openSettings(tester, named: '设置');

      // `cased` is a no-op for zh, so the row reads as it is written.
      expect(find.text('登录以保留此账本'), findsOneWidget);
      expect(find.text('此账本没有账号，会随这部手机一起消失。登录即可保留。'), findsOneWidget);

      await tapOn(tester, find.text('退出登录'));
      expect(find.text('退出此账本？'), findsOneWidget);
      expect(find.text('你的账本及其收据将被删除，且无法恢复。'), findsOneWidget);
      // The moment a user is warned about losing data is the worst possible
      // moment for the app to switch language.
      expect(find.textContaining('cannot be recovered'), findsNothing);
    });
  });

  group('keeping it', () {
    testWidgets('a guest is offered a way to keep the Ledger, and told what '
        'happens if they do not', (tester) async {
      await open(tester);
      await continueAsGuest(tester);
      await openSettings(tester);

      expect(markSaying('Sign in to keep this Ledger'), findsOneWidget);
      expect(
        find.text(
          'This Ledger has no account behind it, so it goes when this phone '
          'does. Signing in keeps it.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an account holder is not offered what they already have', (
      tester,
    ) async {
      signIn = FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai);

      await open(tester);
      await openSettings(tester);

      expect(markSaying('Sign in to keep this Ledger'), findsNothing);
      expect(markSaying('Sign out'), findsOneWidget);
    });

    testWidgets('signing in keeps the Ledger, and the offer goes', (
      tester,
    ) async {
      await open(tester);
      await continueAsGuest(tester);
      await openSettings(tester);
      await tapOn(tester, markSaying('Sign in to keep this Ledger'));

      expect(markSaying('Sign in to keep this Ledger'), findsNothing);

      // Nothing moved: the uid did not change, so neither did the Ledger.
      await tapOn(tester, find.byTooltip('Back'));
      expect(find.text('Village Grocer'), findsWidgets);
    });

    testWidgets('a closed account picker says nothing and changes nothing', (
      tester,
    ) async {
      signIn.refuseLink = const SignInAbandoned();

      await open(tester);
      await continueAsGuest(tester);
      await openSettings(tester);
      await tapOn(tester, markSaying('Sign in to keep this Ledger'));

      expect(markSaying('Sign in to keep this Ledger'), findsOneWidget);
      expect(find.textContaining('Bad state'), findsNothing);
    });

    testWidgets('a refused sign-in is said beside the row it was asked from, '
        'and the Ledger is untouched', (tester) async {
      signIn.refuseLink = StateError('no network');

      await open(tester);
      await continueAsGuest(tester);
      await openSettings(tester);
      await tapOn(tester, markSaying('Sign in to keep this Ledger'));

      expect(find.textContaining('no network'), findsOneWidget);
      expect(markSaying('Sign in to keep this Ledger'), findsOneWidget);
      expect(store.contents, [onTheLedger]);
      expect(signIn.deleted, isFalse);
    });
  });

  group('an account that already has a Ledger', () {
    setUp(() => signIn.collides = true);

    testWidgets('is said before anything is deleted', (tester) async {
      await open(tester);
      await continueAsGuest(tester);
      await openSettings(tester);
      await tapAndWait(tester, markSaying('Sign in to keep this Ledger'));

      expect(
        find.textContaining('That account already has a Ledger'),
        findsOneWidget,
      );
      expect(store.contents, [onTheLedger]);
    });

    testWidgets('declined, the guest keeps everything they had', (
      tester,
    ) async {
      await open(tester);
      await continueAsGuest(tester);
      await openSettings(tester);
      await tapAndWait(tester, markSaying('Sign in to keep this Ledger'));
      // Declining leaves the row's spinner to stop on its own, so this
      // cannot settle until the cubit is back at rest.
      await tapAndWait(tester, find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(markSaying('Sign in to keep this Ledger'), findsOneWidget);
      expect(store.contents, [onTheLedger]);
      expect(signIn.deleted, isFalse);
    });

    testWidgets('confirmed, this Ledger goes and that account is signed into '
        'without being chosen twice', (tester) async {
      await open(tester);
      await continueAsGuest(tester);
      await openSettings(tester);
      await tapAndWait(tester, markSaying('Sign in to keep this Ledger'));
      // "Sign in", not "Sign out": this dialog signs the user in to the
      // other account, and the button has to say what it does.
      await tapAndWait(tester, find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(store.contents, isEmpty);
      expect(signIn.deleted, isTrue);
      expect(signIn.signedInWith, FakeSignInGateway.theOtherAccount);
    });
  });

  group('leaving', () {
    testWidgets('a guest is asked first, and told the Ledger goes with them', (
      tester,
    ) async {
      await open(tester);
      await continueAsGuest(tester);
      await openSettings(tester);
      await tapOn(tester, markSaying('Sign out'));

      expect(find.text('Sign out of this Ledger?'), findsOneWidget);
      expect(find.textContaining('cannot be recovered'), findsOneWidget);
      expect(store.contents, [onTheLedger]);
    });

    testWidgets('declining leaves them exactly where they were', (
      tester,
    ) async {
      await open(tester);
      await continueAsGuest(tester);
      await openSettings(tester);
      await tapOn(tester, markSaying('Sign out'));
      await tapOn(tester, find.text('Keep it'));

      expect(find.text('Sign out of this Ledger?'), findsNothing);
      expect(markSaying('Sign in to keep this Ledger'), findsOneWidget);
      expect(store.contents, [onTheLedger]);
      expect(signIn.deleted, isFalse);
    });

    testWidgets('confirming erases the Ledger, the Scans and the account', (
      tester,
    ) async {
      await store.capture(Uint8List.fromList([1, 2, 3]));

      await open(tester);
      await continueAsGuest(tester);
      await openSettings(tester);
      await tapOn(tester, markSaying('Sign out'));
      await tapAndWait(tester, find.textContaining('Sign out').last);
      await tester.pumpAndSettle();

      expect(store.contents, isEmpty);
      expect(store.waiting, isEmpty);
      expect(signIn.deleted, isTrue);
      expect(preferences.forgotten, contains(FakeSignInGateway.guest.uid));
      expect(markSaying('Continue with Google'), findsOneWidget);
    });

    testWidgets('a refused erasure keeps them signed in and says why', (
      tester,
    ) async {
      store.refuseErasing = StateError('no network');

      await open(tester);
      await continueAsGuest(tester);
      await openSettings(tester);
      await tapOn(tester, markSaying('Sign out'));
      await tapAndWait(tester, find.textContaining('Sign out').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('no network'), findsOneWidget);
      expect(store.contents, [onTheLedger]);
      expect(signIn.deleted, isFalse);
      // Still theirs to try again from, which is the whole reason a failed
      // erasure does not sign anybody out.
      expect(markSaying('Sign in to keep this Ledger'), findsOneWidget);
    });

    testWidgets('an account holder still leaves in one tap', (tester) async {
      signIn = FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai);

      await open(tester);
      await openSettings(tester);
      await tapOn(tester, markSaying('Sign out'));

      expect(find.text('Sign out of this Ledger?'), findsNothing);
      expect(markSaying('Continue with Google'), findsOneWidget);
      // Their Ledger waits for them. Nothing was erased on the way out.
      expect(store.contents, [onTheLedger]);
    });
  });

  group('an erasure the phone interrupted', () {
    testWidgets('is finished before the app draws anything else', (
      tester,
    ) async {
      signIn = FakeSignInGateway(alreadySignedIn: FakeSignInGateway.guest);

      await open(tester, erasureUnderWay: FakeSignInGateway.guest.uid);

      expect(store.contents, isEmpty);
      expect(signIn.deleted, isTrue);
      expect(markSaying('Continue with Google'), findsOneWidget);
      expect(find.text('Village Grocer'), findsNothing);
    });

    testWidgets('naming a uid nobody is signed in as is simply forgotten', (
      tester,
    ) async {
      signIn = FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai);

      await open(tester, erasureUnderWay: 'a-uid-that-is-already-gone');

      expect(await preferences.erasureUnderWay(), isNull);
      // Kai's Ledger is not somebody else's to erase.
      expect(store.contents, [onTheLedger]);
      expect(find.text('Village Grocer'), findsWidgets);
    });

    testWidgets('is never resumed against a Ledger the guest went on to keep', (
      tester,
    ) async {
      // The sequence that makes this the worst bug in the feature: an
      // erasure is refused, so the user stays a guest and is told; they then
      // keep the Ledger by signing in, which leaves the uid exactly as it
      // was. A record matched on uid alone would erase, on the next launch,
      // the Ledger they just signed in to save.
      store.refuseErasing = StateError('no network');

      await open(tester);
      await continueAsGuest(tester);
      await openSettings(tester);
      await tapOn(tester, markSaying('Sign out'));
      await tapAndWait(tester, find.textContaining('Sign out').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('no network'), findsOneWidget);

      store.refuseErasing = null;
      await tapOn(tester, markSaying('Sign in to keep this Ledger'));
      expect(markSaying('Sign in to keep this Ledger'), findsNothing);

      await relaunch(tester);

      expect(store.contents, [onTheLedger]);
      expect(find.text('Village Grocer'), findsWidgets);
    });

    testWidgets('that is refused does not arm the launch after it', (
      tester,
    ) async {
      signIn = FakeSignInGateway(alreadySignedIn: FakeSignInGateway.guest);
      store.refuseErasing = StateError('no network');

      await open(tester, erasureUnderWay: FakeSignInGateway.guest.uid);

      // The record survives the app being killed, which is what it is for,
      // and not a refusal — this code was still running and does know the
      // outcome. Left set, it would delete a Ledger on some later launch
      // without asking again, which is not something to do quietly.
      expect(await preferences.erasureUnderWay(), isNull);
      // Shown their Ledger in the meantime, which is the truth: it is still
      // there, and signing out again is how they ask a second time.
      expect(find.text('Village Grocer'), findsWidgets);
    });
  });
}
