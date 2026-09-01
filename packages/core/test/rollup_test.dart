import 'package:test/test.dart';
import 'package:where_money_core/where_money_core.dart';

Expense spent(
  double total, {
  required int day,
  int month = 8,
  int year = 2026,
  String category = 'dining',
  String merchant = 'Kopitiam',
  String currency = 'MYR',
  ExpenseSource source = ExpenseSource.scanned,
  bool needsReview = false,
}) => Expense(
  id: '$year-$month-$day-$merchant-$total',
  merchant: merchant,
  date: DateTime(year, month, day),
  currency: currency,
  total: total,
  category: category,
  lineItems: const [],
  source: source,
  needsReview: needsReview,
);

Rollup august(List<Expense> ledger) =>
    Rollup.forMonth(ledger, year: 2026, month: 8, homeCurrency: 'MYR');

CategoryTotal categoryIn(Rollup rollup, String category) =>
    rollup.byCategory.firstWhere((c) => c.category == category);

void main() {
  test('a month totals each category and counts what went into it', () {
    final rollup = august([
      spent(20.00, day: 1, category: 'dining'),
      spent(30.00, day: 2, category: 'dining'),
      spent(45.00, day: 3, category: 'fuel'),
      spent(10.00, day: 4, month: 7, category: 'dining'),
    ]);

    expect(rollup.total, 95.00);
    expect(rollup.expenseCount, 3);
    expect(categoryIn(rollup, 'dining').amount, 50.00);
    expect(categoryIn(rollup, 'dining').count, 2);
    expect(categoryIn(rollup, 'fuel').amount, 45.00);
  });

  test('categories are ordered by what they cost', () {
    final rollup = august([
      spent(20.00, day: 1, category: 'dining'),
      spent(80.00, day: 2, category: 'groceries'),
      spent(45.00, day: 3, category: 'fuel'),
    ]);

    expect(rollup.byCategory.map((c) => c.category), [
      'groceries',
      'fuel',
      'dining',
    ]);
  });

  test('the month is compared against the one before it', () {
    final rollup = august([
      spent(150.00, day: 4, category: 'groceries'),
      spent(100.00, day: 12, month: 7, category: 'groceries'),
      spent(20.00, day: 14, month: 7, category: 'fuel'),
    ]);

    expect(rollup.previousTotal, 120.00);
    expect(rollup.delta, 30.00);
    expect(rollup.percentChange, closeTo(25.0, 0.001));
  });

  test('a category that moved carries last month beside this month', () {
    final rollup = august([
      spent(150.00, day: 4, category: 'groceries'),
      spent(100.00, day: 12, month: 7, category: 'groceries'),
    ]);

    expect(categoryIn(rollup, 'groceries').previousAmount, 100.00);
    expect(categoryIn(rollup, 'groceries').delta, 50.00);
  });

  test('a first month has no percentage to compare against', () {
    final rollup = august([spent(150.00, day: 4)]);

    expect(rollup.previousTotal, 0);
    expect(rollup.percentChange, isNull);
  });

  test('December looks back into the previous year', () {
    final rollup = Rollup.forMonth(
      [
        spent(40.00, day: 3, month: 1, year: 2027),
        spent(25.00, day: 9, month: 12, year: 2026),
      ],
      year: 2027,
      month: 1,
      homeCurrency: 'MYR',
    );

    expect(rollup.previousTotal, 25.00);
  });

  test('the largest purchases come back biggest first', () {
    final rollup = august([
      spent(12.00, day: 1, merchant: 'Grab'),
      spent(289.90, day: 2, merchant: 'Ikea'),
      spent(54.90, day: 3, merchant: 'Netflix'),
    ]);

    expect(rollup.largest.map((e) => e.merchant), ['Ikea', 'Netflix', 'Grab']);
  });

  test('the heaviest day is the one the money actually went out on', () {
    final rollup = august([
      spent(40.00, day: 3),
      spent(30.00, day: 9),
      spent(35.00, day: 9),
      spent(10.00, day: 20),
    ]);

    expect(rollup.heaviestDay!.day, 9);
    expect(rollup.heaviestDay!.amount, 65.00);
  });

  test('an empty month has no heaviest day rather than a made-up one', () {
    expect(august(const []).heaviestDay, isNull);
    expect(august(const []).total, 0);
  });

  test('spending in another currency is left out and counted', () {
    final rollup = august([
      spent(100.00, day: 2),
      spent(60.00, day: 5, currency: 'SGD', merchant: 'Changi'),
      spent(40.00, day: 6, currency: 'USD', merchant: 'Steam'),
    ]);

    expect(rollup.total, 100.00);
    expect(rollup.expenseCount, 1);
    expect(rollup.excludedCount, 2);
    expect(rollup.excludedCurrencies, {'SGD', 'USD'});
    expect(rollup.largest.map((e) => e.merchant), ['Kopitiam']);
  });

  test('an excluded expense from another month is not counted as excluded', () {
    final rollup = august([
      spent(100.00, day: 2),
      spent(60.00, day: 5, month: 7, currency: 'SGD'),
    ]);

    expect(rollup.excludedCount, 0);
  });

  test('the rollup says how much of the month came from Scans', () {
    final rollup = august([
      spent(10.00, day: 1, source: ExpenseSource.scanned),
      spent(20.00, day: 2, source: ExpenseSource.manual),
      spent(30.00, day: 3, source: ExpenseSource.scanned, needsReview: true),
    ]);

    expect(rollup.scannedCount, 2);
    expect(rollup.needsReviewCount, 1);
  });

  test('the daily average spreads the month over its own length', () {
    final rollup = august([spent(310.00, day: 4)]);

    expect(rollup.dailyAverage, closeTo(10.0, 0.001));
  });

  test('the seeded Ledger rolls up into a month worth looking at', () {
    final rollup = Rollup.forMonth(
      seedLedger(around: DateTime(2026, 8, 15)),
      year: 2026,
      month: 8,
      homeCurrency: 'MYR',
    );

    expect(rollup.expenseCount, 18);
    expect(rollup.total, closeTo(1806.75, 0.005));
    expect(rollup.byCategory.first.category, 'groceries');
    expect(rollup.heaviestDay!.day, 23);
    expect(rollup.largest.first.merchant, 'Ikea Damansara');
    expect(rollup.excludedCount, 1);
    expect(rollup.excludedCurrencies, {'USD'});
    expect(rollup.previousTotal, closeTo(1265.80, 0.005));
    expect(rollup.needsReviewCount, 2);
  });

  test('a trend runs oldest to newest and ends at the month asked for', () {
    final trend = Rollup.trailing(
      [spent(10.00, day: 1, month: 6), spent(20.00, day: 1, month: 8)],
      year: 2026,
      month: 8,
      months: 4,
      homeCurrency: 'MYR',
    );

    expect(trend.map((r) => (r.year, r.month)), [
      (2026, 5),
      (2026, 6),
      (2026, 7),
      (2026, 8),
    ]);
    expect(trend.map((r) => r.total), [0, 10.00, 0, 20.00]);
  });

  test('a trend crosses the turn of the year', () {
    final trend = Rollup.trailing(
      [spent(60.00, day: 4, month: 12, year: 2025)],
      year: 2026,
      month: 2,
      months: 3,
      homeCurrency: 'MYR',
    );

    expect(trend.map((r) => (r.year, r.month)), [
      (2025, 12),
      (2026, 1),
      (2026, 2),
    ]);
    expect(trend.first.total, 60.00);
  });

  test('a month in the trend still leaves out other currencies', () {
    final trend = Rollup.trailing(
      [
        spent(100.00, day: 2, month: 7),
        spent(60.00, day: 5, month: 7, currency: 'SGD'),
      ],
      year: 2026,
      month: 8,
      months: 2,
      homeCurrency: 'MYR',
    );

    expect(trend.first.total, 100.00);
    expect(trend.first.excludedCount, 1);
  });

  test('a month nobody spent anything in has no spending to show', () {
    expect(august(const []).hasSpending, isFalse);
    expect(august([spent(10.00, day: 1)]).hasSpending, isTrue);
  });

  test('a month of nothing but foreign spending has none to chart and still '
      'says what it left out', () {
    final rollup = august([spent(60.00, day: 5, currency: 'SGD')]);

    expect(rollup.hasSpending, isFalse);
    expect(rollup.excludedCount, 1);
  });

  test('a month numbers the one it is being compared against', () {
    expect(
      (august(const []).previousYear, august(const []).previousMonth),
      (2026, 7),
    );

    final january = Rollup.forMonth(
      const [],
      year: 2026,
      month: 1,
      homeCurrency: 'MYR',
    );
    expect((january.previousYear, january.previousMonth), (2025, 12));
  });
}
