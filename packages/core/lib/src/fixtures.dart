/// Canned Extractions — one clean receipt, one deliberately flawed — and a
/// seeded month of Expenses. They are the backbone of the tests and the
/// material a fake gateway hands back, so the app is inspectable before a
/// single call is made.
library;

import 'expense.dart';
import 'extraction.dart';

/// The instant the canned Extractions are written against. Pass it to the
/// Check as `now` so the date heuristics are asserted against a fixed clock
/// rather than against whenever the suite happens to run.
final DateTime fixtureNow = DateTime(2026, 8, 23);

/// Everything reconciles: line items sum to the subtotal, subtotal plus tax
/// reaches the total, each line's quantity times unit price is its amount, and
/// the date is recent. The Check finds nothing.
const Extraction cleanExtraction = Extraction(
  isReceipt: true,
  merchant: 'Village Grocer Bangsar',
  purchasedAt: '2026-08-21',
  currency: 'MYR',
  subtotal: 41.60,
  tax: 2.50,
  tip: null,
  total: 44.10,
  paymentMethod: 'card',
  category: 'groceries',
  categoryReason: 'Fresh food and household staples, nothing else on the bill.',
  lineItems: [
    LineItem(
      description: 'Farm Fresh Milk 1L',
      quantity: 2,
      unitPrice: 8.50,
      amount: 17.00,
      category: 'groceries',
    ),
    LineItem(
      description: 'Wholemeal Bread',
      quantity: 1,
      unitPrice: 4.40,
      amount: 4.40,
      category: 'groceries',
    ),
    LineItem(
      description: 'Free Range Eggs 10s',
      quantity: 1,
      unitPrice: 12.90,
      amount: 12.90,
      category: 'groceries',
    ),
    LineItem(
      description: 'Cavendish Bananas',
      quantity: 1,
      unitPrice: 7.30,
      amount: 7.30,
      category: 'groceries',
    ),
  ],
  needsReview: false,
  reviewReasons: [],
);

/// Flawed on purpose, in the two ways a creased receipt actually fails: the
/// line items sum to 21.40 against a subtotal of 22.90 because a row was cut
/// off, and the date was not legible at all. It exercises the flagged lane
/// without needing a bad photo.
const Extraction flawedExtraction = Extraction(
  isReceipt: true,
  merchant: 'Jaya Grocer Bangsar',
  purchasedAt: null,
  currency: 'MYR',
  subtotal: 22.90,
  tax: 1.37,
  tip: null,
  total: 24.27,
  paymentMethod: 'card',
  category: 'groceries',
  categoryReason: 'Almost all of the spend is fresh food and household milk.',
  lineItems: [
    LineItem(
      description: 'Farm Fresh Milk 1L',
      quantity: 2,
      unitPrice: 8.50,
      amount: 17.00,
      category: 'groceries',
    ),
    LineItem(
      description: 'Wholemeal Bread',
      quantity: 1,
      unitPrice: 4.40,
      amount: 4.40,
      category: 'groceries',
    ),
  ],
  needsReview: true,
  reviewReasons: [
    'The date is creased and could not be read.',
    'A third line item is cut off at the bottom edge of the photo.',
  ],
);

/// A photo that was never a receipt. Offered for discard, not for Review.
const Extraction notAReceiptExtraction = Extraction(
  isReceipt: false,
  merchant: '',
  purchasedAt: null,
  currency: '',
  subtotal: null,
  tax: null,
  tip: null,
  total: 0,
  paymentMethod: 'unknown',
  category: 'other',
  categoryReason: '',
  lineItems: [],
  needsReview: false,
  reviewReasons: [],
);

