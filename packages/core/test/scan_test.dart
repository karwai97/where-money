import 'package:test/test.dart';
import 'package:where_money_core/where_money_core.dart';

void main() {
  final at = DateTime.utc(2026, 8, 24, 9, 30);

  test('a photographed receipt is a Scan at captured before anything else '
      'happens to it', () {
    final scan = Scan.captured(id: 'a', at: at);

    expect(scan.state, ScanState.captured);
    expect(scan.extraction, isNull);
    expect(scan.capturedAt, at);
  });

  test('a Scan waits in the Inbox until it becomes an Expense', () {
    for (final state in ScanState.values) {
      final scan = Scan(id: 'a', capturedAt: at, state: state);
      expect(scan.inInbox, state != ScanState.committed, reason: '$state');
    }
  });

  test('a Scan carries the Extraction the Model produced for it', () {
    final scan = Scan.captured(
      id: 'a',
      at: at,
    ).movedTo(ScanState.extracted, extraction: cleanExtraction);

    expect(scan.state, ScanState.extracted);
    expect(scan.extraction?.merchant, cleanExtraction.merchant);
    expect(scan.id, 'a');
    expect(scan.capturedAt, at);
  });

  test('a Scan that failed says which failure it was', () {
    final scan = Scan.captured(
      id: 'a',
      at: at,
    ).movedTo(ScanState.failed, failure: ScanFailure.refused);

    expect(scan.state, ScanState.failed);
    expect(scan.failure, ScanFailure.refused);
  });

  test('a capped Scan says when the allowance resets', () {
    final tomorrow = DateTime.utc(2026, 8, 25);

    final scan = Scan.captured(
      id: 'a',
      at: at,
    ).movedTo(ScanState.capped, allowanceResetsAt: tomorrow);

    expect(scan.state, ScanState.capped);
    expect(scan.allowanceResetsAt, tomorrow);
  });

  test('moving on from a failure leaves the failure behind', () {
    final failed = Scan.captured(
      id: 'a',
      at: at,
    ).movedTo(ScanState.failed, failure: ScanFailure.outOfReach);

    final readAgain = failed.movedTo(ScanState.extracting);

    expect(readAgain.failure, isNull);
    expect(readAgain.allowanceResetsAt, isNull);
  });

  test('trying again is only offered for a Scan that has not been read', () {
    for (final state in ScanState.values) {
      expect(
        Scan(id: 'a', capturedAt: at, state: state).canBeReadAgain,
        state == ScanState.failed || state == ScanState.capped,
        reason: '$state',
      );
    }
  });

  test('only a Scan that could not reach the Model tries again by itself', () {
    for (final failure in ScanFailure.values) {
      expect(
        failure.triesAgainByItself,
        failure == ScanFailure.outOfReach,
        reason: '$failure',
      );
    }
  });
}
