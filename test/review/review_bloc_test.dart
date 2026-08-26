import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/review/review_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/in_memory_ledger_store.dart';

void main() {
  final now = fixtureNow;

  ReviewBloc against(InMemoryLedgerStore store) =>
      ReviewBloc(store, store, store, clock: () => now);

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

  group('editing something already in the Ledger', () {
    Expense committed({
      List<String> correctedFields = const [],
      ExpenseSource source = ExpenseSource.scanned,
      String? receiptPath = 'scan-1.jpg',
    }) => Expense.fromExtraction(
      cleanExtraction,
      id: 'exp-1',
      now: now,
      source: source,
      correctedFields: correctedFields,
      receiptPath: receiptPath,
    );

    test(
      'editing opens on what is in the Ledger, not on a blank form',
      () async {
        final expense = committed();
        final bloc = against(InMemoryLedgerStore([expense]))
          ..add(ExpenseEditStarted(expense));

        final state = await reviewing(bloc);
        expect(state.extraction.merchant, 'Village Grocer Bangsar');
        expect(state.extraction.total, 44.10);
        expect(state.extraction.lineItems, hasLength(4));
      },
    );

    test(
      'the Check re-runs while editing, the same as it does during Review',
      () async {
        final expense = committed();
        final bloc = against(InMemoryLedgerStore([expense]))
          ..add(ExpenseEditStarted(expense));

        expect(await labels(bloc), isEmpty);

        bloc.add(const FieldCorrected(ReviewField.total, '99.00'));
        expect(await labels(bloc), contains('Total does not add up'));

        bloc.add(const FieldCorrected(ReviewField.total, '44.10'));
        expect(await labels(bloc), isEmpty);
      },
    );

    test(
      "correcting last quarter's Expense is not nagged about how old it is",
      () async {
        final old = committed().copyWith(date: DateTime(2026, 3, 2));
        final bloc = against(InMemoryLedgerStore([old]))
          ..add(ExpenseEditStarted(old));

        expect(
          await labels(bloc),
          isEmpty,
          reason:
              'the date was confirmed when it was committed, and no edit can '
              'settle a Finding about the calendar',
        );
      },
    );

    test(
      'but a date typed in while editing that has not happened yet still is',
      () async {
        final expense = committed();
        final bloc = against(InMemoryLedgerStore([expense]))
          ..add(ExpenseEditStarted(expense))
          ..add(const FieldCorrected(ReviewField.purchasedAt, '2027-01-04'));

        expect(await labels(bloc), contains('Date in the future'));
      },
    );

    test(
      'a saved edit writes over the same Expense rather than adding a second '
      'one',
      () async {
        final expense = committed();
        final store = InMemoryLedgerStore([expense]);
        against(store)
          ..add(ExpenseEditStarted(expense))
          ..add(const FieldCorrected(ReviewField.merchant, 'Village Grocer KL'))
          ..add(const ReviewCommitted());
        await pumpEventQueue();

        expect(store.contents, hasLength(1));
        expect(store.contents.single.id, 'exp-1');
        expect(store.contents.single.merchant, 'Village Grocer KL');
      },
    );

    test('editing adds to the fields already recorded as corrected rather than '
        'replacing them', () async {
      final expense = committed(correctedFields: const ['merchant']);
      final store = InMemoryLedgerStore([expense]);
      against(store)
        ..add(ExpenseEditStarted(expense))
        ..add(const FieldCorrected(ReviewField.total, '45.10'))
        ..add(const ReviewCommitted());
      await pumpEventQueue();

      expect(store.contents.single.correctedFields, ['merchant', 'total']);
    });

    test('correcting the same field twice is still one correction', () async {
      final expense = committed(correctedFields: const ['merchant']);
      final store = InMemoryLedgerStore([expense]);
      against(store)
        ..add(ExpenseEditStarted(expense))
        ..add(const FieldCorrected(ReviewField.merchant, 'Village Grocer KL'))
        ..add(const ReviewCommitted());
      await pumpEventQueue();

      expect(store.contents.single.correctedFields, ['merchant']);
    });

    test(
      'an edited Expense keeps its receipt and how it got into the Ledger',
      () async {
        final expense = committed();
        final store = InMemoryLedgerStore([expense]);
        against(store)
          ..add(ExpenseEditStarted(expense))
          ..add(const FieldCorrected(ReviewField.total, '45.10'))
          ..add(const ReviewCommitted());
        await pumpEventQueue();

        expect(store.contents.single.receiptPath, 'scan-1.jpg');
        expect(store.contents.single.source, ExpenseSource.scanned);
      },
    );

    test(
      'an Expense typed by hand is still typed by hand after an edit',
      () async {
        final expense = committed(
          source: ExpenseSource.manual,
          receiptPath: null,
        );
        final store = InMemoryLedgerStore([expense]);
        against(store)
          ..add(ExpenseEditStarted(expense))
          ..add(const FieldCorrected(ReviewField.total, '45.10'))
          ..add(const ReviewCommitted());
        await pumpEventQueue();

        expect(store.contents.single.source, ExpenseSource.manual);
        expect(store.contents.single.receiptPath, isNull);
      },
    );

    test(
      'a refused save keeps the typing rather than losing the edit',
      () async {
        final expense = committed();
        final store = InMemoryLedgerStore([expense])
          ..refuseWrites = StateError('denied');
        final bloc = against(store)
          ..add(ExpenseEditStarted(expense))
          ..add(const FieldCorrected(ReviewField.merchant, 'Village Grocer KL'))
          ..add(const ReviewCommitted());

        final state = await reviewing(bloc);
        expect(state.refusal, isNotNull);
        expect(state.extraction.merchant, 'Village Grocer KL');
      },
    );
  });
}
