/// The fields of an Extraction that Review can change. Naming them once means
/// a Finding can say which field it is about, and a Corrected Field recorded
/// on a committed Expense is the same vocabulary rather than a loose string.
library;

enum ReviewField {
  merchant,
  purchasedAt,
  currency,
  subtotal,
  tax,
  tip,
  total,
  paymentMethod,
  category,
  lineItems,
}

/// The fields of a Line Item that Review can change. Every one of them is a
/// correction to [ReviewField.lineItems] as far as the tally is concerned —
/// the row a user retyped is not the interesting grain, the fact that they had
/// to retype a row is.
enum LineItemField { description, quantity, unitPrice, amount, category }

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