/// Two months of a plausible Ledger, hung off [around] so the current month is
/// always populated no matter when this is opened. The two foreign Expenses
/// are there on purpose: they are what the Rollup has to exclude and count.
List<Expense> seedLedger({DateTime? around}) {
  final base = around ?? DateTime.now();
  final thisMonth = DateTime(base.year, base.month);
  final lastMonth = DateTime(base.year, base.month - 1);

  var sequence = 0;
  Expense spent(
    DateTime month,
    int day,
    String merchant,
    double total,
    String category, {
    String currency = 'MYR',
    ExpenseSource source = ExpenseSource.scanned,
    bool needsReview = false,
  }) {
    sequence++;
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return Expense(
      id: 'seed-$sequence',
      merchant: merchant,
      date: DateTime(month.year, month.month, day.clamp(1, lastDay)),
      currency: currency,
      total: total,
      category: category,
      lineItems: const [],
      source: source,
      needsReview: needsReview,
    );
  }

  return [
    spent(thisMonth, 2, 'Jaya Grocer Bangsar', 184.20, 'groceries'),
    spent(thisMonth, 3, 'Grab', 18.40, 'transport'),
    spent(thisMonth, 4, 'Kopitiam SS2', 26.00, 'dining',
        source: ExpenseSource.manual),
    spent(thisMonth, 5, 'Petronas Damansara', 120.00, 'fuel'),
    spent(thisMonth, 7, 'Tenaga Nasional', 168.55, 'utilities'),
    spent(thisMonth, 8, 'Guardian Pharmacy', 47.90, 'pharmacy',
        needsReview: true),
    spent(thisMonth, 9, 'Village Grocer', 96.15, 'groceries'),
    spent(thisMonth, 11, 'Netflix', 54.90, 'subscriptions'),
    spent(thisMonth, 12, 'Uniqlo Mid Valley', 219.00, 'apparel'),
    spent(thisMonth, 13, 'Grab', 22.10, 'transport'),
    spent(thisMonth, 14, "Nando's", 78.40, 'dining'),
    spent(thisMonth, 16, 'Jaya Grocer Bangsar', 142.75, 'groceries'),
    spent(thisMonth, 17, 'GSC Cinemas', 44.00, 'entertainment'),
    spent(thisMonth, 18, 'Klinik Kesihatan', 85.00, 'healthcare'),
    spent(thisMonth, 19, 'Shopee', 63.30, 'shopping', needsReview: true),
    spent(thisMonth, 21, 'Petronas Damansara', 115.00, 'fuel'),
    spent(thisMonth, 22, 'Starbucks KLCC', 31.20, 'dining'),
    spent(thisMonth, 23, 'Ikea Damansara', 289.90, 'home'),
    spent(thisMonth, 20, 'Steam', 24.99, 'entertainment',
        currency: 'USD', source: ExpenseSource.manual),

    spent(lastMonth, 3, 'Jaya Grocer Bangsar', 201.40, 'groceries'),
    spent(lastMonth, 5, 'Petronas Damansara', 118.00, 'fuel'),
    spent(lastMonth, 8, 'Tenaga Nasional', 152.30, 'utilities'),
    spent(lastMonth, 10, 'Grab', 46.80, 'transport'),
    spent(lastMonth, 12, 'Village Grocer', 88.20, 'groceries'),
    spent(lastMonth, 15, 'Netflix', 54.90, 'subscriptions'),
    spent(lastMonth, 18, 'Sushi Zanmai', 112.60, 'dining'),
    spent(lastMonth, 20, 'Watsons', 39.10, 'personal_care'),
    spent(lastMonth, 24, 'AirAsia', 428.00, 'travel',
        source: ExpenseSource.manual),
    spent(lastMonth, 27, 'Kopitiam SS2', 24.50, 'dining'),
    spent(lastMonth, 26, 'Changi Duty Free', 88.00, 'shopping',
        currency: 'SGD'),
  ];
}

/// A Ledger with Review's corrections on it, for anything that reads the
/// Corrected Fields tally. The hand-typed Expense carries corrections too:
/// without them there would be nothing for the filter that leaves it out to be
/// tested against.
List<Expense> seedCorrectedLedger() {
  Expense reviewed(String id,
          {ExpenseSource source = ExpenseSource.scanned,
          List<String> corrected = const []}) =>
      Expense(
        id: id,
        merchant: 'Village Grocer',
        date: DateTime(2026, 8, 3),
        currency: 'MYR',
        total: 44.10,
        category: 'groceries',
        lineItems: const [],
        source: source,
        needsReview: false,
        correctedFields: corrected,
      );

  return [
    reviewed('corrected-1', corrected: const ['merchant', 'category']),
    reviewed('corrected-2', corrected: const ['merchant']),
    reviewed('corrected-3'),
    reviewed('typed-1',
        source: ExpenseSource.manual,
        corrected: const ['merchant', 'total', 'category']),
  ];
}
