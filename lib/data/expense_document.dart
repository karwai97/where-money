/// The translation between an Expense and the shape Firestore holds it in.
///
/// Deliberately not `Expense.toJson`: the Model wire format and the Ledger's
/// storage format are free to move apart, and this is the only file that knows
/// either half of this one.
library;

import 'package:where_money_core/where_money_core.dart';

import 'receipt_store.dart';

Map<String, Object?> expenseToDocument(Expense expense) => {
  'merchant': expense.merchant,
  // ISO-8601 rather than a Timestamp, so ordering and month ranges are plain
  // string comparisons and this mapping stays testable without Firestore.
  'date': expense.date.toIso8601String(),
  'currency': expense.currency,
  'total': expense.total,
  'category': expense.category,
  'lineItems': [
    for (final item in expense.lineItems)
      {
        'description': item.description,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice,
        'amount': item.amount,
        'category': item.category,
      },
  ],
  'source': expense.source.name,
  'needsReview': expense.needsReview,
  'subtotal': expense.subtotal,
  'tax': expense.tax,
  'tip': expense.tip,
  'paymentMethod': expense.paymentMethod,
  // A name within this device's Scan directory rather than an absolute path:
  // the directory moves between app versions and the file does not.
  'receiptPath': expense.receiptPath,
  'correctedFields': expense.correctedFields,
};

/// Throws [FormatException] if the document has no legible amount or date.
/// Everything else falls back, but a total is the one thing this app must
/// never be confidently wrong about, so a corrupt one surfaces rather than
/// becoming a plausible-looking 0.00.
Expense expenseFromDocument(String id, Map<String, Object?> document) {
  final source = ExpenseSource.values.firstWhere(
    (source) => source.name == _string(document['source']),
    orElse: () => ExpenseSource.scanned,
  );

  return Expense(
    id: id,
    merchant: _string(document['merchant']) ?? 'Unknown merchant',
    date:
        DateTime.tryParse(_string(document['date']) ?? '') ??
        (throw FormatException('Expense $id has no legible date.')),
    currency: _string(document['currency']) ?? '???',
    total:
        _double(document['total']) ??
        (throw FormatException('Expense $id has no legible total.')),
    category: _string(document['category']) ?? 'other',
    lineItems: [
      for (final item in _maps(document['lineItems']))
        LineItem(
          description: _string(item['description']) ?? '',
          quantity: _double(item['quantity']),
          unitPrice: _double(item['unitPrice']),
          amount: _double(item['amount']) ?? 0,
          category: _string(item['category']) ?? 'other',
        ),
    ],
    source: source,
    needsReview: document['needsReview'] == true,
    subtotal: _double(document['subtotal']),
    tax: _double(document['tax']),
    tip: _double(document['tip']),
    paymentMethod: _string(document['paymentMethod']) ?? 'unknown',
    receiptPath:
        _string(document['receiptPath']) ??
        // Expenses committed before the path was written down have none. A
        // scanned Expense carries its Scan's id and the photo is named after
        // the Scan, so the receipt is recoverable rather than lost.
        (source == ExpenseSource.scanned ? receiptPathFor(id) : null),
    correctedFields: [
      for (final field in _list(document['correctedFields'])) ?_string(field),
    ],
  );
}

String? _string(Object? value) => value is String ? value : null;

double? _double(Object? value) => value is num ? value.toDouble() : null;

List<Object?> _list(Object? value) => value is List ? value : const [];

Iterable<Map<Object?, Object?>> _maps(Object? value) =>
    _list(value).whereType<Map<Object?, Object?>>();
