/// The currency codes of ISO 4217, and the few symbols receipts print instead.
///
/// Closed for a different reason from the Category taxonomy. ADR-0005 closes
/// that one because it is sent to the Model as an enum and this project
/// decided its membership. Nobody decided ISO 4217's — it is a fact about the
/// world — so it earns no ADR and no glossary entry, and no copy either: a
/// code is already the word in every language, which is why these are outside
/// the invariant that every slug in a closed set has words in both languages.
library;

/// Table A.1, the codes money is actually denominated in. The funds codes,
/// the precious metals and the reserved codes are all left out: none of them
/// is something a receipt is printed in, and a picker that offers to record
/// lunch in gold is worse than one that does not.
///
/// Alphabetical, which is also the order the picker shows the tail of the list
/// in.
const List<String> isoCurrencies = [
  'AED', 'AFN', 'ALL', 'AMD', 'AOA', 'ARS', 'AUD', 'AWG', 'AZN', //
  'BAM', 'BBD', 'BDT', 'BGN', 'BHD', 'BIF', 'BMD', 'BND', 'BOB', 'BRL',
  'BSD', 'BTN', 'BWP', 'BYN', 'BZD',
  'CAD', 'CDF', 'CHF', 'CLP', 'CNY', 'COP', 'CRC', 'CUP', 'CVE', 'CZK',
  'DJF', 'DKK', 'DOP', 'DZD',
  'EGP', 'ERN', 'ETB', 'EUR',
  'FJD', 'FKP',
  'GBP', 'GEL', 'GHS', 'GIP', 'GMD', 'GNF', 'GTQ', 'GYD',
  'HKD', 'HNL', 'HTG', 'HUF',
  'IDR', 'ILS', 'INR', 'IQD', 'IRR', 'ISK',
  'JMD', 'JOD', 'JPY',
  'KES', 'KGS', 'KHR', 'KMF', 'KPW', 'KRW', 'KWD', 'KYD', 'KZT',
  'LAK', 'LBP', 'LKR', 'LRD', 'LSL', 'LYD',
  'MAD', 'MDL', 'MGA', 'MKD', 'MMK', 'MNT', 'MOP', 'MRU', 'MUR', 'MVR',
  'MWK', 'MXN', 'MYR', 'MZN',
  'NAD', 'NGN', 'NIO', 'NOK', 'NPR', 'NZD',
  'OMR',
  'PAB', 'PEN', 'PGK', 'PHP', 'PKR', 'PLN', 'PYG',
  'QAR',
  'RON', 'RSD', 'RUB', 'RWF',
  'SAR', 'SBD', 'SCR', 'SDG', 'SEK', 'SGD', 'SHP', 'SLE', 'SOS', 'SRD',
  'SSP', 'STN', 'SVC', 'SYP', 'SZL',
  'THB', 'TJS', 'TMT', 'TND', 'TOP', 'TRY', 'TTD', 'TWD', 'TZS',
  'UAH', 'UGX', 'USD', 'UYU', 'UZS',
  'VED', 'VES', 'VND', 'VUV',
  'WST',
  'XAF', 'XCD', 'XCG', 'XOF', 'XPF',
  'YER',
  'ZAR', 'ZMW', 'ZWG',
];

/// What a receipt prints where a code belongs, for the ones that mean exactly
/// one currency. `$` and `¥` are deliberately absent: `$` is eight currencies
/// and `¥` is two, and guessing between them puts a number in the wrong month
/// without saying so.
///
/// Applied where Review seeds its form, never where an Extraction is parsed —
/// an Extraction is what the Model claims it read, and the Corrected Field
/// tally is built on that claim staying intact.
const Map<String, String> currencyAliases = {
  'RM': 'MYR',
  r'S$': 'SGD',
  r'HK$': 'HKD',
  r'NT$': 'TWD',
  '£': 'GBP',
  '€': 'EUR',
};

/// What [read] means as a code, or null when the app cannot say. Trims and
/// upper-cases first, so `myr` and a stray space are the code they obviously
/// are, then tries the aliases for what receipts print instead.
String? currencyFrom(String read) {
  final trimmed = read.trim();
  if (trimmed.isEmpty) return null;

  final upper = trimmed.toUpperCase();
  if (isoCurrencies.contains(upper)) return upper;

  return currencyAliases[trimmed] ?? currencyAliases[upper];
}
