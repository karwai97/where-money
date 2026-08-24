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
