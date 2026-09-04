/// The Check: the on-device arithmetic and plausibility pass over an
/// Extraction. Structured outputs guarantee the JSON parses; they guarantee
/// nothing about whether the numbers are right. This is the cheap local
/// defence — it re-does the arithmetic printed on the receipt and reports
/// where the Extraction contradicts itself. It costs nothing and calls nothing.
library;

import 'currencies.dart';
import 'extraction.dart';
import 'review_field.dart';
import 'taxonomy.dart';

enum Severity { warn, fail }

/// One thing a Check noticed. A Finding says what it found and carries the
/// values it found it in; it does not say it in any language. The words live
/// with the screen that shows them, so a kind added here without copy over
/// there stops compiling.
sealed class Finding {
  const Finding();

  Severity get severity;

  /// The field a correction would have to reach to answer this. Null when the
  /// Finding is about the Extraction as a whole and no single correction
  /// settles it.
  ReviewField? get field;
}

sealed class _Warning extends Finding {
  const _Warning();

  @override
  Severity get severity => Severity.warn;
}

sealed class _Failure extends Finding {
  const _Failure();

  @override
  Severity get severity => Severity.fail;
}

final class NotAReceipt extends _Failure {
  const NotAReceipt();

  @override
  ReviewField? get field => null;
}

final class NoTotal extends _Failure {
  const NoTotal();

  @override
  ReviewField? get field => ReviewField.total;
}

final class NoMerchant extends _Warning {
  const NoMerchant();

  @override
  ReviewField? get field => ReviewField.merchant;
}

final class NoDate extends _Warning {
  const NoDate();

  @override
  ReviewField? get field => ReviewField.purchasedAt;
}

final class UnparseableDate extends _Warning {
  const UnparseableDate(this.read);

  /// What arrived where an ISO date belonged.
  final String read;

  @override
  ReviewField? get field => ReviewField.purchasedAt;
}

final class DateInTheFuture extends _Failure {
  const DateInTheFuture(this.read);

  final String read;

  @override
  ReviewField? get field => ReviewField.purchasedAt;
}

/// Almost exactly a year ago, on a receipt that has just been photographed.
/// [likelyYear] is the year it probably should have read.
final class YearLooksMisread extends _Warning {
  const YearLooksMisread({required this.read, required this.likelyYear});

  final String read;
  final int likelyYear;

  @override
  ReviewField? get field => ReviewField.purchasedAt;
}

/// Old enough to be worth a second look, but not a year out.
final class DateIsUnusuallyOld extends _Warning {
  const DateIsUnusuallyOld({required this.read, required this.daysAgo});

  final String read;
  final int daysAgo;

  @override
  ReviewField? get field => ReviewField.purchasedAt;
}

final class NoCurrency extends _Warning {
  const NoCurrency();

  @override
  ReviewField? get field => ReviewField.currency;
}

final class CurrencyNotAnIsoCode extends _Warning {
  const CurrencyNotAnIsoCode(this.read);

  final String read;

  @override
  ReviewField? get field => ReviewField.currency;
}

final class TotalDoesNotAddUp extends _Failure {
  const TotalDoesNotAddUp({
    required this.subtotal,
    required this.tax,
    required this.tip,
    required this.composed,
    required this.total,
  });

  final double subtotal;
  final double tax;
  final double tip;

  /// What the parts add to.
  final double composed;

  /// What the receipt says the total is.
  final double total;

  double get difference => (composed - total).abs();

  @override
  ReviewField? get field => ReviewField.total;
}

/// The line items do not add to what they should. [againstSubtotal] says which
/// figure they were compared with; [over] says which way they missed.
/// Discounts and unlisted deposits legitimately produce a shortfall, so that
/// only warns, while items exceeding the receipt means something was read
/// twice.
final class LineItemsDoNotMatch extends Finding {
  const LineItemsDoNotMatch({
    required this.sum,
    required this.target,
    required this.againstSubtotal,
    required this.over,
  });

  final double sum;
  final double target;
  final bool againstSubtotal;
  final bool over;

  @override
  Severity get severity => over ? Severity.fail : Severity.warn;

  @override
  ReviewField? get field => ReviewField.lineItems;
}

final class LineArithmeticOff extends _Warning {
  const LineArithmeticOff({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.expected,
    required this.amount,
  });

  final String description;
  final double quantity;
  final double unitPrice;

  /// Quantity times unit price.
  final double expected;

  /// What the line itself reads.
  final double amount;

  @override
  ReviewField? get field => ReviewField.lineItems;
}

final class UnknownItemCategory extends _Failure {
  const UnknownItemCategory({required this.description, required this.read});

  final String description;
  final String read;

  @override
  ReviewField? get field => ReviewField.lineItems;
}

final class UnknownCategory extends _Failure {
  const UnknownCategory(this.read);

  final String read;

  @override
  ReviewField? get field => ReviewField.category;
}

final class UnknownPaymentMethod extends _Warning {
  const UnknownPaymentMethod(this.read);

  final String read;

  @override
  ReviewField? get field => ReviewField.paymentMethod;
}

/// The Model flagged the image itself. [reasons] is what it gave, and is
/// frequently empty.
final class ModelAskedForReview extends _Warning {
  const ModelAskedForReview(this.reasons);

  final List<String> reasons;

  @override
  ReviewField? get field => null;
}

/// Receipts round in ways that do not always reconcile to the cent, so
/// comparisons allow a small absolute slack.
const double _slack = 0.02;

