/// An Expense: a reviewed, committed record of money spent. The only thing
/// charts and Recaps are ever built from.
library;

import 'check.dart';
import 'extraction.dart';
import 'taxonomy.dart';

enum ExpenseSource { scanned, manual }

class Expense {
  final String id;
  final String merchant;
  final DateTime date;
  final String currency;
  final double total;
  final String category;
  final List<LineItem> lineItems;
  final ExpenseSource source;
  final bool needsReview;

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
    this.correctedFields = const [],
  });

  factory Expense.fromExtraction(
    Extraction extraction, {
    required String id,
    List<String> correctedFields = const [],
    DateTime? now,
  }) {
    final fallbackDate = now ?? DateTime.now();
    final merchant = extraction.merchant.trim();
    final currency = extraction.currency.trim();

    return Expense(
      id: id,
      merchant: merchant.isEmpty ? 'Unknown merchant' : merchant,
      date: DateTime.tryParse(extraction.purchasedAt ?? '') ?? fallbackDate,
      currency: currency.isEmpty ? '???' : currency.toUpperCase(),
      total: extraction.total,
      category: categories.contains(extraction.category)
          ? extraction.category
          : 'other',
      lineItems: extraction.lineItems,
      source: ExpenseSource.scanned,
      // A field the user has already fixed has just been reviewed by the only
      // authority that matters, so it no longer counts as needing review.
      needsReview:
          !Check.of(extraction, now: now).isConsistent &&
          correctedFields.isEmpty,
      correctedFields: correctedFields,
    );
  }

  bool get wasCorrected => correctedFields.isNotEmpty;

  Expense copyWith({
    String? merchant,
    DateTime? date,
    String? currency,
    double? total,
    String? category,
    List<LineItem>? lineItems,
    bool? needsReview,
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
    correctedFields: correctedFields ?? this.correctedFields,
  );
}
