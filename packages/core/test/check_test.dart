import 'package:test/test.dart';
import 'package:where_money_core/where_money_core.dart';

/// Every date-sensitive assertion is made against a fixed instant rather than
/// clock, so a test that passes today still passes next year.
final now = fixtureNow;

Extraction clean({
  String? purchasedAt,
  String? currency,
  double? subtotal,
  double? tax,
  bool noTax = false,
  double? tip,
  double? total,
  String? category,
  String? paymentMethod,
  List<LineItem>? lineItems,
}) => cleanExtraction.copyWith(
  purchasedAt: purchasedAt,
  clearPurchasedAt: purchasedAt == null,
  currency: currency,
  subtotal: subtotal,
  tax: tax,
  clearTax: noTax,
  tip: tip,
  total: total,
  category: category,
  paymentMethod: paymentMethod,
  lineItems: lineItems,
);

Finding? labelled(Check check, String label) {
  for (final finding in check.findings) {
    if (finding.label == label) return finding;
  }
  return null;
}

void main() {
  test('a clean receipt raises nothing at all', () {
    final check = Check.of(cleanExtraction, now: now);

    expect(check.findings, isEmpty);
    expect(check.isConsistent, isTrue);
  });

  test('the flawed receipt is caught on its line items and its unread date', () {
    final check = Check.of(flawedExtraction, now: now);

    expect(labelled(check, 'Line items do not match subtotal'), isNotNull);
    expect(labelled(check, 'No date'), isNotNull);
    expect(check.isConsistent, isFalse);
  });

  test('a subtotal, tax and tip that fall short of the total is a failure', () {
    final check = Check.of(
      clean(purchasedAt: '2026-08-21', subtotal: 20.00, tax: 1.20, total: 30.00),
      now: now,
    );

    final finding = labelled(check, 'Total does not add up');
    expect(finding, isNotNull);
    expect(finding!.severity, Severity.fail);
    expect(finding.detail, contains('8.80'));
  });

  test('a line whose quantity times unit price misses its amount is flagged', () {
    final check = Check.of(
      clean(
        purchasedAt: '2026-08-21',
        subtotal: 12.00,
        noTax: true,
        total: 12.00,
        lineItems: const [
          LineItem(
            description: 'Kaya toast',
            quantity: 3,
            unitPrice: 5.00,
            amount: 12.00,
            category: 'dining',
          ),
        ],
      ),
      now: now,
    );

    final finding = labelled(check, 'Line arithmetic off');
    expect(finding, isNotNull);
    expect(finding!.detail, contains('Kaya toast'));
  });

  test('a date in the future is a failure, not a warning', () {
    final check = Check.of(clean(purchasedAt: '2026-11-02'), now: now);

    final finding = labelled(check, 'Date in the future');
    expect(finding, isNotNull);
    expect(finding!.severity, Severity.fail);
  });

  test('a date a year old reads as a misread year and names the likely one', () {
    final check = Check.of(clean(purchasedAt: '2025-08-21'), now: now);

    final finding = labelled(check, 'Year looks misread');
    expect(finding, isNotNull);
    expect(finding!.detail, contains('2026'));
    expect(labelled(check, 'Date is unusually old'), isNull);
  });

  test('a misread year is caught across the turn of the year too', () {
    final january = DateTime(2027, 1, 12);
    final check = Check.of(clean(purchasedAt: '2025-12-28'), now: january);

    final finding = labelled(check, 'Year looks misread');
    expect(finding, isNotNull);
    expect(finding!.detail, contains('2027'));
  });

  test('a genuinely old date is old rather than a misread year', () {
    final check = Check.of(clean(purchasedAt: '2026-01-14'), now: now);

    expect(labelled(check, 'Date is unusually old'), isNotNull);
    expect(labelled(check, 'Year looks misread'), isNull);
  });

  test('a date the model could not read at all is a warning', () {
    final check = Check.of(clean(), now: now);

    expect(labelled(check, 'No date')!.severity, Severity.warn);
  });

  test('a category outside the taxonomy is caught', () {
    final check = Check.of(
      clean(purchasedAt: '2026-08-21', category: 'crypto'),
      now: now,
    );

    final finding = labelled(check, 'Unknown category');
    expect(finding, isNotNull);
    expect(finding!.severity, Severity.fail);
    expect(finding.detail, contains('crypto'));
  });

  test('a payment method outside the taxonomy is caught', () {
    final check = Check.of(
      clean(purchasedAt: '2026-08-21', paymentMethod: 'crypto'),
      now: now,
    );

    expect(labelled(check, 'Unknown payment method'), isNotNull);
  });

  test('a line item category outside the taxonomy is caught', () {
    final check = Check.of(
      clean(
        purchasedAt: '2026-08-21',
        subtotal: 5.00,
        noTax: true,
        total: 5.00,
        lineItems: const [
          LineItem(
            description: 'Mystery item',
            amount: 5.00,
            category: 'sundries',
          ),
        ],
      ),
      now: now,
    );

    expect(labelled(check, 'Unknown item category'), isNotNull);
  });

  test('an image the model says is not a receipt stops at that one finding', () {
    final check = Check.of(notAReceiptExtraction, now: now);

    expect(check.findings, hasLength(1));
    expect(check.findings.single.label, 'Not a receipt');
    expect(check.findings.single.severity, Severity.fail);
  });

  test('items exceeding the receipt fail where a shortfall only warns', () {
    final over = Check.of(
      clean(
        purchasedAt: '2026-08-21',
        subtotal: 5.00,
        noTax: true,
        total: 5.00,
        lineItems: const [
          LineItem(description: 'Coffee', amount: 9.00, category: 'dining'),
        ],
      ),
      now: now,
    );

    expect(
      labelled(over, 'Line items do not match subtotal')!.severity,
      Severity.fail,
    );
    expect(
      labelled(
        Check.of(flawedExtraction, now: now),
        'Line items do not match subtotal',
      )!.severity,
      Severity.warn,
    );
  });

  test('a total of zero leaves nothing usable', () {
    final check = Check.of(
      clean(purchasedAt: '2026-08-21', subtotal: 0, noTax: true, total: 0),
      now: now,
    );

    expect(labelled(check, 'No total')!.severity, Severity.fail);
  });

  test('a currency that is not an ISO code is flagged', () {
    final check = Check.of(
      clean(purchasedAt: '2026-08-21', currency: 'RM'),
      now: now,
    );

    expect(labelled(check, 'Currency unclear'), isNotNull);
  });
}