/// How old a freshly photographed receipt can plausibly be before the date
/// itself becomes the suspicious part. Generous, so a genuinely old receipt
/// still passes.
const int _staleDays = 60;

class Check {
  final List<Finding> findings;

  const Check(this.findings);

  /// [alreadyReviewed] is what an Extraction being corrected months later
  /// carries. The staleness heuristics below are behavioural claims about a
  /// receipt that has just been entered — nobody photographs a year-old bill —
  /// and they are wrong about one the user confirmed the date on long ago.
  /// Everything else still runs, a date in the future included: an edit is
  /// exactly where a new typo comes from.
  factory Check.of(
    Extraction extraction, {
    DateTime? now,
    bool alreadyReviewed = false,
  }) => Check(_findings(extraction, now ?? DateTime.now(), alreadyReviewed));

  bool get hasFailure => findings.any((f) => f.severity == Severity.fail);
  bool get hasWarning => findings.any((f) => f.severity == Severity.warn);

  /// Nothing to look at. Not permission to skip Review — Review is
  /// unconditional — but permission to pre-fill the form and ask for one tap.
  bool get isConsistent => findings.isEmpty;
}

List<Finding> _findings(
  Extraction extraction,
  DateTime now,
  bool alreadyReviewed,
) {
  if (!extraction.isReceipt) return const [NotAReceipt()];

  final findings = <Finding>[];

  if (extraction.total <= 0) findings.add(const NoTotal());

  if (extraction.merchant.trim().isEmpty) findings.add(const NoMerchant());

  findings.addAll(_dateFindings(extraction.purchasedAt, now, alreadyReviewed));

  // Membership, not length: `XYZ` is three characters and no currency, and
  // `???` is what an Expense that never had one is stored with. An alias is
  // not accepted here — the Check reports what the Extraction says, and
  // rewriting `RM` into `MYR` is Review's job when it seeds the form.
  final currency = extraction.currency.trim();
  if (currency.isEmpty) {
    findings.add(const NoCurrency());
  } else if (!isoCurrencies.contains(currency.toUpperCase())) {
    findings.add(CurrencyNotAnIsoCode(currency));
  }

  final subtotal = extraction.subtotal;
  if (subtotal != null) {
    final tax = extraction.tax ?? 0;
    final tip = extraction.tip ?? 0;
    final composed = subtotal + tax + tip;
    if (!_close(composed, extraction.total)) {
      findings.add(
        TotalDoesNotAddUp(
          subtotal: subtotal,
          tax: tax,
          tip: tip,
          composed: composed,
          total: extraction.total,
        ),
      );
    }
  }

  if (extraction.lineItems.isNotEmpty) {
    findings.addAll(_lineItemFindings(extraction));
  }

  if (!categories.contains(extraction.category)) {
    findings.add(UnknownCategory(extraction.category));
  }

  if (!paymentMethods.contains(extraction.paymentMethod)) {
    findings.add(UnknownPaymentMethod(extraction.paymentMethod));
  }

  if (extraction.needsReview) {
    findings.add(ModelAskedForReview(extraction.reviewReasons));
  }

  return findings;
}

List<Finding> _dateFindings(
  String? purchasedAt,
  DateTime now,
  bool alreadyReviewed,
) {
  if (purchasedAt == null) return const [NoDate()];

  final date = DateTime.tryParse(purchasedAt);
  if (date == null) return [UnparseableDate(purchasedAt)];

  if (date.isAfter(now.add(const Duration(days: 1)))) {
    return [DateInTheFuture(purchasedAt)];
  }

  final age = now.difference(date).inDays;
  if (age <= _staleDays || alreadyReviewed) return const [];

  // A misread year slips past every other check here: 2025-08-14 is a
  // perfectly valid ISO date in the past. What gives it away is behavioural —
  // people photograph receipts within days of buying something, so a year-old
  // receipt arriving through the camera is far more likely a digit error.
  final monthsAgo = (now.year - date.year) * 12 + (now.month - date.month);
  final offByAYear = (monthsAgo - 12).abs() <= 1;

  return [
    if (offByAYear)
      YearLooksMisread(read: purchasedAt, likelyYear: now.year)
    else
      DateIsUnusuallyOld(read: purchasedAt, daysAgo: age),
  ];
}

List<Finding> _lineItemFindings(Extraction extraction) {
  final findings = <Finding>[];

  final lineSum = extraction.lineItems.fold<double>(
    0,
    (sum, item) => sum + item.amount,
  );
  final subtotal = extraction.subtotal;
  final target = subtotal ?? extraction.total;

  if (!_close(lineSum, target)) {
    findings.add(
      LineItemsDoNotMatch(
        sum: lineSum,
        target: target,
        againstSubtotal: subtotal != null,
        over: lineSum > target + _slack,
      ),
    );
  }

  for (final item in extraction.lineItems) {
    final quantity = item.quantity;
    final unitPrice = item.unitPrice;
    if (quantity != null && unitPrice != null) {
      final expected = quantity * unitPrice;
      if (!_close(expected, item.amount)) {
        findings.add(
          LineArithmeticOff(
            description: item.description,
            quantity: quantity,
            unitPrice: unitPrice,
            expected: expected,
            amount: item.amount,
          ),
        );
      }
    }

    if (!categories.contains(item.category)) {
      findings.add(
        UnknownItemCategory(description: item.description, read: item.category),
      );
    }
  }

  return findings;
}

bool _close(double a, double b) => (a - b).abs() <= _slack;
