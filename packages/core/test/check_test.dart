import 'package:test/test.dart';
import 'package:where_money_core/where_money_core.dart';

/// Every date-sensitive assertion is made against a fixed instant rather than
/// clock, so a test that passes today still passes next year.
final now = fixtureNow;

Extraction clean({
  String? purchasedAt,
  String? currency,
  double? subtotal,
  bool noSubtotal = false,
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
  clearSubtotal: noSubtotal,
  tax: tax,
  clearTax: noTax,
  tip: tip,
  total: total,
  category: category,
  paymentMethod: paymentMethod,
  lineItems: lineItems,
);

/// The one Finding of a given kind, or null. The Check reports kinds, so a kind
/// is what a test looks for — the words belong to the app.
T? kind<T extends Finding>(Check check) {
  for (final finding in check.findings) {
    if (finding is T) return finding;
  }
  return null;
}

void main() {
  test('a clean receipt raises nothing at all', () {
    final check = Check.of(cleanExtraction, now: now);

    expect(check.findings, isEmpty);
    expect(check.isConsistent, isTrue);
  });

  test(
    'the flawed receipt is caught on its line items and its unread date',
    () {
      final check = Check.of(flawedExtraction, now: now);

      expect(kind<LineItemsDoNotMatch>(check)?.againstSubtotal, isTrue);
      expect(kind<NoDate>(check), isNotNull);
      expect(check.isConsistent, isFalse);
    },
  );

  test('a subtotal, tax and tip that fall short of the total is a failure', () {
    final check = Check.of(
      clean(
        purchasedAt: '2026-08-21',
        subtotal: 20.00,
        tax: 1.20,
        total: 30.00,
      ),
      now: now,
    );

    final finding = kind<TotalDoesNotAddUp>(check);
    expect(finding, isNotNull);
    expect(finding!.severity, Severity.fail);
    expect(finding.composed, closeTo(21.20, 0.001));
    expect(finding.total, 30.00);
    expect(finding.difference, closeTo(8.80, 0.001));
  });

  test(
    'a line whose quantity times unit price misses its amount is flagged',
    () {
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

      final finding = kind<LineArithmeticOff>(check);
      expect(finding, isNotNull);
      expect(finding!.description, 'Kaya toast');
      expect(finding.expected, closeTo(15.00, 0.001));
      expect(finding.amount, 12.00);
    },
  );

  test('a date in the future is a failure, not a warning', () {
    final check = Check.of(clean(purchasedAt: '2026-11-02'), now: now);

    final finding = kind<DateInTheFuture>(check);
    expect(finding, isNotNull);
    expect(finding!.severity, Severity.fail);
    expect(finding.read, '2026-11-02');
  });

  test(
    'a date a year old reads as a misread year and names the likely one',
    () {
      final check = Check.of(clean(purchasedAt: '2025-08-21'), now: now);

      final finding = kind<YearLooksMisread>(check);
      expect(finding, isNotNull);
      expect(finding!.likelyYear, 2026);
      expect(kind<DateIsUnusuallyOld>(check), isNull);
    },
  );

  test('a misread year is caught across the turn of the year too', () {
    final january = DateTime(2027, 1, 12);
    final check = Check.of(clean(purchasedAt: '2025-12-28'), now: january);

    expect(kind<YearLooksMisread>(check)?.likelyYear, 2027);
  });

  test('a genuinely old date is old rather than a misread year', () {
    final check = Check.of(clean(purchasedAt: '2026-01-14'), now: now);

    final finding = kind<DateIsUnusuallyOld>(check);
    expect(finding, isNotNull);
    expect(finding!.read, '2026-01-14');
    expect(finding.daysAgo, now.difference(DateTime(2026, 1, 14)).inDays);
    expect(kind<YearLooksMisread>(check), isNull);
  });

  test('a date the model could not read at all is a warning', () {
    final check = Check.of(clean(), now: now);

    expect(kind<NoDate>(check)!.severity, Severity.warn);
  });

  test('a date that is not an ISO date at all keeps what it read', () {
    final check = Check.of(clean(purchasedAt: '21 Aug'), now: now);

    expect(kind<UnparseableDate>(check)?.read, '21 Aug');
  });

  test('a category outside the taxonomy is caught', () {
    final check = Check.of(
      clean(purchasedAt: '2026-08-21', category: 'crypto'),
      now: now,
    );

    final finding = kind<UnknownCategory>(check);
    expect(finding, isNotNull);
    expect(finding!.severity, Severity.fail);
    expect(finding.read, 'crypto');
  });

  test('a payment method outside the taxonomy is caught', () {
    final check = Check.of(
      clean(purchasedAt: '2026-08-21', paymentMethod: 'crypto'),
      now: now,
    );

    expect(kind<UnknownPaymentMethod>(check)?.read, 'crypto');
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

    final finding = kind<UnknownItemCategory>(check);
    expect(finding, isNotNull);
    expect(finding!.description, 'Mystery item');
    expect(finding.read, 'sundries');
  });

  test(
    'an image the model says is not a receipt stops at that one finding',
    () {
      final check = Check.of(notAReceiptExtraction, now: now);

      expect(check.findings, hasLength(1));
      expect(check.findings.single, isA<NotAReceipt>());
      expect(check.findings.single.severity, Severity.fail);
    },
  );

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

    final overshoot = kind<LineItemsDoNotMatch>(over);
    expect(overshoot!.over, isTrue);
    expect(overshoot.severity, Severity.fail);
    expect(overshoot.sum, closeTo(9.00, 0.001));
    expect(overshoot.target, closeTo(5.00, 0.001));

    final shortfall = kind<LineItemsDoNotMatch>(
      Check.of(flawedExtraction, now: now),
    );
    expect(shortfall!.over, isFalse);
    expect(shortfall.severity, Severity.warn);
  });

  test('line items are compared with the total when there is no subtotal', () {
    final check = Check.of(
      clean(
        purchasedAt: '2026-08-21',
        noSubtotal: true,
        noTax: true,
        lineItems: const [
          LineItem(description: 'Coffee', amount: 1.00, category: 'dining'),
        ],
      ),
      now: now,
    );

    final finding = kind<LineItemsDoNotMatch>(check);
    expect(finding!.againstSubtotal, isFalse);
    expect(finding.target, cleanExtraction.total);
  });

  test('a total of zero leaves nothing usable', () {
    final check = Check.of(
      clean(purchasedAt: '2026-08-21', subtotal: 0, noTax: true, total: 0),
      now: now,
    );

    expect(kind<NoTotal>(check)!.severity, Severity.fail);
  });

  test('a currency that is not an ISO code is flagged', () {
    final check = Check.of(
      clean(purchasedAt: '2026-08-21', currency: 'RM'),
      now: now,
    );

    expect(kind<CurrencyNotAnIsoCode>(check)?.read, 'RM');
    expect(kind<NoCurrency>(check), isNull);
  });

  test('nothing read at all is a different Finding from a bad code', () {
    final check = Check.of(
      clean(purchasedAt: '2026-08-21', currency: '  '),
      now: now,
    );

    expect(kind<NoCurrency>(check), isNotNull);
    expect(kind<CurrencyNotAnIsoCode>(check), isNull);
  });

  test(
    'a Finding names the field it is about, so a correction can settle it',
    () {
      final check = Check.of(
        clean(
          purchasedAt: '2026-08-21',
          subtotal: 20.00,
          tax: 1.20,
          total: 30.00,
        ),
        now: now,
      );

      expect(kind<TotalDoesNotAddUp>(check)!.field, ReviewField.total);
    },
  );

  test('a line-item Finding is about the line items rather than the total', () {
    final check = Check.of(
      clean(
        purchasedAt: '2026-08-21',
        lineItems: [
          const LineItem(
            description: 'Farm Fresh Milk 1L',
            amount: 41.60,
            category: 'groceries',
          ),
          const LineItem(
            description: 'Wholemeal Bread',
            amount: 4.40,
            category: 'groceries',
          ),
        ],
      ),
      now: now,
    );

    expect(kind<LineItemsDoNotMatch>(check)!.field, ReviewField.lineItems);
  });

  group('an Extraction that has been through Review before', () {
    Extraction dated(String day) => cleanExtraction.copyWith(purchasedAt: day);

    test('is not asked about a date it was already confirmed on', () {
      final check = Check.of(
        dated('2026-03-02'),
        now: fixtureNow,
        alreadyReviewed: true,
      );

      expect(check.findings, isEmpty);
    });

    test('is asked about it on the way in, where the heuristic belongs', () {
      final check = Check.of(dated('2026-03-02'), now: fixtureNow);

      expect(kind<DateIsUnusuallyOld>(check), isNotNull);
    });

    test('is still asked about a date that has not happened yet', () {
      final check = Check.of(
        dated('2027-01-04'),
        now: fixtureNow,
        alreadyReviewed: true,
      );

      expect(kind<DateInTheFuture>(check), isNotNull);
    });

    test('is still asked about arithmetic that stopped adding up', () {
      final check = Check.of(
        dated('2026-03-02').copyWith(total: 99.00),
        now: fixtureNow,
        alreadyReviewed: true,
      );

      expect(kind<TotalDoesNotAddUp>(check), isNotNull);
    });
  });
}
