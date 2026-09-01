/// How things read in the app: dates, money, counts, and what the domain's
/// closed sets are called in front of a user. One definition each, so the
/// Ledger and the Inbox cannot drift into two house styles.
///
/// The words live here rather than in `packages/core` because a Category, a
/// payment method and a month are named differently in every language, while
/// the slug is the same everywhere. See ADR-0007.
library;

import 'package:where_money_core/where_money_core.dart';

String asDay(DateTime at) => '${at.year}-${_two(at.month)}-${_two(at.day)}';

String asMoment(DateTime at) =>
    '${asDay(at)} ${_two(at.hour)}:${_two(at.minute)}';

String _two(int value) => value.toString().padLeft(2, '0');

String asMoney(String currency, double amount) =>
    '$currency ${amount.toStringAsFixed(2)}';

String asExpenses(int count) => count == 1 ? '1 Expense' : '$count Expenses';

String asReceipts(int count) => count == 1 ? '1 receipt' : '$count receipts';

const Map<String, String> categoryLabels = {
  'groceries': 'Groceries',
  'dining': 'Dining out',
  'transport': 'Transport',
  'fuel': 'Fuel',
  'utilities': 'Utilities',
  'healthcare': 'Healthcare',
  'pharmacy': 'Pharmacy',
  'entertainment': 'Entertainment',
  'shopping': 'Shopping',
  'apparel': 'Apparel',
  'home': 'Home',
  'electronics': 'Electronics',
  'travel': 'Travel',
  'education': 'Education',
  'personal_care': 'Personal care',
  'subscriptions': 'Subscriptions',
  'fees_charges': 'Fees & charges',
  'other': 'Other',
};

/// A slug this app has no label for reads as itself rather than disappearing.
String categoryLabel(String category) => categoryLabels[category] ?? category;

const Map<String, String> paymentMethodLabels = {
  'cash': 'Cash',
  'card': 'Card',
  'ewallet': 'E-wallet',
  'bank_transfer': 'Bank transfer',
  'unknown': 'Not recorded',
};

String paymentMethodLabel(String method) =>
    paymentMethodLabels[method] ?? method;

extension ReviewFieldLabel on ReviewField {
  /// What this field is called in front of the user. One definition, so the
  /// Review form and the Corrected Fields tally cannot end up calling the same
  /// field two things.
  String get label => switch (this) {
    ReviewField.merchant => 'Merchant',
    ReviewField.purchasedAt => 'Date',
    ReviewField.currency => 'Currency',
    ReviewField.subtotal => 'Subtotal',
    ReviewField.tax => 'Tax',
    ReviewField.tip => 'Tip',
    ReviewField.total => 'Total',
    ReviewField.paymentMethod => 'Paid with',
    ReviewField.category => 'Category',
    ReviewField.lineItems => 'Line Items',
  };
}

/// A Corrected Field as an Expense recorded it, which is a bare name by the
/// time it has been through Firestore. A name this app no longer has a field
/// for reads as itself rather than disappearing.
String reviewFieldLabel(String name) =>
    ReviewField.values
        .where((field) => field.name == name)
        .firstOrNull
        ?.label ??
    name;

extension CategoryTotalLabel on CategoryTotal {
  String get label => categoryLabel(category);
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
