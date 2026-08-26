import 'package:test/test.dart';
import 'package:where_money_core/where_money_core.dart';

void main() {
  Expense expense(
    String id, {
    ExpenseSource source = ExpenseSource.scanned,
    List<String> corrected = const [],
  }) => Expense(
    id: id,
    merchant: 'Village Grocer',
    date: DateTime(2026, 8, 3),
    currency: 'MYR',
    total: 44.10,
    category: 'groceries',
    lineItems: const [],
    source: source,
    needsReview: false,
    correctedFields: corrected,
  );

  test('an empty Ledger has measured nothing', () {
    final tally = CorrectedFields.across(const []);

    expect(tally.scanned, 0);
    expect(tally.clean, 0);
    expect(tally.byField, isEmpty);
  });

  test('a field is counted once per Expense the user changed it on', () {
    final tally = CorrectedFields.across([
      expense('a', corrected: const ['merchant', 'category']),
      expense('b', corrected: const ['merchant']),
      expense('c'),
    ]);

    expect(tally.scanned, 3);
    expect(tally.clean, 1);
    expect(tally.byField, {'merchant': 2, 'category': 1});
  });

  test(
    'the most-corrected field is first, so the misread is the thing read',
    () {
      final tally = CorrectedFields.across([
        expense('a', corrected: const ['total']),
        expense('b', corrected: const ['merchant', 'total']),
        expense('c', corrected: const ['merchant', 'total']),
      ]);

      expect(tally.byField.keys.first, 'total');
    },
  );

  test('an Expense typed by hand is not evidence about a Model', () {
    final tally = CorrectedFields.across(seedCorrectedLedger());

    expect(tally.scanned, 3);
    expect(tally.byField, {'merchant': 2, 'category': 1});
  });
}
