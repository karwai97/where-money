import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/on_screen.dart';
import 'package:where_money_core/where_money_core.dart';

/// The domain holds the closed sets and the app holds their words (ADR-0007),
/// which leaves a gap: a slug added to the taxonomy with no copy beside it
/// prints as `personal_care` across the Ledger, the charts and the Review
/// dropdown with nothing failing. These are the tests that were in the domain
/// package before the words moved.
void main() {
  test('every Category has copy to show the user', () {
    for (final category in categories) {
      expect(categoryLabel(category), isNot(category));
    }
  });

  test('every payment method has copy to show the user', () {
    for (final method in paymentMethods) {
      expect(paymentMethodLabel(method), isNot(method));
    }
  });

  test('every field Review can change has copy to show the user', () {
    for (final field in ReviewField.values) {
      expect(field.label, isNot(field.name));
      expect(reviewFieldLabel(field.name), field.label);
    }
  });

  test('a month is named from the year and month the Rollup exposes', () {
    final august = Rollup.forMonth(
      const [],
      year: 2026,
      month: 8,
      homeCurrency: 'MYR',
    );

    expect(august.monthLabel, 'August 2026');
    expect(august.shortMonthLabel, 'Aug');
    expect(august.previousMonthLabel, 'July 2026');

    final january = Rollup.forMonth(
      const [],
      year: 2026,
      month: 1,
      homeCurrency: 'MYR',
    );

    expect(january.previousMonthLabel, 'December 2025');
  });
}
