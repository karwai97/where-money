import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/review/finding_copy.dart';
import 'package:where_money_core/where_money_core.dart';

/// Every kind of Finding, with the words it puts on the Review screen. The
/// switch in [sayingFor] is exhaustive, so a kind added to the Check without
/// copy does not compile; this pins what the copy actually says, including
/// where the numbers land in the sentence.
void main() {
  ({String label, String detail}) said(Finding finding) {
    final (label, detail) = sayingFor(finding);
    return (label: label, detail: detail);
  }

  test('an image that is not a receipt', () {
    expect(said(const NotAReceipt()), (
      label: 'Not a receipt',
      detail: 'The model says this image is not a receipt.',
    ));
  });

  test('no total', () {
    expect(said(const NoTotal()), (
      label: 'No total',
      detail: 'Total is zero or negative — nothing usable was read.',
    ));
  });

  test('no merchant', () {
    expect(said(const NoMerchant()), (
      label: 'No merchant',
      detail: 'Merchant name was not legible. The expense is unattributable.',
    ));
  });

  test('no date', () {
    expect(said(const NoDate()), (
      label: 'No date',
      detail:
          'The date on the receipt was not legible — it will default to today.',
    ));
  });

  test('a date that is not an ISO date', () {
    expect(said(const UnparseableDate('21 Aug')), (
      label: 'Unparseable date',
      detail: 'Got "21 Aug", which is not an ISO date.',
    ));
  });

  test('a date in the future', () {
    expect(said(const DateInTheFuture('2027-01-04')), (
      label: 'Date in the future',
      detail:
          'Read 2027-01-04, which has not happened yet — probably a card '
          'expiry or a best-before date rather than the purchase.',
    ));
  });

  test('a year that looks misread names the likely one', () {
    expect(said(const YearLooksMisread(read: '2025-08-21', likelyYear: 2026)), (
      label: 'Year looks misread',
      detail:
          'Read 2025-08-21, almost exactly a year ago. On a freshly '
          'photographed receipt that usually means the year was misread — '
          '2026 is the likely value.',
    ));
  });

  test('a date that is merely old counts the days', () {
    expect(said(const DateIsUnusuallyOld(read: '2026-01-14', daysAgo: 219)), (
      label: 'Date is unusually old',
      detail:
          'Read 2026-01-14, 219 days ago. Fine for an old receipt, but worth '
          'checking if this was just photographed.',
    ));
  });

  test('nothing read where a currency belonged', () {
    expect(said(const NoCurrency()), (
      label: 'Currency unclear',
      detail: 'No currency identified, so the amount has no unit.',
    ));
  });

  test('a currency that is not an ISO code', () {
    expect(said(const CurrencyNotAnIsoCode('RM')), (
      label: 'Currency unclear',
      detail: 'Got "RM", which is not an ISO 4217 code.',
    ));
  });

  test('a total that does not add up shows every part of the arithmetic', () {
    expect(
      said(
        const TotalDoesNotAddUp(
          subtotal: 20.00,
          tax: 1.20,
          tip: 0,
          composed: 21.20,
          total: 30.00,
        ),
      ),
      (
        label: 'Total does not add up',
        detail:
            'subtotal 20.00 + tax 1.20 + tip 0.00 = 21.20, but total reads '
            '30.00 (off by 8.80).',
      ),
    );
  });

  test('line items that fall short of the subtotal', () {
    expect(
      said(
        const LineItemsDoNotMatch(
          sum: 46.00,
          target: 50.00,
          againstSubtotal: true,
          over: false,
        ),
      ),
      (
        label: 'Line items do not match subtotal',
        detail:
            'Items sum to 46.00 against a subtotal of 50.00 — an item may '
            'have been missed, or a discount was not itemised.',
      ),
    );
  });

  test('line items that exceed the total', () {
    expect(
      said(
        const LineItemsDoNotMatch(
          sum: 9.00,
          target: 5.00,
          againstSubtotal: false,
          over: true,
        ),
      ),
      (
        label: 'Line items do not match total',
        detail:
            'Items sum to 9.00 against a total of 5.00 — items exceed the '
            'receipt, so something was double-read.',
      ),
    );
  });

  test('a line whose arithmetic is off', () {
    expect(
      said(
        const LineArithmeticOff(
          description: 'Kaya toast',
          quantity: 3,
          unitPrice: 5.00,
          expected: 15.00,
          amount: 12.00,
        ),
      ),
      (
        label: 'Line arithmetic off',
        detail: '"Kaya toast": 3.00 x 5.00 = 15.00, but the line reads 12.00.',
      ),
    );
  });

  test('a line item category outside the taxonomy', () {
    expect(
      said(
        const UnknownItemCategory(
          description: 'Mystery item',
          read: 'sundries',
        ),
      ),
      (
        label: 'Unknown item category',
        detail:
            '"Mystery item" came back as "sundries", which is not in the '
            'taxonomy.',
      ),
    );
  });

  test('a category outside the taxonomy', () {
    expect(said(const UnknownCategory('crypto')), (
      label: 'Unknown category',
      detail: 'Got "crypto", which is outside the enum the schema declared.',
    ));
  });

  test('a payment method outside the taxonomy', () {
    expect(said(const UnknownPaymentMethod('crypto')), (
      label: 'Unknown payment method',
      detail: 'Got "crypto".',
    ));
  });

  test('the Model asking for review passes on its reasons', () {
    expect(said(const ModelAskedForReview(['blurry', 'creased'])), (
      label: 'Model asked for review',
      detail: 'blurry; creased',
    ));
  });

  test('the Model asking for review with no reason still says something', () {
    expect(said(const ModelAskedForReview([])), (
      label: 'Model asked for review',
      detail: 'It flagged the image but gave no reason.',
    ));
  });
}
