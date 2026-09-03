import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/l10n/app_localizations_en.dart';
import 'package:where_money/ledger/ledger_bloc.dart';
import 'package:where_money/ledger/recap_copy.dart';
import 'package:where_money/scan/inbox_copy.dart';
import 'package:where_money_core/where_money_core.dart';

/// Every way the Model can leave a Scan or a month with nothing, and the words
/// the user gets for it. Both switches are exhaustive, so a member added
/// without copy does not compile; this pins what the copy says.
///
/// These twenty sentences are what the app says on its worst day and until now
/// nothing read any of them, which meant a member could be pointed at another
/// member's key and compile clean. The Findings have had this test since the
/// copy moved into the message files; the failures should have had it then too.
void main() {
  final words = AppLocalizationsEn();

  ({String saying, String? next}) inbox(ScanFailure? failure) {
    final (saying, next) = sayingFor(
      words,
      Scan(
        id: 'a',
        capturedAt: DateTime(2026, 8, 27),
        state: ScanState.failed,
        failure: failure,
      ),
    );
    return (saying: saying, next: next);
  }

  group('what the Inbox says about a failed Scan', () {
    test('the Model refused the photo', () {
      expect(inbox(ScanFailure.refused), (
        saying: 'The Model would not read this photo',
        next: 'A clearer photograph is the likeliest fix.',
      ));
    });

    test('the Model answered with nothing', () {
      expect(inbox(ScanFailure.saidNothing), (
        saying: 'The Model answered with nothing at all',
        next: 'Reading it again usually works.',
      ));
    });

    test('the answer was not the promised JSON', () {
      expect(inbox(ScanFailure.notLegible), (
        saying: "The Model's answer was not readable",
        next: 'Reading it again usually works.',
      ));
    });

    test('nothing got through from this phone', () {
      expect(inbox(ScanFailure.outOfReach), (
        saying: 'No connection when this was read',
        next: 'It will keep trying on its own.',
      ));
    });

    test('the far end could not do it', () {
      expect(inbox(ScanFailure.modelUnavailable), (
        saying: 'The Model was not available',
        next: 'This usually passes. Read it again in a minute.',
      ));
    });

    test('the token was refused', () {
      expect(inbox(ScanFailure.tokenRefused), (
        saying: 'Your sign-in was not accepted',
        next: 'Sign in again, then read it again.',
      ));
    });

    test('the image was not accepted', () {
      expect(inbox(ScanFailure.imageNotAccepted), (
        saying: 'This photo could not be sent',
        next: 'Photograph the receipt again.',
      ));
    });

    /// A Scan stored by a version of the app that had no failure to write. It
    /// is reachable from disk rather than from the reading queue, which is why
    /// it has no next step to offer.
    test('a Scan that failed before the app could say why', () {
      expect(inbox(null), (saying: 'This could not be read', next: null));
    });

    /// The next steps are deliberately not distinct — silence and malformed
    /// JSON both answer to reading it again — but two failures wearing the
    /// same headline would be a member pointed at the wrong key.
    test('no two failures wear the same headline', () {
      final headlines = [
        for (final failure in [...ScanFailure.values, null])
          inbox(failure).saying,
      ];

      expect(headlines.toSet(), hasLength(headlines.length));
    });
  });

  group('why a month has no Recap', () {
    test('the Model would not write it up', () {
      expect(
        whyThereIsNoRecap(words, WhyNoRecap.refused),
        'The Model would not write up this month.',
      );
    });

    test('the Model had nothing to say', () {
      expect(
        whyThereIsNoRecap(words, WhyNoRecap.nothingToSay),
        'The Model had nothing to say about this month.',
      );
    });

    test("the day's allowance is spent", () {
      expect(
        whyThereIsNoRecap(words, WhyNoRecap.allowanceSpent),
        "That is today's allowance. There will be a Recap tomorrow.",
      );
    });

    test('the token was refused', () {
      expect(
        whyThereIsNoRecap(words, WhyNoRecap.tokenRefused),
        'Sign in again and the Recap will come back.',
      );
    });

    test('nothing got through from this phone', () {
      expect(
        whyThereIsNoRecap(words, WhyNoRecap.outOfReach),
        'No Recap without a connection. The charts do not need one.',
      );
    });

    test('the far end could not do it', () {
      expect(
        whyThereIsNoRecap(words, WhyNoRecap.modelUnavailable),
        'The Model could not be reached. The charts do not need it.',
      );
    });

    test('no two reasons read the same', () {
      final reasons = [
        for (final why in WhyNoRecap.values) whyThereIsNoRecap(words, why),
      ];

      expect(reasons.toSet(), hasLength(reasons.length));
    });
  });
}
