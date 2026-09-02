/// How things read in the app: dates, money, counts, and what the domain's
/// closed sets are called in front of a user. One definition each, so the
/// Ledger and the Inbox cannot drift into two house styles.
///
/// The words live here rather than in `packages/core` because a Category, a
/// payment method and a month are named differently in every language, while
/// the slug is the same everywhere. See ADR-0007.
library;

import 'package:intl/intl.dart';
import 'package:where_money_core/where_money_core.dart';

import 'l10n/app_localizations.dart';

/// Dates are the one set of words this app does not write. The names of the
/// months and the order the parts go in come out of the CLDR data
/// `flutter_localizations` loads for the locale on the `MaterialApp`, which is
/// why every one of these takes the words rather than a language code.
String asDay(AppLocalizations words, DateTime at) =>
    DateFormat.yMMMd(words.localeName).format(at);

String asMoment(AppLocalizations words, DateTime at) =>
    DateFormat.yMMMd(words.localeName).add_jm().format(at);

/// Money is deliberately not locale-formatted. A locale renders whichever
/// currency symbol it is used to whatever the amount is actually in, and the
/// Home Currency rule (ADR-0006) depends on a foreign-currency Expense looking
/// foreign. So an amount keeps its explicit ISO code in every language.
String asMoney(String currency, double amount) =>
    '$currency ${amount.toStringAsFixed(2)}';

/// When an Expense happened and what it was for, on one line. The Ledger and
/// an opened Expense both print it, and the separator is punctuation rather
/// than a word, so it is one definition here instead of the same message
/// copied under two screen prefixes.
String dayAndCategory(AppLocalizations words, DateTime at, String category) =>
    '${asDay(words, at)} · ${categoryLabel(words, category)}';

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
  String monthLabel(AppLocalizations words) =>
      DateFormat.yMMMM(words.localeName).format(DateTime(year, month));

  /// Short enough for an axis on a phone. Not the first three letters of the
  /// long name: that is an English coincidence, and in Chinese it cuts a
  /// character off the middle of `8月`.
  String shortMonthLabel(AppLocalizations words) =>
      DateFormat.MMM(words.localeName).format(DateTime(year, month));

  String previousMonthLabel(AppLocalizations words) => DateFormat.yMMMM(
    words.localeName,
  ).format(DateTime(previousYear, previousMonth));
}
