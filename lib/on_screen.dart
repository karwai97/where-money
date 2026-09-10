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

/// A mark in the case the screen draws it rather than the case the message
/// files hold it in. The design shouts the name of a screen, of a field, of a
/// column head and of the one action a screen exists for, and that is
/// typography rather than wording — so the casing happens here and the ARB
/// files stay in sentence case (ADR-0007).
///
/// Only where the language has an upper case to go to. `toUpperCase()` on
/// Chinese looks like a no-op and is not one: it leaves the characters alone
/// and shouts whatever Latin the string carries. "锁定 Where Money" came out
/// "锁定 WHERE MONEY", beside three marks that read as written. The app's own
/// name, "PIN", "Android", "Google" and "ISO" all sit inside Chinese copy, so
/// this is a class of thing rather than the one label that caught it.
String cased(AppLocalizations words, String text) =>
    _withoutLetterCase.contains(words.localeName.split('_').first)
    ? text
    : text.toUpperCase();

/// The languages this app can be read in whose script has no upper case to go
/// to. A language added to `languages` belongs in here only if the same is
/// true of it.
const _withoutLetterCase = {'zh'};

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
    '$currency ${asAmount(amount)}';

/// The figure with no code in front of it, for the one caller that prints the
/// code itself: the Ledger sets the ISO code smaller and beside the number, so
/// a column of amounts lines up on its digits. Kept here, and used by
/// [asMoney], so there is one answer to how many decimals an amount has and
/// whether it ever carries a thousands separator. It does not.
String asAmount(double amount) => amount.toStringAsFixed(2);

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

/// A merchant is transcribed off the paper and is never translated; its
/// absence is. Read on the Ledger, on an opened Expense and in the dialog that
/// deletes one, so it sits here with the domain's other vocabulary rather than
/// under a screen prefix.
String merchantLabel(AppLocalizations words, String? merchant) =>
    merchant ?? words.merchantUnknown;

extension ExpenseSourceLabel on ExpenseSource {
  /// How much of the Ledger the app produced, in as few words as a tooltip on
  /// an icon can carry. `HowItGotHere` is the only caller and it is read from
  /// two screens, which is why this is not `expense*` or `ledger*`.
  String labelIn(AppLocalizations words) => switch (this) {
    ExpenseSource.scanned => words.expenseSourceScanned,
    ExpenseSource.manual => words.expenseSourceManual,
  };
}

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

/// A month spelled out. Takes a date rather than a Rollup because two of the
/// three things that name a month have no Rollup to hand: the pill back to the
/// month the app opened in, and the year over the sheet of months.
String asMonth(AppLocalizations words, DateTime month) =>
    DateFormat.yMMMM(words.localeName).format(month);

/// The month and year small enough to sit beside a total. Not [asShortMonth]
/// with a year stuck on: the order of the two parts is the locale's business,
/// not this app's.
String asShortMonthAndYear(AppLocalizations words, DateTime month) =>
    DateFormat.yMMM(words.localeName).format(month);

/// The year on its own, which in Chinese is `2026年` rather than `2026`.
String asYear(AppLocalizations words, DateTime month) =>
    DateFormat.y(words.localeName).format(month);

/// The Rollup carries a year and a month; naming the month is the screen's job.
extension RollupLabels on Rollup {
  String monthLabel(AppLocalizations words) =>
      asMonth(words, DateTime(year, month));

  /// Short enough for an axis on a phone, or for a grid of twelve. Not the
  /// first three letters of the long name: that is an English coincidence,
  /// and in Chinese it cuts a character off the middle of `8月`.
  String shortMonthLabel(AppLocalizations words) =>
      DateFormat.MMM(words.localeName).format(DateTime(year, month));

  String previousMonthLabel(AppLocalizations words) =>
      asMonth(words, DateTime(previousYear, previousMonth));

  String shortMonthAndYearLabel(AppLocalizations words) =>
      asShortMonthAndYear(words, DateTime(year, month));

  /// How the month reads against the one before it. Printed by the Ledger's
  /// header and by the chart detail, so the rounding and the three ways it can
  /// come out are settled once — a month that spent 0.4% more says "about the
  /// same" on both screens rather than "0% more" on one of them.
  String comparedWithPreviousMonth(AppLocalizations words) {
    final previous = previousMonthLabel(words);
    final change = percentChange;

    if (change == null) return words.rollupNothingToCompare(previous);
    if (change.abs() < 0.5) return words.rollupAboutTheSame(previous);

    final percent = change.abs().round();
    return change > 0
        ? words.rollupMoreThan(percent, previous)
        : words.rollupLessThan(percent, previous);
  }
}
