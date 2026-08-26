import 'package:test/test.dart';
import 'package:where_money_core/where_money_core.dart';

void main() {
  test('a blank Extraction has nothing in it to review', () {
    final blank = Extraction.blank();

    expect(blank.merchant, isEmpty);
    expect(blank.purchasedAt, isNull);
    expect(blank.currency, isEmpty);
    expect(blank.total, 0);
    expect(blank.lineItems, isEmpty);
    expect(blank.needsReview, isFalse);
  });

  test('a blank Extraction is checked like a receipt, not discarded as one '
      'that is not', () {
    final findings = Check.of(Extraction.blank(), now: fixtureNow).findings;

    expect(
      findings.map((finding) => finding.label),
      isNot(contains('Not a receipt')),
    );
  });

  test('a blank Extraction raises a Finding for everything it is missing', () {
    final check = Check.of(Extraction.blank(), now: fixtureNow);
    final fields = check.findings.map((finding) => finding.field).toSet();

    expect(
      fields,
      containsAll(<ReviewField>[
        ReviewField.total,
        ReviewField.merchant,
        ReviewField.purchasedAt,
        ReviewField.currency,
      ]),
    );
  });
}
