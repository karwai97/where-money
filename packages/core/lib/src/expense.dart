/// An Expense: a reviewed, committed record of money spent. The only thing
/// charts and Recaps are ever built from.
library;

import 'check.dart';
import 'extraction.dart';
import 'review_field.dart';
import 'taxonomy.dart';

enum ExpenseSource { scanned, manual }

class Expense {
  final String id;

  /// The merchant, as printed on the paper. Null when the receipt did not say
  /// legibly and nobody typed it in — an absence rather than a placeholder,
  /// because a placeholder is words, and words in the domain end up quoted
  /// into a Recap in the wrong language (ADR-0007). What the app calls an
  /// Expense with no merchant is `merchantLabel`'s in `on_screen.dart`.
  final String? merchant;
  final DateTime date;
  final String currency;
  final double total;
  final String category;
  final List<LineItem> lineItems;
  final ExpenseSource source;
  final bool needsReview;

  /// The arithmetic printed on the receipt, kept because it is what the Check
  /// re-does. Without it, reopening a committed Expense would compare its line
  /// items against a total that includes tax and contradict the Review that
  /// let it in.
  final double? subtotal;
  final double? tax;
  final double? tip;
  final String paymentMethod;

  /// Where the receipt photo is, as a name within this device's Scan
  /// directory. Null for an Expense typed by hand, and dangling on a phone the
  /// Ledger was restored to — images never leave the device they were taken on
  /// (ADR-0003), so a Ledger can outlive its photos.
  final String? receiptPath;

  /// Which fields the user changed during Review. The tally of these across
  /// the Ledger is the project's only real measure of extraction accuracy.
  final List<String> correctedFields;

  const Expense({
    required this.id,
    required this.merchant,
    required this.date,
    required this.currency,
    required this.total,
    required this.category,
    required this.lineItems,
    required this.source,
    required this.needsReview,
    this.subtotal,
    this.tax,
    this.tip,
    this.paymentMethod = 'unknown',
    this.receiptPath,
    this.correctedFields = const [],
  });

  factory Expense.fromExtraction(
    Extraction extraction, {
    required String id,
    ExpenseSource source = ExpenseSource.scanned,
    List<String> correctedFields = const [],
    String? receiptPath,
    DateTime? now,
  }) {
    final fallbackDate = now ?? DateTime.now();
    final merchant = extraction.merchant.trim();
    final currency = extraction.currency.trim();

    return Expense(
      id: id,
      merchant: merchant.isEmpty ? null : merchant,
      date: DateTime.tryParse(extraction.purchasedAt ?? '') ?? fallbackDate,
      currency: currency.isEmpty ? '???' : currency.toUpperCase(),
      total: extraction.total,
      category: categories.contains(extraction.category)
          ? extraction.category
          : 'other',
      lineItems: extraction.lineItems,
      source: source,
      needsReview: _needsReview(extraction, correctedFields, now),
      subtotal: extraction.subtotal,
      tax: extraction.tax,
      tip: extraction.tip,
      paymentMethod: paymentMethods.contains(extraction.paymentMethod)
          ? extraction.paymentMethod
          : 'unknown',
      receiptPath: receiptPath,
      correctedFields: correctedFields,
    );
  }

  /// The Expense as something Review can edit again. The Model's own words are
  /// deliberately dropped: [Extraction.categoryReason] described a photo this
  /// Expense no longer is, and its request for a human to look has already
  /// been answered by the Review that committed it. Asking again on every edit
  /// would make a Finding that can never be settled. The Check's staleness
  /// heuristics are the other half of the same problem, and they answer to
  /// `Check.of(..., alreadyReviewed: true)`.
  Extraction asExtraction() => Extraction(
    isReceipt: true,
    // An Extraction says "not read" with a blank rather than a null, which is
    // also what `NoMerchant` looks for — so reopening an Expense with no
    // merchant raises the same Finding it was committed past.
    merchant: merchant ?? '',
    purchasedAt: date.toIso8601String().split('T').first,
    currency: currency,
    subtotal: subtotal,
    tax: tax,
    tip: tip,
    total: total,
    paymentMethod: paymentMethod,
    category: category,
    categoryReason: '',
    lineItems: lineItems,
    needsReview: false,
    reviewReasons: const [],
  );

  bool get wasCorrected => correctedFields.isNotEmpty;

  Expense copyWith({
    String? merchant,
    DateTime? date,
    String? currency,
    double? total,
    String? category,
    List<LineItem>? lineItems,
    bool? needsReview,
    double? subtotal,
    double? tax,
    double? tip,
    String? paymentMethod,
    String? receiptPath,
    List<String>? correctedFields,
  }) => Expense(
    id: id,
    merchant: merchant ?? this.merchant,
    date: date ?? this.date,
    currency: currency ?? this.currency,
    total: total ?? this.total,
    category: category ?? this.category,
    lineItems: lineItems ?? this.lineItems,
    source: source,
    needsReview: needsReview ?? this.needsReview,
    subtotal: subtotal ?? this.subtotal,
    tax: tax ?? this.tax,
    tip: tip ?? this.tip,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    receiptPath: receiptPath ?? this.receiptPath,
    correctedFields: correctedFields ?? this.correctedFields,
  );
}

/// A field the user has already corrected has just been reviewed by the only
/// authority that matters, so its Finding no longer counts. Correcting the
/// merchant says nothing about the total, which is why this is per field rather
/// than "any correction at all settles everything".
///
/// A Finding that names no field is not about anything the user could correct.
/// The only one that reaches a committed Expense is the Model asking for a
/// human to look, and a human just has — Review is unconditional, so nothing
/// gets here without one. Counting it would mark every Extraction the Model was
/// unsure about as unreviewed forever.
bool _needsReview(
  Extraction extraction,
  List<String> correctedFields,
  DateTime? now,
) => Check.of(extraction, now: now).findings.any(
  (finding) => switch (finding.field) {
    null => false,
    final ReviewField field => !correctedFields.contains(field.name),
  },
);
