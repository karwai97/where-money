import 'package:test/test.dart';
import 'package:where_money_core/where_money_core.dart';

final now = fixtureNow;

void main() {
  test('a committed Extraction keeps what was read from the receipt', () {
    final expense = Expense.fromExtraction(
      cleanExtraction,
      id: 'exp-1',
      now: now,
    );

    expect(expense.merchant, cleanExtraction.merchant);
    expect(expense.total, cleanExtraction.total);
    expect(expense.currency, 'MYR');
    expect(expense.date, DateTime.parse(cleanExtraction.purchasedAt!));
    expect(expense.source, ExpenseSource.scanned);
    expect(expense.needsReview, isFalse);
  });

  test('an unread date falls back to the day it was reviewed', () {
    final expense = Expense.fromExtraction(
      flawedExtraction,
      id: 'exp-2',
      now: now,
    );

    expect(expense.date, now);
  });

  test('an Extraction the Check warned about arrives needing review', () {
    final expense = Expense.fromExtraction(
      flawedExtraction,
      id: 'exp-3',
      now: now,
    );

    expect(expense.needsReview, isTrue);
  });

  test('an Extraction whose total does not add up arrives needing review', () {
    final expense = Expense.fromExtraction(
      cleanExtraction.copyWith(total: 99.00),
      id: 'exp-6',
      now: now,
    );

    expect(expense.needsReview, isTrue);
  });

  test(
    'a field the user corrected is recorded and settles its own Finding',
    () {
      final expense = Expense.fromExtraction(
        cleanExtraction.copyWith(total: 99.00),
        id: 'exp-4',
        now: now,
        correctedFields: const ['total'],
      );

      expect(expense.correctedFields, ['total']);
      expect(expense.wasCorrected, isTrue);
      expect(expense.needsReview, isFalse);
    },
  );

  test('correcting one field does not settle a Finding about another', () {
    final expense = Expense.fromExtraction(
      cleanExtraction.copyWith(total: 99.00),
      id: 'exp-7',
      now: now,
      correctedFields: const ['merchant'],
    );

    expect(
      expense.needsReview,
      isTrue,
      reason: 'the total is still wrong, and nobody has looked at it',
    );
  });

  test('the Model asking for a human to look is answered by Review itself', () {
    final expense = Expense.fromExtraction(
      flawedExtraction,
      id: 'exp-9',
      now: now,
      correctedFields: const ['purchasedAt', 'lineItems'],
    );

    expect(
      expense.needsReview,
      isFalse,
      reason:
          'every Finding naming a field was corrected, and the Model asking '
          'for review is what the user has just done',
    );
  });

  test('an Expense typed by hand records that nobody scanned it', () {
    final expense = Expense.fromExtraction(
      Extraction.blank().copyWith(
        merchant: 'Kopitiam SS2',
        purchasedAt: '2026-08-22',
        currency: 'MYR',
        total: 26.00,
        category: 'dining',
      ),
      id: 'exp-8',
      now: now,
      source: ExpenseSource.manual,
      correctedFields: const ['merchant', 'purchasedAt', 'currency', 'total'],
    );

    expect(expense.source, ExpenseSource.manual);
    expect(expense.merchant, 'Kopitiam SS2');
    expect(expense.total, 26.00);
    expect(expense.needsReview, isFalse);
  });

  test('a category outside the taxonomy lands in other', () {
    final expense = Expense.fromExtraction(
      cleanExtraction.copyWith(category: 'crypto'),
      id: 'exp-5',
      now: now,
    );

    expect(expense.category, 'other');
  });

  test('a committed Expense keeps the arithmetic the Check re-does', () {
    final expense = Expense.fromExtraction(
      cleanExtraction,
      id: 'exp-10',
      now: now,
    );

    expect(expense.subtotal, cleanExtraction.subtotal);
    expect(expense.tax, cleanExtraction.tax);
    expect(expense.tip, cleanExtraction.tip);
    expect(expense.paymentMethod, 'card');
  });

  test('reopening a clean Expense finds the same Check that let it in', () {
    final expense = Expense.fromExtraction(
      cleanExtraction,
      id: 'exp-11',
      now: now,
    );

    final again = Check.of(expense.asExtraction(), now: now);

    expect(
      again.findings,
      isEmpty,
      reason:
          'the subtotal and tax are on the Expense, so the line items still '
          'reconcile the way they did during Review',
    );
  });

  test('reopening an Expense does not ask again for the review it has already '
      'had', () {
    final expense = Expense.fromExtraction(
      flawedExtraction,
      id: 'exp-12',
      now: now,
      correctedFields: const ['purchasedAt', 'lineItems'],
    );

    final findings = Check.of(expense.asExtraction(), now: now).findings;

    expect(findings, isNot(contains(isA<ModelAskedForReview>())));
  });

  test('an Expense typed by hand has no receipt to point at', () {
    final expense = Expense.fromExtraction(
      Extraction.blank(),
      id: 'exp-13',
      now: now,
      source: ExpenseSource.manual,
    );

    expect(expense.receiptPath, isNull);
  });

  test('an Expense read from a receipt remembers where the photo is', () {
    final expense = Expense.fromExtraction(
      cleanExtraction,
      id: 'exp-14',
      now: now,
      receiptPath: 'scan-1.jpg',
    );

    expect(expense.receiptPath, 'scan-1.jpg');
    expect(expense.asExtraction().merchant, cleanExtraction.merchant);
  });
}
