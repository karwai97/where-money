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

  test('a field the user fixed is recorded and settles the review', () {
    final expense = Expense.fromExtraction(
      flawedExtraction,
      id: 'exp-4',
      now: now,
      correctedFields: const ['purchasedAt'],
    );

    expect(expense.correctedFields, ['purchasedAt']);
    expect(expense.wasCorrected, isTrue);
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
