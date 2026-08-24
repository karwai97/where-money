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

  test('a field the user corrected is recorded and settles its own Finding', () {
    final expense = Expense.fromExtraction(
      cleanExtraction.copyWith(total: 99.00),
      id: 'exp-4',
      now: now,
      correctedFields: const ['total'],
    );

    expect(expense.correctedFields, ['total']);
    expect(expense.wasCorrected, isTrue);
    expect(expense.needsReview, isFalse);
  });

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
}
