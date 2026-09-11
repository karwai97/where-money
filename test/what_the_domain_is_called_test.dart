import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/l10n/app_localizations.dart';
import 'package:where_money/l10n/app_localizations_en.dart';
import 'package:where_money/l10n/app_localizations_zh.dart';
import 'package:where_money/on_screen.dart';
import 'package:where_money_core/where_money_core.dart';

/// The domain holds the closed sets and the app holds their words (ADR-0007),
/// which leaves a gap: a slug added to the taxonomy with no copy beside it
/// prints as `personal_care` across the Ledger, the charts and the Review
/// dropdown with nothing failing. These are the tests that were in the domain
/// package before the words moved.
///
/// Every set is checked in every language the domain knows. A slug can only be
/// missing from one of them, and the fallback that keeps it readable is also
/// what hides it.
void main() {
  // Dates and month names are the one set of words this app does not write:
  // they come out of the CLDR data `flutter_localizations` loads per locale,
  // which a MaterialApp does for itself and a unit test has to ask for.
  setUpAll(() async {
    for (final language in languages) {
      await GlobalMaterialLocalizations.delegate.load(Locale(language));
    }
  });

  for (final language in languages) {
    final words = lookupAppLocalizations(Locale(language));

    group('in $language', () {
      test('every Category has copy to show the user', () {
        for (final category in categories) {
          expect(categoryLabel(words, category), isNot(category));
        }
      });

      test('every payment method has copy to show the user', () {
        for (final method in paymentMethods) {
          expect(paymentMethodLabel(words, method), isNot(method));
        }
      });

      test('both ways an Expense can have got here have copy', () {
        for (final source in ExpenseSource.values) {
          expect(source.labelIn(words), isNot(source.name));
        }
      });

      test('an Expense with no merchant is called something', () {
        expect(merchantLabel(words, null), isNotEmpty);
        expect(merchantLabel(words, 'Kopitiam SS2'), 'Kopitiam SS2');
      });

      test('every field Review can change has copy to show the user', () {
        for (final field in ReviewField.values) {
          expect(field.labelIn(words), isNot(field.name));
          expect(reviewFieldLabel(words, field.name), field.labelIn(words));
        }
      });

      test('every language is named in its own language, identically', () {
        // The dropdown names each language in itself so a reader can find
        // theirs without already reading this one, which only works if the
        // name does not change with the language it is read in.
        final english = AppLocalizationsEn();
        for (final named in languages) {
          expect(languageLabel(words, named), languageLabel(english, named));
          expect(languageLabel(words, named), isNot(named));
        }
      });
    });
  }

  test('a slug this app has no words for reads as itself', () {
    final words = AppLocalizationsEn();

    expect(categoryLabel(words, 'sundries'), 'sundries');
    expect(paymentMethodLabel(words, 'crypto'), 'crypto');
    expect(reviewFieldLabel(words, 'vatNumber'), 'vatNumber');
  });

  test('a month is named the way the language names months', () {
    final august = Rollup.forMonth(
      const [],
      year: 2026,
      month: 8,
      homeCurrency: 'MYR',
    );

    expect(august.monthLabel(AppLocalizationsEn()), 'August 2026');
    expect(august.shortMonthLabel(AppLocalizationsEn()), 'Aug');
    expect(august.previousMonthLabel(AppLocalizationsEn()), 'July 2026');

    expect(august.monthLabel(AppLocalizationsZh()), '2026年8月');
    expect(august.shortMonthLabel(AppLocalizationsZh()), '8月');
    expect(august.previousMonthLabel(AppLocalizationsZh()), '2026年7月');

    final january = Rollup.forMonth(
      const [],
      year: 2026,
      month: 1,
      homeCurrency: 'MYR',
    );

    expect(january.previousMonthLabel(AppLocalizationsEn()), 'December 2025');
    expect(january.previousMonthLabel(AppLocalizationsZh()), '2025年12月');
  });

  test('a day is written the way the language writes dates', () {
    final at = DateTime(2026, 8, 27);

    expect(asDay(AppLocalizationsEn(), at), 'Aug 27, 2026');
    expect(asDay(AppLocalizationsZh(), at), '2026年8月27日');
  });

  test('a moment carries the time as well, in the same house style', () {
    final at = DateTime(2026, 8, 27, 14, 5);

    expect(asMoment(AppLocalizationsEn(), at), startsWith('Aug 27, 2026'));
    expect(asMoment(AppLocalizationsZh(), at), startsWith('2026年8月27日'));
    // English reads the clock in halves of a day and Chinese reads it whole.
    expect(asMoment(AppLocalizationsEn(), at), contains('2:05'));
    expect(asMoment(AppLocalizationsZh(), at), contains('14:05'));
  });

  test('a day and a Category read as one line in either language', () {
    final at = DateTime(2026, 8, 27);

    expect(
      dayAndCategory(AppLocalizationsEn(), at, 'home'),
      'Aug 27, 2026 · Home',
    );
    expect(dayAndCategory(AppLocalizationsZh(), at, 'home'), '2026年8月27日 · 居家');
  });
}
