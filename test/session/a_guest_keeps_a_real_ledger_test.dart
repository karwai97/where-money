import 'dart:typed_data';

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

  Future<void> open(WidgetTester tester, {String? erasureUnderWay}) async {
    await tester.pumpWidget(
      WhereMoneyApp(
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

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

  Future<void> tapOn(WidgetTester tester, Finder what) async {
    await tester.tap(what);
    await tester.pumpAndSettle();
  }

  /// For the taps that leave a spinner on screen. A spinner animates
  /// forever, so nothing settles while one is drawn — a dialog waiting over
  /// the row's spinner never would, and neither would the modal a deletion
  /// runs under.
  Future<void> tapAndWait(WidgetTester tester, Finder what) async {
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

  group('keeping it', () {
    testWidgets('a guest is offered a way to keep the Ledger, and told what '
        'happens if they do not', (tester) async {
      await open(tester);
      await continueAsGuest(tester);
      await openSettings(tester);

      expect(markSaying('Sign in to keep this ledger'), findsOneWidget);
      expect(
        find.text('This ledger lives on this phone only. Signing in keeps it.'),
        findsOneWidget,
      );
    });

    testWidgets('an account holder is not offered what they already have', (
      tester,
    ) async {
      signIn = FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai);

      await open(tester);
      await openSettings(tester);

      expect(markSaying('Sign in to keep this ledger'), findsNothing);
      expect(markSaying('Sign out'), findsOneWidget);
    });

    testWidgets('signing in keeps the Ledger, and the offer goes', (
      tester,
    ) async {
      await open(tester);
      await continueAsGuest(tester);
      await openSettings(tester);
      await tapOn(tester, markSaying('Sign in to keep this ledger'));

      expect(markSaying('Sign in to keep this ledger'), findsNothing);

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
      await tapOn(tester, markSaying('Sign in to keep this ledger'));

      expect(markSaying('Sign in to keep this ledger'), findsOneWidget);
      expect(find.textContaining('Bad state'), findsNothing);
    });

    testWidgets('a refused sign-in is said beside the row it was asked from, '
        'and the Ledger is untouched', (tester) async {
      signIn.refuseLink = StateError('no network');

      await open(tester);
      await continueAsGuest(tester);
      await openSettings(tester);
      await tapOn(tester, markSaying('Sign in to keep this ledger'));

      expect(find.textContaining('no network'), findsOneWidget);
      expect(markSaying('Sign in to keep this ledger'), findsOneWidget);
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
      await tapAndWait(tester, markSaying('Sign in to keep this ledger'));

      expect(
        find.textContaining('That account already has a ledger'),
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
      await tapAndWait(tester, markSaying('Sign in to keep this ledger'));
      await tapOn(tester, find.text('Keep it'));

      expect(markSaying('Sign in to keep this ledger'), findsOneWidget);
      expect(store.contents, [onTheLedger]);
      expect(signIn.deleted, isFalse);
    });

    testWidgets('confirmed, this Ledger goes and that account is signed into '
        'without being chosen twice', (tester) async {
      await open(tester);
      await continueAsGuest(tester);
      await openSettings(tester);
      await tapAndWait(tester, markSaying('Sign in to keep this ledger'));
      await tapAndWait(tester, find.text('Sign out'));
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

      expect(find.text('Sign out of this ledger?'), findsOneWidget);
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

      expect(find.text('Sign out of this ledger?'), findsNothing);
      expect(markSaying('Sign in to keep this ledger'), findsOneWidget);
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
      expect(markSaying('Sign in to keep this ledger'), findsOneWidget);
    });

    testWidgets('an account holder still leaves in one tap', (tester) async {
      signIn = FakeSignInGateway(alreadySignedIn: FakeSignInGateway.kai);

      await open(tester);
      await openSettings(tester);
      await tapOn(tester, markSaying('Sign out'));

      expect(find.text('Sign out of this ledger?'), findsNothing);
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

    testWidgets('that fails is left for the next launch', (tester) async {
      signIn = FakeSignInGateway(alreadySignedIn: FakeSignInGateway.guest);
      store.refuseErasing = StateError('no network');

      await open(tester, erasureUnderWay: FakeSignInGateway.guest.uid);

      expect(await preferences.erasureUnderWay(), FakeSignInGateway.guest.uid);
      // Shown their Ledger in the meantime, which is the truth: it is still
      // there.
      expect(find.text('Village Grocer'), findsWidgets);
    });
  });
}
