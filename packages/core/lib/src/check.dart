/// The Check: the on-device arithmetic and plausibility pass over an
/// Extraction. Structured outputs guarantee the JSON parses; they guarantee
/// nothing about whether the numbers are right. This is the cheap local
/// defence — it re-does the arithmetic printed on the receipt and reports
/// where the Extraction contradicts itself. It costs nothing and calls nothing.
library;

import 'extraction.dart';
import 'taxonomy.dart';

enum Severity { warn, fail }

class Finding {
  final String label;
  final String detail;
  final Severity severity;

  const Finding(this.label, this.detail, this.severity);
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

  factory Check.of(Extraction extraction, {DateTime? now}) =>
      Check(_findings(extraction, now ?? DateTime.now()));

  bool get hasFailure => findings.any((f) => f.severity == Severity.fail);
  bool get hasWarning => findings.any((f) => f.severity == Severity.warn);

  /// Nothing to look at. Not permission to skip Review — Review is
  /// unconditional — but permission to pre-fill the form and ask for one tap.
  bool get isConsistent => findings.isEmpty;
}

List<Finding> _findings(Extraction extraction, DateTime now) {
  if (!extraction.isReceipt) {
    return const [
      Finding(
        'Not a receipt',
        'The model says this image is not a receipt.',
        Severity.fail,
      ),
    ];
  }

  final findings = <Finding>[];

  if (extraction.total <= 0) {
    findings.add(
      const Finding(
        'No total',
        'Total is zero or negative — nothing usable was read.',
        Severity.fail,
      ),
    );
  }

  if (extraction.merchant.trim().isEmpty) {
    findings.add(
      const Finding(
        'No merchant',
        'Merchant name was not legible. The expense is unattributable.',
        Severity.warn,
      ),
    );
  }

  findings.addAll(_dateFindings(extraction.purchasedAt, now));

  final currency = extraction.currency.trim();
  if (currency.length != 3) {
    findings.add(
      Finding(
        'Currency unclear',
        currency.isEmpty
            ? 'No currency identified, so the amount has no unit.'
            : 'Got "$currency", which is not an ISO 4217 code.',
        Severity.warn,
      ),
    );
  }

  final subtotal = extraction.subtotal;
  if (subtotal != null) {
    final tax = extraction.tax ?? 0;
    final tip = extraction.tip ?? 0;
    final composed = subtotal + tax + tip;
    if (!_close(composed, extraction.total)) {
      findings.add(
        Finding(
          'Total does not add up',
          'subtotal ${_money(subtotal)} + tax ${_money(tax)} + tip '
              '${_money(tip)} = ${_money(composed)}, but total reads '
              '${_money(extraction.total)} (off by '
              '${_money((composed - extraction.total).abs())}).',
          Severity.fail,
        ),
      );
    }
  }

  if (extraction.lineItems.isNotEmpty) {
    findings.addAll(_lineItemFindings(extraction));
  }

  if (!categories.contains(extraction.category)) {
    findings.add(
      Finding(
        'Unknown category',
        'Got "${extraction.category}", which is outside the enum the schema '
            'declared.',
        Severity.fail,
      ),
    );
  }

  if (!paymentMethods.contains(extraction.paymentMethod)) {
    findings.add(
      Finding(
        'Unknown payment method',
        'Got "${extraction.paymentMethod}".',
        Severity.warn,
      ),
    );
  }

  if (extraction.needsReview) {
    findings.add(
      Finding(
        'Model asked for review',
        extraction.reviewReasons.isEmpty
            ? 'It flagged the image but gave no reason.'
            : extraction.reviewReasons.join('; '),
        Severity.warn,
      ),
    );
  }

  return findings;
}

List<Finding> _dateFindings(String? purchasedAt, DateTime now) {
  if (purchasedAt == null) {
    return const [
      Finding(
        'No date',
        'The date on the receipt was not legible — it will default to today.',
        Severity.warn,
      ),
    ];
  }

  final date = DateTime.tryParse(purchasedAt);
  if (date == null) {
    return [
      Finding(
        'Unparseable date',
        'Got "$purchasedAt", which is not an ISO date.',
        Severity.warn,
      ),
    ];
  }

  if (date.isAfter(now.add(const Duration(days: 1)))) {
    return [
      Finding(
        'Date in the future',
        'Read $purchasedAt, which has not happened yet — probably a card '
            'expiry or a best-before date rather than the purchase.',
        Severity.fail,
      ),
    ];
  }

  final age = now.difference(date).inDays;
  if (age <= _staleDays) return const [];

  // A misread year slips past every other check here: 2025-08-14 is a
  // perfectly valid ISO date in the past. What gives it away is behavioural —
  // people photograph receipts within days of buying something, so a year-old
  // receipt arriving through the camera is far more likely a digit error.
  final monthsAgo = (now.year - date.year) * 12 + (now.month - date.month);
  final offByAYear = (monthsAgo - 12).abs() <= 1;

  return [
    Finding(
      offByAYear ? 'Year looks misread' : 'Date is unusually old',
      offByAYear
          ? 'Read $purchasedAt, almost exactly a year ago. On a freshly '
                'photographed receipt that usually means the year was '
                'misread — ${now.year} is the likely value.'
          : 'Read $purchasedAt, $age days ago. Fine for an old receipt, but '
                'worth checking if this was just photographed.',
      Severity.warn,
    ),
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
  final targetName = subtotal != null ? 'subtotal' : 'total';

  if (!_close(lineSum, target)) {
    // Discounts and unlisted deposits legitimately break this, so a shortfall
    // is a warning while an overshoot is a failure.
    final over = lineSum > target + _slack;
    findings.add(
      Finding(
        'Line items do not match $targetName',
        'Items sum to ${_money(lineSum)} against a $targetName of '
            '${_money(target)}'
            '${over ? ' — items exceed the receipt, so something was double-read.' : ' — an item may have been missed, or a discount was not itemised.'}',
        over ? Severity.fail : Severity.warn,
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
          Finding(
            'Line arithmetic off',
            '"${item.description}": ${_money(quantity)} x ${_money(unitPrice)} '
                '= ${_money(expected)}, but the line reads '
                '${_money(item.amount)}.',
            Severity.warn,
          ),
        );
      }
    }

    if (!categories.contains(item.category)) {
      findings.add(
        Finding(
          'Unknown item category',
          '"${item.description}" came back as "${item.category}", which is '
              'not in the taxonomy.',
          Severity.fail,
        ),
      );
    }
  }

  return findings;
}

bool _close(double a, double b) => (a - b).abs() <= _slack;

String _money(double value) => value.toStringAsFixed(2);
