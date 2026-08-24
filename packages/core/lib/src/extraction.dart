/// What the Model claims it read from a receipt. Well-shaped, not necessarily
/// true — the Check decides how far to believe it and Review has the last word.
library;

import 'review_field.dart';

class LineItem {
  final String description;
  final double? quantity;
  final double? unitPrice;
  final double amount;
  final String category;

  const LineItem({
    required this.description,
    required this.amount,
    required this.category,
    this.quantity,
    this.unitPrice,
  });

  factory LineItem.fromJson(Map<String, dynamic> json) => LineItem(
    description: (json['description'] ?? '') as String,
    quantity: _toDouble(json['quantity']),
    unitPrice: _toDouble(json['unit_price']),
    amount: _toDouble(json['amount']) ?? 0,
    category: (json['category'] ?? 'other') as String,
  );

  LineItem copyWith({
    String? description,
    double? quantity,
    bool clearQuantity = false,
    double? unitPrice,
    bool clearUnitPrice = false,
    double? amount,
    String? category,
  }) => LineItem(
    description: description ?? this.description,
    quantity: clearQuantity ? null : (quantity ?? this.quantity),
    unitPrice: clearUnitPrice ? null : (unitPrice ?? this.unitPrice),
    amount: amount ?? this.amount,
    category: category ?? this.category,
  );

  /// The field named, for telling a real correction from a keystroke that
  /// changed nothing. A [LineItem] is a value with no identity, so comparing
  /// whole rows would say "changed" every time.
  Object? valueAt(LineItemField field) => switch (field) {
    LineItemField.description => description,
    LineItemField.quantity => quantity,
    LineItemField.unitPrice => unitPrice,
    LineItemField.amount => amount,
    LineItemField.category => category,
  };

  Map<String, dynamic> toJson() => {
    'description': description,
    'quantity': quantity,
    'unit_price': unitPrice,
    'amount': amount,
    'category': category,
  };
}

class Extraction {
  final bool isReceipt;
  final String merchant;

  /// ISO yyyy-MM-dd, or null when the date was not legible.
  final String? purchasedAt;
  final String currency;
  final double? subtotal;
  final double? tax;
  final double? tip;
  final double total;
  final String paymentMethod;
  final String category;
  final String categoryReason;
  final List<LineItem> lineItems;
  final bool needsReview;
  final List<String> reviewReasons;

  const Extraction({
    required this.isReceipt,
    required this.merchant,
    required this.purchasedAt,
    required this.currency,
    required this.subtotal,
    required this.tax,
    required this.tip,
    required this.total,
    required this.paymentMethod,
    required this.category,
    required this.categoryReason,
    required this.lineItems,
    required this.needsReview,
    required this.reviewReasons,
  });

  /// Nothing read, because nothing was photographed: the starting point for
  /// an Expense typed by hand. [isReceipt] is true so the Check measures the
  /// empty fields rather than dismissing the whole thing as not a receipt —
  /// there is no image here for that question to be about.
  factory Extraction.blank() => const Extraction(
    isReceipt: true,
    merchant: '',
    purchasedAt: null,
    currency: '',
    subtotal: null,
    tax: null,
    tip: null,
    total: 0,
    paymentMethod: 'unknown',
    category: 'other',
    categoryReason: '',
    lineItems: [],
    needsReview: false,
    reviewReasons: [],
  );

  factory Extraction.fromJson(Map<String, dynamic> json) => Extraction(
    isReceipt: (json['is_receipt'] ?? false) as bool,
    merchant: (json['merchant'] ?? '') as String,
    purchasedAt: json['purchased_at'] as String?,
    currency: (json['currency'] ?? '') as String,
    subtotal: _toDouble(json['subtotal']),
    tax: _toDouble(json['tax']),
    tip: _toDouble(json['tip']),
    total: _toDouble(json['total']) ?? 0,
    paymentMethod: (json['payment_method'] ?? 'unknown') as String,
    category: (json['category'] ?? 'other') as String,
    categoryReason: (json['category_reason'] ?? '') as String,
    lineItems: ((json['line_items'] ?? const []) as List)
        .map((e) => LineItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    needsReview: (json['needs_review'] ?? false) as bool,
    reviewReasons: ((json['review_reasons'] ?? const []) as List)
        .map((e) => e.toString())
        .toList(),
  );

  /// Nullable scalars take a `clear` flag rather than reading a null argument
  /// as "leave it alone", so "the user deleted the tip" stays expressible.
  Extraction copyWith({
    bool? isReceipt,
    String? merchant,
    String? purchasedAt,
    bool clearPurchasedAt = false,
    String? currency,
    double? subtotal,
    bool clearSubtotal = false,
    double? tax,
    bool clearTax = false,
    double? tip,
    bool clearTip = false,
    double? total,
    String? paymentMethod,
    String? category,
    List<LineItem>? lineItems,
    bool? needsReview,
    List<String>? reviewReasons,
  }) => Extraction(
    isReceipt: isReceipt ?? this.isReceipt,
    merchant: merchant ?? this.merchant,
    purchasedAt: clearPurchasedAt ? null : (purchasedAt ?? this.purchasedAt),
    currency: currency ?? this.currency,
    subtotal: clearSubtotal ? null : (subtotal ?? this.subtotal),
    tax: clearTax ? null : (tax ?? this.tax),
    tip: clearTip ? null : (tip ?? this.tip),
    total: total ?? this.total,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    category: category ?? this.category,
    categoryReason: categoryReason,
    lineItems: lineItems ?? this.lineItems,
    needsReview: needsReview ?? this.needsReview,
    reviewReasons: reviewReasons ?? this.reviewReasons,
  );

  /// The field named, for comparing before against after. Review needs this to
  /// tell a real correction from a keystroke that changed nothing.
  Object? valueAt(ReviewField field) => switch (field) {
    ReviewField.merchant => merchant,
    ReviewField.purchasedAt => purchasedAt,
    ReviewField.currency => currency,
    ReviewField.subtotal => subtotal,
    ReviewField.tax => tax,
    ReviewField.tip => tip,
    ReviewField.total => total,
    ReviewField.paymentMethod => paymentMethod,
    ReviewField.category => category,
    ReviewField.lineItems => lineItems,
  };

  Map<String, dynamic> toJson() => {
    'is_receipt': isReceipt,
    'merchant': merchant,
    'purchased_at': purchasedAt,
    'currency': currency,
    'subtotal': subtotal,
    'tax': tax,
    'tip': tip,
    'total': total,
    'payment_method': paymentMethod,
    'category': category,
    'category_reason': categoryReason,
    'line_items': lineItems.map((e) => e.toJson()).toList(),
    'needs_review': needsReview,
    'review_reasons': reviewReasons,
  };
}

double? _toDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
