import 'package:test/test.dart';
import 'package:where_money_core/where_money_core.dart';

void main() {
  test('the fixtures only ever use Categories the taxonomy knows', () {
    for (final extraction in [cleanExtraction, flawedExtraction]) {
      expect(categories, contains(extraction.category));
      expect(paymentMethods, contains(extraction.paymentMethod));
      for (final item in extraction.lineItems) {
        expect(categories, contains(item.category));
      }
    }
  });

  test('every currency code is three upper-case letters, listed once', () {
    expect(isoCurrencies, everyElement(matches(RegExp(r'^[A-Z]{3}$'))));
    expect(isoCurrencies.toSet(), hasLength(isoCurrencies.length));
  });

  test(
    'the currency list is alphabetical, which is the order it is read in',
    () {
      expect(isoCurrencies, orderedEquals([...isoCurrencies]..sort()));
    },
  );

  test('the currencies this app was written around are all in the set', () {
    expect(isoCurrencies, containsAll(['MYR', 'SGD', 'USD', 'EUR', 'GBP']));
  });

  test('nothing reserved for testing or for metal is offered as money', () {
    expect(isoCurrencies, isNot(contains('XXX')));
    expect(isoCurrencies, isNot(contains('XTS')));
    expect(isoCurrencies, isNot(contains('XAU')));
  });

  test('every alias points at a currency the set knows', () {
    for (final code in currencyAliases.values) {
      expect(isoCurrencies, contains(code));
    }
  });

  test('no symbol that means more than one currency is an alias', () {
    for (final symbol in const [r'$', '¥', 'kr', '£€']) {
      expect(currencyAliases.keys, isNot(contains(symbol)));
    }
  });

  test('what a receipt prints reads as the code it means', () {
    expect(currencyFrom('RM'), 'MYR');
    expect(currencyFrom(r'S$'), 'SGD');
    expect(currencyFrom('£'), 'GBP');
    expect(currencyFrom(' myr '), 'MYR');
  });

  test('what the app cannot place stays unplaced', () {
    for (final read in const [r'$', 'XYZ', '???', '', '  ']) {
      expect(currencyFrom(read), isNull);
    }
  });
}
