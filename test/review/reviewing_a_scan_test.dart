import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/review/review_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/in_memory_ledger_store.dart';

/// Review with something to Review: what the Model read, in front of the
/// receipt it read it from.
void main() {
  final now = fixtureNow;
  final receipt = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);

  late InMemoryLedgerStore store;

  setUp(() => store = InMemoryLedgerStore());

  ReviewBloc against(InMemoryLedgerStore store) =>
      ReviewBloc(store, store, store, clock: () => now);

  Future<ReviewInProgress> reviewing(ReviewBloc bloc) async {
    await pumpEventQueue();
    return bloc.state as ReviewInProgress;
  }

  Future<Scan> waiting(Extraction read) async {
    final scan = await store.capture(receipt);
    await store.put(scan.movedTo(ScanState.extracted, extraction: read));
    return store.waiting.single;
  }

  test('Review opens pre-filled with what the Model read', () async {
    final bloc = against(store)
      ..add(ScanReviewStarted(await waiting(cleanExtraction)));

    final state = await reviewing(bloc);
    expect(state.extraction.merchant, 'Village Grocer Bangsar');
    expect(state.extraction.total, 44.10);
    expect(state.correctedFields, isEmpty);
  });

  test('the receipt is there to check the fields against', () async {
    final bloc = against(store)
      ..add(ScanReviewStarted(await waiting(cleanExtraction)));

    expect((await reviewing(bloc)).receipt, receipt);
  });

  test('the Model says why it chose the Category', () async {
    final bloc = against(store)
      ..add(ScanReviewStarted(await waiting(cleanExtraction)));

    expect(
      (await reviewing(bloc)).extraction.categoryReason,
      'Fresh food and household staples, nothing else on the bill.',
    );
  });

  test('a clean Extraction opens with nothing flagged and is still not an '
      'Expense', () async {
    final bloc = against(store)
      ..add(ScanReviewStarted(await waiting(cleanExtraction)));

    expect((await reviewing(bloc)).check.findings, isEmpty);
    expect(store.contents, isEmpty);
    expect(store.waiting, hasLength(1));
  });

  test('a clean Extraction becomes an Expense on one deliberate tap', () async {
    final bloc = against(store)
      ..add(ScanReviewStarted(await waiting(cleanExtraction)));
    await pumpEventQueue();

    bloc.add(const ReviewCommitted());
    await pumpEventQueue();

    expect(store.contents, hasLength(1));
    expect(store.contents.single.merchant, 'Village Grocer Bangsar');
  });

  test(
    'a flagged Extraction reaches the same screen with its Findings',
    () async {
      final bloc = against(store)
        ..add(ScanReviewStarted(await waiting(flawedExtraction)));

      final labels = (await reviewing(bloc)).check.findings.map((f) => f.label);
      expect(labels, contains('No date'));
      expect(labels, contains('Line items do not match subtotal'));
    },
  );

  test('committing takes the Scan out of the Inbox', () async {
    final bloc = against(store)
      ..add(ScanReviewStarted(await waiting(cleanExtraction)));
    await pumpEventQueue();

    bloc.add(const ReviewCommitted());
    await pumpEventQueue();

    expect(store.waiting, isEmpty);
  });

  test('the committed Expense says it came from a Scan', () async {
    final bloc = against(store)
      ..add(ScanReviewStarted(await waiting(cleanExtraction)));
    await pumpEventQueue();

    bloc.add(const ReviewCommitted());
    await pumpEventQueue();

    expect(store.contents.single.source, ExpenseSource.scanned);
  });

  test(
    'corrections during Review are recorded by field name on the Expense',
    () async {
      final bloc = against(store)
        ..add(ScanReviewStarted(await waiting(cleanExtraction)));
      await pumpEventQueue();

      bloc
        ..add(const FieldCorrected(ReviewField.merchant, 'Village Grocer'))
        ..add(const FieldCorrected(ReviewField.total, '44.20'));
      await pumpEventQueue();
      bloc.add(const ReviewCommitted());
      await pumpEventQueue();

      expect(store.contents.single.correctedFields, ['merchant', 'total']);
    },
  );

  test('a Scan Reviewed twice is still one Expense', () async {
    final scan = await waiting(cleanExtraction);
    final bloc = against(store)..add(ScanReviewStarted(scan));
    await pumpEventQueue();
    bloc.add(const ReviewCommitted());
    await pumpEventQueue();

    bloc
      ..add(ScanReviewStarted(scan))
      ..add(const ReviewCommitted());
    await pumpEventQueue();

    expect(store.contents, hasLength(1));
  });

  test(
    'a half-finished Review is still there after looking at something else',
    () async {
      final bloc = against(store)
        ..add(ScanReviewStarted(await waiting(cleanExtraction)));
      await pumpEventQueue();
      bloc.add(const FieldCorrected(ReviewField.merchant, 'Village Grocer KL'));
      await pumpEventQueue();

      bloc.add(const ManualExpenseStarted());
      expect((await reviewing(bloc)).extraction.merchant, isEmpty);

      bloc.add(ScanReviewStarted(store.waiting.single));
      final back = await reviewing(bloc);

      expect(back.extraction.merchant, 'Village Grocer KL');
      expect(back.correctedFields, ['merchant']);
      expect(back.receipt, receipt);
    },
  );

  test('a Scan with nothing read yet has nothing to Review', () async {
    final scan = await store.capture(receipt);
    final bloc = against(store)..add(ScanReviewStarted(scan));

    await pumpEventQueue();
    expect(bloc.state, isA<ReviewIdle>());
  });
}
