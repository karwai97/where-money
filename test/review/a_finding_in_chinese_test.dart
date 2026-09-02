import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/l10n/app_localizations_en.dart';
import 'package:where_money/l10n/app_localizations_zh.dart';
import 'package:where_money/review/finding_copy.dart';
import 'package:where_money_core/where_money_core.dart';

/// The other half of [what_a_finding_says_test.dart]: the same Findings read in
/// Chinese. What that file pins is that the English did not change in the move;
/// what this one pins is that the move happened at all, and that a value the
/// Check found still lands inside the sentence rather than beside it.
void main() {
  final english = AppLocalizationsEn();
  final chinese = AppLocalizationsZh();

  /// Every sentence the Check can put on the Review screen. Seventeen kinds,
  /// but twenty-one sentences: line items can fall short of a subtotal or a
  /// total and can exceed either, and the Model can flag an image with reasons
  /// or without. Each of those is a whole message rather than a sentence with a
  /// fragment dropped into it.
  const everySaying = <Finding>[
    NotAReceipt(),
    NoTotal(),
    NoMerchant(),
    NoDate(),
    UnparseableDate('21 Aug'),
    DateInTheFuture('2027-01-04'),
    YearLooksMisread(read: '2025-08-21', likelyYear: 2026),
    DateIsUnusuallyOld(read: '2026-01-14', daysAgo: 219),
    NoCurrency(),
    CurrencyNotAnIsoCode('RM'),
    TotalDoesNotAddUp(
      subtotal: 20.00,
      tax: 1.20,
      tip: 0,
      composed: 21.20,
      total: 30.00,
    ),
    LineItemsDoNotMatch(
      sum: 46.00,
      target: 50.00,
      againstSubtotal: true,
      over: false,
    ),
    LineItemsDoNotMatch(
      sum: 54.00,
      target: 50.00,
      againstSubtotal: true,
      over: true,
    ),
    LineItemsDoNotMatch(
      sum: 4.00,
      target: 5.00,
      againstSubtotal: false,
      over: false,
    ),
    LineItemsDoNotMatch(
      sum: 9.00,
      target: 5.00,
      againstSubtotal: false,
      over: true,
    ),
    LineArithmeticOff(
      description: 'Kaya toast',
      quantity: 3,
      unitPrice: 5.00,
      expected: 15.00,
      amount: 12.00,
    ),
    UnknownItemCategory(description: 'Mystery item', read: 'sundries'),
    UnknownCategory('crypto'),
    UnknownPaymentMethod('crypto'),
    ModelAskedForReview(['blurry', 'creased']),
    ModelAskedForReview([]),
  ];

  test('every Finding says something in Chinese', () {
    for (final finding in everySaying) {
      final (title, detail) = sayingFor(chinese, finding);

      expect(title, isNotEmpty, reason: '$finding has no Chinese title');
      expect(detail, isNotEmpty, reason: '$finding has no Chinese detail');
    }
  });

  test('no Finding was left in English', () {
    for (final finding in everySaying) {
      final (englishTitle, englishDetail) = sayingFor(english, finding);
      final (chineseTitle, chineseDetail) = sayingFor(chinese, finding);

      expect(
        chineseTitle,
        isNot(englishTitle),
        reason: '$finding still shows its English title in Chinese',
      );
      expect(
        chineseDetail,
        isNot(englishDetail),
        reason: '$finding still shows its English sentence in Chinese',
      );
    }
  });

  test('the twenty-one sentences are twenty-one distinct sentences', () {
    // A key copied and not edited is the way one Finding ends up explaining
    // another, and it reads as plausible prose about the wrong thing.
    final details = everySaying
        .map((finding) => sayingFor(chinese, finding).$2)
        .toList();

    expect(details.toSet(), hasLength(details.length));
  });

  test('a date read off a receipt is quoted the way Chinese quotes', () {
    final (_, detail) = sayingFor(chinese, const UnparseableDate('21 Aug'));

    expect(detail, '读到「21 Aug」，不是 ISO 格式的日期。');
  });

  test('the likely year is a year, not a counted quantity', () {
    final (_, detail) = sayingFor(
      chinese,
      const YearLooksMisread(read: '2025-08-21', likelyYear: 2026),
    );

    // 2,026 would be what a locale-aware number does to a year.
    expect(detail, contains('2026'));
    expect(detail, isNot(contains('2,026')));
  });

  test('an amount keeps two decimal places and no locale', () {
    final (_, detail) = sayingFor(
      chinese,
      const TotalDoesNotAddUp(
        subtotal: 20.00,
        tax: 1.20,
        tip: 0,
        composed: 21.20,
        total: 30.00,
      ),
    );

    expect(detail, '小计 20.00 + 税 1.20 + 小费 0.00 = 21.20，但总额写的是 30.00（差 8.80）。');
  });

  test('a line as printed on the receipt is not translated', () {
    final (_, detail) = sayingFor(
      chinese,
      const LineArithmeticOff(
        description: 'Kaya toast',
        quantity: 3,
        unitPrice: 5.00,
        expected: 15.00,
        amount: 12.00,
      ),
    );

    expect(detail, contains('Kaya toast'));
  });

  test('the Model’s own reasons are passed on, separated the Chinese way', () {
    final (_, detail) = sayingFor(
      chinese,
      const ModelAskedForReview(['blurry', 'creased']),
    );

    expect(detail, 'blurry；creased');
  });
}
