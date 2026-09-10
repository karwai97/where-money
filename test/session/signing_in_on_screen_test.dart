import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/a_form_of_rows.dart';
import 'package:where_money/app.dart';
import 'package:where_money/session/receipt_mark.dart';

import '../as_drawn.dart';
import '../fakes/fake_device_lock.dart';
import '../fakes/fake_model_gateway.dart';
import '../fakes/fake_sign_in_gateway.dart';
import '../fakes/in_memory_device_preferences.dart';
import '../fakes/in_memory_ledger_store.dart';

/// The sign-in screen drawn in Graphite rather than in Material's defaults:
/// the launcher's receipt over the name and the pitch, and the two ways in at
/// the foot of the screen in the strip Review's commit button already uses,
/// ranked by shape.
///
/// What the screen says and does in each state is `app_test.dart` and
/// `signing_in_speaks_chinese_test.dart`. This file is about how it is drawn,
/// which is the only thing the redraw could have broken.
void main() {
  /// The canvas's reference phone, which is wider than the suite's usual 390:
  /// the strip's buttons are full width on both and nothing here is designed
  /// to a breakpoint.
  const phone = Size(412, 915);

  late FakeSignInGateway signIn;

  setUp(() => signIn = FakeSignInGateway());

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view
      ..physicalSize = phone
      ..devicePixelRatio = 1;

    await tester.pumpWidget(
      WhereMoneyApp(
        lock: FakeDeviceLock(),
        preferences: InMemoryDevicePreferences(locksOnOpen: false),
        signIn: signIn,
        storesFor: (_) => InMemoryLedgerStore().stores,
        model: FakeModelGateway(),
        photograph: (_) async => null,
        clock: () => DateTime(2026, 8, 23),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Holds a sign-in in flight, so the screen can be read while it waits. A
  /// spinner animates forever, so nothing on this screen settles once it is
  /// up.
  Future<void> holdTheSignIn(WidgetTester tester, Finder tapping) async {
    final held = Completer<void>();
    signIn.holds = held;
    addTearDown(() {
      if (!held.isCompleted) held.complete();
    });

    await tester.tap(tapping);
    await tester.pump();
  }

  Finder theGoogleButton() =>
      find.widgetWithText(FilledButton, 'CONTINUE WITH GOOGLE');

  Finder theGuestButton() =>
      find.widgetWithText(OutlinedButton, 'CONTINUE AS GUEST');

  testWidgets('the receipt sits over the name and the pitch', (tester) async {
    await open(tester);

    expect(find.byType(ReceiptMark), findsOneWidget);
    expect(find.text('Where Money'), findsOneWidget);
    expect(
      find.text('Photograph the receipt. See where the money went.'),
      findsOneWidget,
    );

    final mark = tester.getRect(find.byType(ReceiptMark));
    expect(mark.size, const Size(72, 112));
    expect(mark.bottom, lessThan(tester.getRect(find.text('Where Money')).top));
    expect(
      tester.getRect(find.text('Where Money')).bottom,
      lessThan(
        tester
            .getRect(
              find.text('Photograph the receipt. See where the money went.'),
            )
            .top,
      ),
    );
  });

  testWidgets('the block sits centred in what the strip leaves', (
    tester,
  ) async {
    await open(tester);

    // A `SingleChildScrollView` aligns its child at the top unless it is told
    // the height it has, so this is what says the block is centred rather
    // than sitting against the top of the screen.
    final block = tester
        .getRect(find.byType(ReceiptMark))
        .expandToInclude(
          tester.getRect(
            find.text('Photograph the receipt. See where the money went.'),
          ),
        );
    final space = Rect.fromLTRB(
      0,
      0,
      phone.width,
      tester.getRect(find.byType(Foot)).top,
    );

    expect(
      block.center.dy,
      closeTo(space.center.dy, 1),
      reason: 'the space above the strip is what centres it',
    );
  });

  testWidgets('the receipt is decoration and is not read out', (tester) async {
    await open(tester);

    expect(
      find.descendant(
        of: find.byType(ReceiptMark),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
      reason: 'the name under it says everything the mark says',
    );
  });

  testWidgets('the two ways in sit in the strip, ranked by shape', (
    tester,
  ) async {
    await open(tester);

    expect(theGoogleButton(), findsOneWidget);
    expect(theGuestButton(), findsOneWidget);

    // Both inside the strip Review's commit button wears, so the screen ends
    // the way every other screen with a button does.
    expect(
      find.descendant(of: find.byType(Foot), matching: theGoogleButton()),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(Foot), matching: theGuestButton()),
      findsOneWidget,
    );

    final google = tester.getRect(theGoogleButton());
    final guest = tester.getRect(theGuestButton());

    // The way into an account is above the way round it, and both are the
    // full width of the strip at the height a thumb wants.
    expect(google.bottom, lessThan(guest.top));
    for (final button in [google, guest]) {
      expect(button.height, 48);
      expect(button.left, 16);
      expect(button.right, phone.width - 16);
    }
  });

  testWidgets('the spinner takes the Google button\'s slot and leaves the '
      'strip where it was', (tester) async {
    await open(tester);
    final before = tester.getRect(theGuestButton());

    await holdTheSignIn(tester, theGoogleButton());

    expect(find.bySemanticsLabel('Signing in'), findsOneWidget);
    expect(theGoogleButton(), findsNothing);

    // The guest button has not moved, because the slot the spinner is in is
    // the height the button was.
    expect(tester.getRect(theGuestButton()), before);
  });

  testWidgets('the way round the account is closed while a sign-in is in '
      'flight', (tester) async {
    await open(tester);
    await holdTheSignIn(tester, theGoogleButton());

    expect(
      tester.widget<OutlinedButton>(theGuestButton()).onPressed,
      isNull,
      reason: 'a second way in is not offered while the first is being tried',
    );
  });

  testWidgets('a failure is said over the buttons, and announced', (
    tester,
  ) async {
    signIn.refuse = StateError('no network');

    await open(tester);
    await tester.tap(theGoogleButton());
    await tester.pumpAndSettle();

    final said = find.textContaining('no network');
    expect(said, findsOneWidget);
    expect(
      tester.getRect(said).bottom,
      lessThan(tester.getRect(theGoogleButton()).top),
      reason: 'the sentence is about the buttons, so it sits above them',
    );

    expect(
      find.ancestor(
        of: said,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
      reason: 'TalkBack reads it without the user hunting for what changed',
    );
  });

  testWidgets('a failure belongs to the attempt that failed', (tester) async {
    signIn.refuse = StateError('no network');

    await open(tester);
    await tester.tap(theGoogleButton());
    await tester.pumpAndSettle();
    expect(find.textContaining('no network'), findsOneWidget);

    signIn.refuse = null;
    await holdTheSignIn(tester, theGoogleButton());

    expect(find.textContaining('no network'), findsNothing);
  });

  testWidgets('a guest is let in without an account', (tester) async {
    await open(tester);
    await tester.tap(theGuestButton());
    await tester.pumpAndSettle();

    expect(markSaying('Ledger'), findsOneWidget);
    expect(theGuestButton(), findsNothing);
  });

  testWidgets('a guest session that was refused is explained the same way', (
    tester,
  ) async {
    signIn.refuseGuest = StateError('no network');

    await open(tester);
    await tester.tap(theGuestButton());
    await tester.pumpAndSettle();

    expect(find.textContaining('no network'), findsOneWidget);
    expect(theGuestButton(), findsOneWidget);
    expect(theGoogleButton(), findsOneWidget);
  });
}
