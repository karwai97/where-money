// The JSON Schema handed to the Responses API, ported from the prototype's
// Dart. It is the contract that makes the Extraction parseable rather than
// hopeful, and the Category enum is what makes that field a member of a known
// set instead of free text the app has to interpret.
//
// Strict mode rejects a good deal of ordinary JSON Schema, and the rejections
// are easy to "fix" wrongly later:
//   * every object carries additionalProperties: false
//   * every property is listed in required — there are no optional fields, so
//     optionality is a ["number", "null"] type union instead
//   * the root is an object and does not use anyOf
//
// The category lists must stay in step with packages/core's taxonomy.dart, and
// the currencies with its currencies.dart; a test reads those files and fails
// if they drift.

const categories = [
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

const paymentMethods = ['cash', 'card', 'ewallet', 'bank_transfer', 'unknown'];

// The same list the picker offers, so the Model cannot return a code the app
// would then have to refuse.
const currencies = [
  'AED', 'AFN', 'ALL', 'AMD', 'AOA', 'ARS', 'AUD', 'AWG', 'AZN',
  'BAM', 'BBD', 'BDT', 'BGN', 'BHD', 'BIF', 'BMD', 'BND', 'BOB',
  'BRL', 'BSD', 'BTN', 'BWP', 'BYN', 'BZD',
  'CAD', 'CDF', 'CHF', 'CLP', 'CNY', 'COP', 'CRC', 'CUP', 'CVE',
  'CZK',
  'DJF', 'DKK', 'DOP', 'DZD',
  'EGP', 'ERN', 'ETB', 'EUR',
  'FJD', 'FKP',
  'GBP', 'GEL', 'GHS', 'GIP', 'GMD', 'GNF', 'GTQ', 'GYD',
  'HKD', 'HNL', 'HTG', 'HUF',
  'IDR', 'ILS', 'INR', 'IQD', 'IRR', 'ISK',
  'JMD', 'JOD', 'JPY',
  'KES', 'KGS', 'KHR', 'KMF', 'KPW', 'KRW', 'KWD', 'KYD', 'KZT',
  'LAK', 'LBP', 'LKR', 'LRD', 'LSL', 'LYD',
  'MAD', 'MDL', 'MGA', 'MKD', 'MMK', 'MNT', 'MOP', 'MRU', 'MUR',
  'MVR', 'MWK', 'MXN', 'MYR', 'MZN',
  'NAD', 'NGN', 'NIO', 'NOK', 'NPR', 'NZD',
  'OMR',
  'PAB', 'PEN', 'PGK', 'PHP', 'PKR', 'PLN', 'PYG',
  'QAR',
  'RON', 'RSD', 'RUB', 'RWF',
  'SAR', 'SBD', 'SCR', 'SDG', 'SEK', 'SGD', 'SHP', 'SLE', 'SOS',
  'SRD', 'SSP', 'STN', 'SVC', 'SYP', 'SZL',
  'THB', 'TJS', 'TMT', 'TND', 'TOP', 'TRY', 'TTD', 'TWD', 'TZS',
  'UAH', 'UGX', 'USD', 'UYU', 'UZS',
  'VED', 'VES', 'VND', 'VUV',
  'WST',
  'XAF', 'XCD', 'XCG', 'XOF', 'XPF',
  'YER',
  'ZAR', 'ZMW', 'ZWG',
];

const nullableNumber = (description: string) => ({
  type: ['number', 'null'],
  description,
});

const lineItemSchema = {
  type: 'object',
  additionalProperties: false,
  properties: {
    description: {
      type: 'string',
      description: 'Item name as printed on the receipt, verbatim.',
    },
    quantity: nullableNumber('Units bought, or null if the row does not say.'),
    unit_price: nullableNumber(
      'Price per unit, or null if the row does not say.',
    ),
    amount: {
      type: 'number',
      description: 'Line total actually charged, after any line discount.',
    },
    category: {
      type: 'string',
      enum: categories,
      description: 'Category for this single item.',
    },
  },
  required: ['description', 'quantity', 'unit_price', 'amount', 'category'],
};

export const receiptSchema = {
  type: 'object',
  additionalProperties: false,
  properties: {
    is_receipt: {
      type: 'boolean',
      description:
        'False if the image is not a purchase receipt or invoice at all.',
    },
    merchant: {
      type: 'string',
      description:
        'Trading name of the seller. Empty string if not legible. Do not guess ' +
        'from the products sold.',
    },
    // The date format keyword is not load-bearing: the app parses a plain ISO
    // string, so if strict mode ever rejects it this drops to a nullable string
    // and nothing else changes.
    purchased_at: {
      type: ['string', 'null'],
      format: 'date',
      description:
        'The date the money was spent, as yyyy-MM-dd, or null if not legible.',
    },
    currency: {
      type: 'string',
      enum: [...currencies, ''],
      description:
        'ISO 4217 code of the money charged. Infer from the printed symbol ' +
        'and locale cues. Return the empty string rather than choosing ' +
        'between candidates when a symbol means more than one currency — a ' +
        'bare $ or ¥ is not enough on its own.',
    },
    subtotal: nullableNumber(
      'Total before tax and tip, or null if not printed.',
    ),
    tax: nullableNumber('Tax charged, or null if not printed.'),
    tip: nullableNumber('Tip or service charge, or null if not printed.'),
    total: {
      type: 'number',
      description:
        'The grand total charged. This is the single most important field.',
    },
    payment_method: {
      type: 'string',
      enum: paymentMethods,
      description:
        'How it was paid for, or unknown if the receipt does not say.',
    },
    category: {
      type: 'string',
      enum: categories,
      description:
        'One category for the receipt as a whole, chosen by where most of the ' +
        'money went.',
    },
    category_reason: {
      type: 'string',
      description: 'One short sentence explaining the category choice.',
    },
    line_items: {
      type: 'array',
      items: lineItemSchema,
      description: 'One entry per priced row, in the order they are printed.',
    },
    needs_review: {
      type: 'boolean',
      description:
        'True if a human should check this before it is trusted — blur, glare, ' +
        'a cut-off total, a handwritten amount, or figures that do not add up.',
    },
    review_reasons: {
      type: 'array',
      items: { type: 'string' },
      description: 'Empty array when needs_review is false.',
    },
  },
  required: [
    'is_receipt',
    'merchant',
    'purchased_at',
    'currency',
    'subtotal',
    'tax',
    'tip',
    'total',
    'payment_method',
    'category',
    'category_reason',
    'line_items',
    'needs_review',
    'review_reasons',
  ],
};

export const extractionInstructions =
  'You read photographs of retail receipts and return their contents as data.\n' +
  '\n' +
  'Rules:\n' +
  '- Transcribe what is printed. Never infer a figure that is not legible, and\n' +
  '  never compute a missing one — return null instead.\n' +
  '- The grand total is the amount actually charged, after discounts and\n' +
  '  including tax. If the receipt shows both a pre-tax and a post-tax total,\n' +
  '  the post-tax one is the total.\n' +
  '- Amounts are plain numbers: no currency symbols, no thousands separators.\n' +
  '- A date is only purchased_at if it is the date the money was spent. Ignore\n' +
  '  print timestamps, best-before dates, and card expiry dates.\n' +
  '- Categorise by where the money went, not by the shop name. A supermarket\n' +
  '  receipt that is mostly nappies and shampoo is personal_care, not groceries.\n' +
  '- Set needs_review whenever you are working around damage: glare, a fold\n' +
  '  through the total, a torn edge, handwriting, or figures that do not sum.\n';

export const extractionUserText =
  'Extract this receipt. If the image is not a receipt, set is_receipt to ' +
  'false and leave the other fields empty or zero.';
