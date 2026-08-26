/// The spend taxonomy. Closed on purpose: it is sent to the Model as a JSON
/// Schema `enum`, which is what makes the Category a guaranteed member of a
/// known set rather than free text the app has to interpret. See ADR-0005.
library;

const List<String> categories = [
  'groceries',
  'dining',
  'transport',
  'fuel',
  'utilities',
  'healthcare',
  'pharmacy',
  'entertainment',
  'shopping',
  'apparel',
  'home',
  'electronics',
  'travel',
  'education',
  'personal_care',
  'subscriptions',
  'fees_charges',
  'other',
];

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

String categoryLabel(String category) => categoryLabels[category] ?? category;

const List<String> paymentMethods = [
  'cash',
  'card',
  'ewallet',
  'bank_transfer',
  'unknown',
];

const Map<String, String> paymentMethodLabels = {
  'cash': 'Cash',
  'card': 'Card',
  'ewallet': 'E-wallet',
  'bank_transfer': 'Bank transfer',
  'unknown': 'Not recorded',
};

String paymentMethodLabel(String method) =>
    paymentMethodLabels[method] ?? method;
