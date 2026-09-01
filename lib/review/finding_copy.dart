import 'package:where_money_core/where_money_core.dart';

/// What a Finding says on screen: a short subject and the sentence under it.
/// The Check reports kinds carrying values and no words at all, so this switch
/// is the only place the words exist. It is exhaustive on purpose — a kind
/// added without copy is a compile error rather than a blank line on somebody's
/// receipt.
(String, String) sayingFor(Finding finding) => switch (finding) {
  NotAReceipt() => (
    'Not a receipt',
    'The model says this image is not a receipt.',
  ),
  NoTotal() => (
    'No total',
    'Total is zero or negative — nothing usable was read.',
  ),
  NoMerchant() => (
    'No merchant',
    'Merchant name was not legible. The expense is unattributable.',
  ),
  NoDate() => (
    'No date',
    'The date on the receipt was not legible — it will default to today.',
  ),
  UnparseableDate(:final read) => (
    'Unparseable date',
    'Got "$read", which is not an ISO date.',
  ),
  DateInTheFuture(:final read) => (
    'Date in the future',
    'Read $read, which has not happened yet — probably a card expiry or a '
        'best-before date rather than the purchase.',
  ),
  YearLooksMisread(:final read, :final likelyYear) => (
    'Year looks misread',
    'Read $read, almost exactly a year ago. On a freshly photographed receipt '
        'that usually means the year was misread — $likelyYear is the likely '
        'value.',
  ),
  DateIsUnusuallyOld(:final read, :final daysAgo) => (
    'Date is unusually old',
    'Read $read, $daysAgo days ago. Fine for an old receipt, but worth '
        'checking if this was just photographed.',
  ),
  NoCurrency() => (
    'Currency unclear',
    'No currency identified, so the amount has no unit.',
  ),
  CurrencyNotAnIsoCode(:final read) => (
    'Currency unclear',
    'Got "$read", which is not an ISO 4217 code.',
  ),
  TotalDoesNotAddUp() => (
    'Total does not add up',
    'subtotal ${_money(finding.subtotal)} + tax ${_money(finding.tax)} + tip '
        '${_money(finding.tip)} = ${_money(finding.composed)}, but total reads '
        '${_money(finding.total)} (off by ${_money(finding.difference)}).',
  ),
  LineItemsDoNotMatch(:final sum, :final target, :final over) => (
    'Line items do not match ${_targetName(finding)}',
    'Items sum to ${_money(sum)} against a ${_targetName(finding)} of '
        '${_money(target)}'
        '${over ? ' — items exceed the receipt, so something was double-read.' : ' — an item may have been missed, or a discount was not itemised.'}',
  ),
  LineArithmeticOff(:final description, :final quantity, :final unitPrice) => (
    'Line arithmetic off',
    '"$description": ${_money(quantity)} x ${_money(unitPrice)} = '
        '${_money(finding.expected)}, but the line reads '
        '${_money(finding.amount)}.',
  ),
  UnknownItemCategory(:final description, :final read) => (
    'Unknown item category',
    '"$description" came back as "$read", which is not in the taxonomy.',
  ),
  UnknownCategory(:final read) => (
    'Unknown category',
    'Got "$read", which is outside the enum the schema declared.',
  ),
  UnknownPaymentMethod(:final read) => (
    'Unknown payment method',
    'Got "$read".',
  ),
  ModelAskedForReview(:final reasons) => (
    'Model asked for review',
    reasons.isEmpty
        ? 'It flagged the image but gave no reason.'
        : reasons.join('; '),
  ),
};

String _targetName(LineItemsDoNotMatch finding) =>
    finding.againstSubtotal ? 'subtotal' : 'total';

String _money(double value) => value.toStringAsFixed(2);
