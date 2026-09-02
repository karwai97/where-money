/// How things read in the app: dates, money, counts, and what the domain's
/// closed sets are called in front of a user. One definition each, so the
/// Ledger and the Inbox cannot drift into two house styles.
///
/// The words live here rather than in `packages/core` because a Category, a
/// payment method and a month are named differently in every language, while
/// the slug is the same everywhere. See ADR-0007.
library;

import 'package:where_money_core/where_money_core.dart';

import 'l10n/app_localizations.dart';

String asDay(DateTime at) => '${at.year}-${_two(at.month)}-${_two(at.day)}';

String asMoment(DateTime at) =>
    '${asDay(at)} ${_two(at.hour)}:${_two(at.minute)}';

String _two(int value) => value.toString().padLeft(2, '0');

String asMoney(String currency, double amount) =>
    '$currency ${amount.toStringAsFixed(2)}';

String asExpenses(int count) => count == 1 ? '1 Expense' : '$count Expenses';

/// A slug this app has no words for reads as itself rather than disappearing.
/// `what_the_domain_is_called_test.dart` is what stops that fallback from
/// quietly covering a Category the message files forgot.
String categoryLabel(AppLocalizations words, String category) =>
    switch (category) {
      'groceries' => words.categoryGroceries,
      'dining' => words.categoryDining,
      'transport' => words.categoryTransport,
      'fuel' => words.categoryFuel,
      'utilities' => words.categoryUtilities,
      'healthcare' => words.categoryHealthcare,
      'pharmacy' => words.categoryPharmacy,
      'entertainment' => words.categoryEntertainment,
      'shopping' => words.categoryShopping,
      'apparel' => words.categoryApparel,
      'home' => words.categoryHome,
      'electronics' => words.categoryElectronics,
      'travel' => words.categoryTravel,
      'education' => words.categoryEducation,
      'personal_care' => words.categoryPersonalCare,
      'subscriptions' => words.categorySubscriptions,
      'fees_charges' => words.categoryFeesCharges,
      'other' => words.categoryOther,
      _ => category,
    };

String paymentMethodLabel(AppLocalizations words, String method) =>
    switch (method) {
      'cash' => words.paymentMethodCash,
      'card' => words.paymentMethodCard,
      'ewallet' => words.paymentMethodEwallet,
      'bank_transfer' => words.paymentMethodBankTransfer,
      'unknown' => words.paymentMethodUnknown,
      _ => method,
    };

extension ReviewFieldLabel on ReviewField {
  /// What this field is called in front of the user. One definition, so the
  /// Review form and the Corrected Fields tally cannot end up calling the same
  /// field two things.
  String labelIn(AppLocalizations words) => switch (this) {
    ReviewField.merchant => words.fieldMerchant,
    ReviewField.purchasedAt => words.fieldPurchasedAt,
    ReviewField.currency => words.fieldCurrency,
    ReviewField.subtotal => words.fieldSubtotal,
    ReviewField.tax => words.fieldTax,
    ReviewField.tip => words.fieldTip,
    ReviewField.total => words.fieldTotal,
    ReviewField.paymentMethod => words.fieldPaymentMethod,
    ReviewField.category => words.fieldCategory,
    ReviewField.lineItems => words.fieldLineItems,
  };
}

/// A Corrected Field as an Expense recorded it, which is a bare name by the
/// time it has been through Firestore. A name this app no longer has a field
/// for reads as itself rather than disappearing.
String reviewFieldLabel(AppLocalizations words, String name) =>
    ReviewField.values
        .where((field) => field.name == name)
        .firstOrNull
        ?.labelIn(words) ??
    name;

extension CategoryTotalLabel on CategoryTotal {
  String labelIn(AppLocalizations words) => categoryLabel(words, category);
}

/// The Rollup carries a year and a month; naming the month is the screen's job.
extension RollupLabels on Rollup {
  String get monthLabel => '${_monthNames[month - 1]} $year';

  /// Short enough for an axis on a phone.
  String get shortMonthLabel => _monthNames[month - 1].substring(0, 3);

  String get previousMonthLabel =>
      '${_monthNames[previousMonth - 1]} $previousYear';
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
