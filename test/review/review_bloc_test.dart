import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/review/review_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/in_memory_ledger_store.dart';

void main() {
  final now = fixtureNow;

  ReviewBloc against(InMemoryLedgerStore store) =>
      ReviewBloc(store, clock: () => now);

  /// Bloc handlers run off the event queue, so nothing here reads a state
  /// without letting the queue drain first.
  Future<ReviewInProgress> reviewing(ReviewBloc bloc) async {
    await pumpEventQueue();
    return bloc.state as ReviewInProgress;
  }

  Future<Iterable<String>> labels(ReviewBloc bloc) async =>
      (await reviewing(bloc)).check.findings.map((finding) => finding.label);

  /// The shortest path from a blank Extraction to something committable.
  void fillIn(ReviewBloc bloc) {
    bloc
      ..add(const FieldCorrected(ReviewField.merchant, 'Kopitiam SS2'))
      ..add(const FieldCorrected(ReviewField.purchasedAt, '2026-08-22'))
      ..add(const FieldCorrected(ReviewField.currency, 'MYR'))
      ..add(const FieldCorrected(ReviewField.total, '26.00'))
      ..add(const FieldCorrected(ReviewField.category, 'dining'))
      ..add(const FieldCorrected(ReviewField.paymentMethod, 'cash'));
  }

  test('adding by hand opens on a blank Extraction with nothing filled in', () async {
    final bloc = against(InMemoryLedgerStore())
      ..add(const ManualExpenseStarted());

    final state = await reviewing(bloc);
    expect(state.extraction.merchant, isEmpty);
    expect(state.extraction.total, 0);
    expect(state.extraction.lineItems, isEmpty);
    expect(state.correctedFields, isEmpty);
  });

  test('a blank Extraction raises a Finding for everything missing', () async {
    final bloc = against(InMemoryLedgerStore())
      ..add(const ManualExpenseStarted());

    expect(await labels(bloc), contains('No total'));
    expect(await labels(bloc), contains('No merchant'));
  });

  test('a total that does not add up loses its Finding once corrected', () async {
    final bloc = against(InMemoryLedgerStore())
      ..add(const ManualExpenseStarted())
      ..add(const FieldCorrected(ReviewField.subtotal, '20.00'))
      ..add(const FieldCorrected(ReviewField.tax, '1.20'))
      ..add(const FieldCorrected(ReviewField.total, '30.00'));

    expect(await labels(bloc), contains('Total does not add up'));

    bloc.add(const FieldCorrected(ReviewField.total, '21.20'));

    expect(await labels(bloc), isNot(contains('Total does not add up')));
  });

  test('the Check re-runs on a half-typed number without throwing it away', () async {
    final bloc = against(InMemoryLedgerStore())
      ..add(const ManualExpenseStarted())
      ..add(const FieldCorrected(ReviewField.total, '2'))
      ..add(const FieldCorrected(ReviewField.total, '26.'));

    expect((await reviewing(bloc)).extraction.total, 26.00);
    expect(await labels(bloc), isNot(contains('No total')));
  });

  test('an emptied optional amount goes back to being unstated', () async {
    final bloc = against(InMemoryLedgerStore())
      ..add(const ManualExpenseStarted())
      ..add(const FieldCorrected(ReviewField.tip, '5.00'))
      ..add(const FieldCorrected(ReviewField.tip, ''));

    expect((await reviewing(bloc)).extraction.tip, isNull);
  });

  test('a Line Item can be added, corrected and removed', () async {
    final bloc = against(InMemoryLedgerStore())
      ..add(const ManualExpenseStarted())
      ..add(const LineItemAdded())
      ..add(const LineItemCorrected(0, LineItemField.description, 'Nasi lemak'))
      ..add(const LineItemCorrected(0, LineItemField.amount, '12.50'))
      ..add(const LineItemCorrected(0, LineItemField.category, 'dining'));

    final item = (await reviewing(bloc)).extraction.lineItems.single;
    expect(item.description, 'Nasi lemak');
    expect(item.amount, 12.50);
    expect(item.category, 'dining');

    bloc.add(const LineItemRemoved(0));

    expect((await reviewing(bloc)).extraction.lineItems, isEmpty);
  });

  test('touching a Line Item records the Line Items as corrected once', () async {
    final bloc = against(InMemoryLedgerStore())
      ..add(const ManualExpenseStarted())
      ..add(const LineItemAdded())
      ..add(const LineItemCorrected(0, LineItemField.description, 'Nasi lemak'));

    expect((await reviewing(bloc)).correctedFields, ['lineItems']);
  });

  test('retyping the value a field already holds is not a correction', () async {
    final bloc = against(InMemoryLedgerStore())
      ..add(const ManualExpenseStarted())
      ..add(const FieldCorrected(ReviewField.merchant, ''))
      ..add(const FieldCorrected(ReviewField.total, '0'));

    expect((await reviewing(bloc)).correctedFields, isEmpty);
  });

  test('committing writes exactly one Expense, recorded as typed by hand',
      () async {
    final store = InMemoryLedgerStore();
    final bloc = against(store)..add(const ManualExpenseStarted());
    fillIn(bloc);

    bloc.add(const ReviewCommitted());
    await pumpEventQueue();

    final written = store.contents.single;
    expect(written.merchant, 'Kopitiam SS2');
    expect(written.total, 26.00);
    expect(written.currency, 'MYR');
    expect(written.category, 'dining');
    expect(written.date, DateTime(2026, 8, 22));
    expect(written.source, ExpenseSource.manual);
    await bloc.close();
  });

  test('every field the user touched is named on the committed Expense',
      () async {
    final store = InMemoryLedgerStore();
    final bloc = against(store)..add(const ManualExpenseStarted());
    fillIn(bloc);

    bloc.add(const ReviewCommitted());
    await pumpEventQueue();

    expect(store.contents.single.correctedFields, [
      'merchant',
      'purchasedAt',
      'currency',
      'total',
      'category',
      'paymentMethod',
    ]);
    await bloc.close();
  });

  test('an Expense the user filled in does not arrive needing review', () async {
    final store = InMemoryLedgerStore();
    final bloc = against(store)..add(const ManualExpenseStarted());
    fillIn(bloc);

    bloc.add(const ReviewCommitted());
    await pumpEventQueue();

    expect(store.contents.single.needsReview, isFalse);
    await bloc.close();
  });

  test('two taps on commit still write one Expense', () async {
    final store = InMemoryLedgerStore();
    final bloc = against(store)..add(const ManualExpenseStarted());
    fillIn(bloc);

    bloc
      ..add(const ReviewCommitted())
      ..add(const ReviewCommitted());
    await pumpEventQueue();

    expect(store.contents, hasLength(1));
    await bloc.close();
  });

  test('leaving Review and coming back keeps the work in progress', () async {
    final bloc = against(InMemoryLedgerStore())
      ..add(const ManualExpenseStarted())
      ..add(const FieldCorrected(ReviewField.merchant, 'Kopitiam SS2'))
      ..add(const ManualExpenseStarted());

    expect((await reviewing(bloc)).extraction.merchant, 'Kopitiam SS2');
  });

  test('a committed Expense is not still sitting there next time', () async {
    final store = InMemoryLedgerStore();
    final bloc = against(store)..add(const ManualExpenseStarted());
    fillIn(bloc);

    bloc.add(const ReviewCommitted());
    await pumpEventQueue();
    bloc.add(const ManualExpenseStarted());

    expect((await reviewing(bloc)).extraction.merchant, isEmpty);
    await bloc.close();
  });

  test('a refused write says so and keeps the work on screen', () async {
    final store = InMemoryLedgerStore()..refuseWrites = StateError('denied');
    final bloc = against(store)..add(const ManualExpenseStarted());
    fillIn(bloc);

    bloc.add(const ReviewCommitted());
    await pumpEventQueue();

    final state = await reviewing(bloc);
    expect(state.refusal, isNotNull);
    expect(state.extraction.merchant, 'Kopitiam SS2');
    expect(store.contents, isEmpty);
    await bloc.close();
  });

  blocTest<ReviewBloc, ReviewState>(
    'a committed Expense tells the screen Review is over',
    build: () => against(InMemoryLedgerStore()),
    act: (bloc) async {
      bloc.add(const ManualExpenseStarted());
      fillIn(bloc);
      bloc.add(const ReviewCommitted());
      await pumpEventQueue();
    },
    verify: (bloc) => expect(bloc.state, isA<ReviewIdle>()),
  );

  test('adding an empty Line Item row is not yet a correction', () async {
    final bloc = against(InMemoryLedgerStore())
      ..add(const ManualExpenseStarted())
      ..add(const LineItemAdded());

    expect(
      (await reviewing(bloc)).correctedFields,
      isEmpty,
      reason: 'an empty row is a placeholder, not a look at the receipt',
    );
  });

  test('an empty Line Item row does not settle the Finding it just caused',
      () async {
    final store = InMemoryLedgerStore();
    final bloc = against(store)..add(const ManualExpenseStarted());
    fillIn(bloc);
    bloc
      ..add(const LineItemAdded())
      ..add(const ReviewCommitted());
    await pumpEventQueue();

    expect(store.contents.single.needsReview, isTrue);
    await bloc.close();
  });

  test('retyping a Line Item value it already holds is not a correction',
      () async {
    final bloc = against(InMemoryLedgerStore())
      ..add(const ManualExpenseStarted())
      ..add(const LineItemAdded())
      ..add(const LineItemCorrected(0, LineItemField.description, ''));

    expect((await reviewing(bloc)).correctedFields, isEmpty);
  });

  test('a half-typed minus sign is not a total', () async {
    final bloc = against(InMemoryLedgerStore())
      ..add(const ManualExpenseStarted())
      ..add(const FieldCorrected(ReviewField.total, '-'));

    expect((await reviewing(bloc)).extraction.total, 0);
  });
}
