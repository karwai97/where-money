/// The spend taxonomy. Closed on purpose: it is sent to the Model as a JSON
/// Schema `enum`, which is what makes the Category a guaranteed member of a
/// known set rather than free text the app has to interpret. See ADR-0005.
///
/// Slugs only. What a Category is called in front of the user is the app's
/// business, because it is called something different in every language
/// (ADR-0007).
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

const List<String> paymentMethods = [
  'cash',
  'card',
  'ewallet',
  'bank_transfer',
  'unknown',
];
