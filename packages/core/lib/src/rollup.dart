/// The Rollup: a month of the Ledger reduced to totals, deltas and outliers.
/// Deterministic, computed on device, and small — the same Rollup feeds the
/// charts and the Recap, so the words and the picture cannot disagree.
///
/// Only Home Currency Expenses are aggregated. Anything else is excluded and
/// counted, never silently folded in at an invented rate (ADR-0006).
library;

import 'expense.dart';

class CategoryTotal {
  final String category;
  final double amount;
  final int count;
  final double previousAmount;

  const CategoryTotal({
    required this.category,
    required this.amount,
    required this.count,
    required this.previousAmount,
  });

  double get delta => amount - previousAmount;
}

class DayTotal {
  final int day;
  final double amount;

  const DayTotal(this.day, this.amount);
}

class Rollup {
  final int year;
  final int month;
  final String homeCurrency;

  final double total;
  final double previousTotal;
  final int expenseCount;
  final int scannedCount;
  final int needsReviewCount;

  final List<CategoryTotal> byCategory;
  final Map<int, double> byDay;

  /// Biggest first, capped at [_topPurchases].
  final List<Expense> largest;

  /// Expenses in the month that were left out for being in another currency.
  final int excludedCount;
  final Set<String> excludedCurrencies;

  const Rollup({
    required this.year,
    required this.month,
    required this.homeCurrency,
    required this.total,
    required this.previousTotal,
    required this.expenseCount,
    required this.scannedCount,
    required this.needsReviewCount,
    required this.byCategory,
    required this.byDay,
    required this.largest,
    required this.excludedCount,
    required this.excludedCurrencies,
  });

  factory Rollup.forMonth(
    List<Expense> ledger, {
    required int year,
    required int month,
    required String homeCurrency,
  }) {
    final inMonth = expensesIn(ledger, year: year, month: month);
    final home = inMonth.where((e) => e.currency == homeCurrency).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final foreign = inMonth.where((e) => e.currency != homeCurrency);

    final previousMonth = DateTime(year, month - 1);
    final previous = ledger.where(
      (e) =>
          e.currency == homeCurrency &&
          e.date.year == previousMonth.year &&
          e.date.month == previousMonth.month,
    );
    final previousByCategory = _sumByCategory(previous);

    final sums = _sumByCategory(home);
    final counts = <String, int>{};
    final byDay = <int, double>{};
    for (final expense in home) {
      counts[expense.category] = (counts[expense.category] ?? 0) + 1;
      byDay[expense.date.day] = (byDay[expense.date.day] ?? 0) + expense.total;
    }

    final byCategory =
        sums.entries
            .map(
              (entry) => CategoryTotal(
                category: entry.key,
                amount: entry.value,
                count: counts[entry.key] ?? 0,
                previousAmount: previousByCategory[entry.key] ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    return Rollup(
      year: year,
      month: month,
      homeCurrency: homeCurrency,
      total: home.fold<double>(0, (sum, e) => sum + e.total),
      previousTotal: previous.fold<double>(0, (sum, e) => sum + e.total),
      expenseCount: home.length,
      scannedCount: home.where((e) => e.source == ExpenseSource.scanned).length,
      needsReviewCount: home.where((e) => e.needsReview).length,
      byCategory: byCategory,
      byDay: byDay,
      largest: home.take(_topPurchases).toList(),
      excludedCount: foreign.length,
      excludedCurrencies: foreign.map((e) => e.currency).toSet(),
    );
  }

  /// The last [months] months ending at [year]/[month], oldest first. The
  /// trend is a list of Rollups rather than a computation of its own, so the
  /// bar a month shows here and the breakdown that month opens into are the
  /// same arithmetic. A month nobody spent anything in comes back empty rather
  /// than missing, so a gap in the Ledger reads as a gap.
  static List<Rollup> trailing(
    List<Expense> ledger, {
    required int year,
    required int month,
    required int months,
    required String homeCurrency,
  }) => List.generate(months, (index) {
    final at = DateTime(year, month - (months - 1 - index));
    return Rollup.forMonth(
      ledger,
      year: at.year,
      month: at.month,
      homeCurrency: homeCurrency,
    );
  });

  /// Whether there is anything to chart. False for a month with no Expenses,
  /// and for one whose Expenses were all in another currency — in both cases
  /// the honest picture is nothing rather than bars of zero.
  bool get hasSpending => expenseCount > 0;

  /// The month before this one, as numbers. Whoever shows it names it; the
  /// domain holds no month names (ADR-0007).
  int get previousYear => DateTime(year, month - 1).year;

  int get previousMonth => DateTime(year, month - 1).month;

  double get delta => total - previousTotal;

  /// Null when there is no previous month to compare against, rather than a
  /// meaningless infinity or zero.
  double? get percentChange =>
      previousTotal == 0 ? null : delta / previousTotal * 100;

  double get dailyAverage {
    final days = DateTime(year, month + 1, 0).day;
    return days == 0 ? 0 : total / days;
  }

  DayTotal? get heaviestDay {
    if (byDay.isEmpty) return null;
    final heaviest = byDay.entries.reduce((a, b) => b.value > a.value ? b : a);
    return DayTotal(heaviest.key, heaviest.value);
  }
}

/// The Expenses a month holds, in every currency — the Ledger's own view of a
/// month, before aggregation leaves the foreign ones out. One filter, so the
/// list on screen and the totals beside it cannot disagree about which month an
/// Expense is in.
List<Expense> expensesIn(
  List<Expense> ledger, {
  required int year,
  required int month,
}) =>
    ledger.where((e) => e.date.year == year && e.date.month == month).toList();

const int _topPurchases = 5;

Map<String, double> _sumByCategory(Iterable<Expense> expenses) {
  final sums = <String, double>{};
  for (final expense in expenses) {
    sums[expense.category] = (sums[expense.category] ?? 0) + expense.total;
  }
  return sums;
}
