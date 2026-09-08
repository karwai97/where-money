import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/l10n/app_localizations_en.dart';
import 'package:where_money/on_screen.dart';
import 'package:where_money_core/where_money_core.dart';

/// The total a month came to, and how it reads against the month before it.
/// Both the Ledger's header and the chart detail print these, so they are one
/// definition tested once rather than the same arithmetic on two screens.
void main() {
  final words = AppLocalizationsEn();

  // Month names come out of the CLDR data `flutter_localizations` loads per
  // locale, which a MaterialApp does for itself and a unit test has to ask for.
  setUpAll(() => GlobalMaterialLocalizations.delegate.load(const Locale('en')));

  Rollup month({required double total, required double previousTotal}) =>
      Rollup(
        year: 2025,
        month: 9,
        homeCurrency: 'MYR',
        total: total,
        previousTotal: previousTotal,
        expenseCount: 24,
        scannedCount: 20,
        needsReviewCount: 0,
        byCategory: const [],
        byDay: const {},
        largest: const [],
        excludedCount: 0,
        excludedCurrencies: const {},
      );

  group('the figure on its own', () {
    test('carries two decimals and no thousands separator', () {
      // ADR-0006's whole point is that a foreign Expense looks foreign, which
      // is why the code is never dropped and the figure is never localised.
      expect(asAmount(1284.60), '1284.60');
      expect(asAmount(8.5), '8.50');
      expect(asAmount(0), '0.00');
    });

    test('is the same figure asMoney prints', () {
      expect(asMoney('MYR', 1284.60), 'MYR ${asAmount(1284.60)}');
    });
  });

  group('how the month reads against the one before', () {
    test('a month with nothing before it has nothing to compare against', () {
      expect(
        month(total: 500, previousTotal: 0).comparedWithPreviousMonth(words),
        'Nothing was spent in August 2025 to compare against.',
      );
    });

    test('spending more says so, rounded', () {
      // 1284.60 against 1147.05 is 11.99%, which reads as 12.
      expect(
        month(
          total: 1284.60,
          previousTotal: 1147.05,
        ).comparedWithPreviousMonth(words),
        '12% more than August 2025.',
      );
    });

    test('spending less says so', () {
      expect(
        month(total: 500, previousTotal: 1000).comparedWithPreviousMonth(words),
        '50% less than August 2025.',
      );
    });

    test('a change too small to round to a percent is about the same', () {
      expect(
        month(
          total: 1000.40,
          previousTotal: 1000,
        ).comparedWithPreviousMonth(words),
        'About the same as August 2025.',
      );
    });
  });
}
