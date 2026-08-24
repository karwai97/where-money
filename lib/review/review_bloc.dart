import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../data/ledger_store.dart';

sealed class ReviewEvent extends Equatable {
  const ReviewEvent();

  @override
  List<Object?> get props => const [];
}

/// Review an Expense the user is typing themselves. Work already in progress
/// survives — an interruption should not cost the user their typing.
final class ManualExpenseStarted extends ReviewEvent {
  const ManualExpenseStarted();
}

final class FieldCorrected extends ReviewEvent {
  const FieldCorrected(this.field, this.value);

  final ReviewField field;

  /// Raw, as typed. Parsing a half-finished number belongs here rather than in
  /// the widget.
  final String value;

  @override
  List<Object?> get props => [field, value];
}

final class LineItemAdded extends ReviewEvent {
  const LineItemAdded();
}

final class LineItemRemoved extends ReviewEvent {
  const LineItemRemoved(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

final class LineItemCorrected extends ReviewEvent {
  const LineItemCorrected(this.index, this.field, this.value);

  final int index;
  final LineItemField field;
  final String value;

  @override
  List<Object?> get props => [index, field, value];
}

final class ReviewCommitted extends ReviewEvent {
  const ReviewCommitted();
}

/// States are compared by identity rather than by value: an Extraction is not
/// Equatable, and every keystroke produces a fresh one, so a correction that
/// leaves the fields looking the same still reaches the screen.
sealed class ReviewState {
  const ReviewState();
}

/// Nothing is under Review. Either nothing has been started, or the last one
/// became an Expense.
final class ReviewIdle extends ReviewState {
  const ReviewIdle();
}

final class ReviewInProgress extends ReviewState {
  const ReviewInProgress({
    required this.extraction,
    required this.check,
    required this.correctedFields,
    this.committing = false,
    this.refusal,
  });

  final Extraction extraction;

  /// Re-run on every keystroke, so a total the Check disagrees with loses its
  /// Finding as soon as the user corrects it.
  final Check check;

  /// Field names, in the order the user first changed them.
  final List<String> correctedFields;

  final bool committing;

  /// Set when the last commit was turned away. The typing is still here.
  final String? refusal;
}

class ReviewBloc extends Bloc<ReviewEvent, ReviewState> {
  ReviewBloc(this._store, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now,
      super(const ReviewIdle()) {
    on<ManualExpenseStarted>(_onManualExpenseStarted);
    on<FieldCorrected>(_onFieldCorrected);
    on<LineItemAdded>(_onLineItemAdded);
    on<LineItemRemoved>(_onLineItemRemoved);
    on<LineItemCorrected>(_onLineItemCorrected);
    on<ReviewCommitted>(_onCommitted);
  }

  final LedgerStore _store;
  final DateTime Function() _now;
  var _committed = 0;

  ReviewInProgress? get _current {
    final state = this.state;
    return state is ReviewInProgress ? state : null;
  }

  void _onManualExpenseStarted(
    ManualExpenseStarted event,
    Emitter<ReviewState> emit,
  ) {
    if (_current != null) return;
    emit(_reviewing(Extraction.blank(), const []));
  }

  void _onFieldCorrected(FieldCorrected event, Emitter<ReviewState> emit) {
    final current = _current;
    if (current == null) return;

    final next = _applyField(current.extraction, event.field, event.value);
    final changed =
        next.valueAt(event.field) != current.extraction.valueAt(event.field);

    emit(
      _reviewing(
        next,
        changed
            ? _recording(current.correctedFields, event.field)
            : current.correctedFields,
      ),
    );
  }

  /// An empty row is a placeholder, not a statement about the receipt, so it
  /// is deliberately not recorded as a correction — otherwise one tap here
  /// would settle the Finding about the line items summing wrong, which adding
  /// an empty row has just made worse.
  void _onLineItemAdded(LineItemAdded event, Emitter<ReviewState> emit) {
    final current = _current;
    if (current == null) return;

    emit(
      _reviewing(
        current.extraction.copyWith(
          lineItems: [...current.extraction.lineItems, _blankLineItem],
        ),
        current.correctedFields,
      ),
    );
  }

  void _onLineItemRemoved(LineItemRemoved event, Emitter<ReviewState> emit) {
    final current = _current;
    if (current == null) return;

    final items = [...current.extraction.lineItems];
    if (event.index < 0 || event.index >= items.length) return;
    final removed = items.removeAt(event.index);

    // Deleting a row the user typed into says something about the receipt.
    // Deleting the empty one they just added — still the same const instance
    // the add put there — says nothing.
    final untouched = identical(removed, _blankLineItem);

    emit(
      _reviewing(
        current.extraction.copyWith(lineItems: items),
        untouched
            ? current.correctedFields
            : _recording(current.correctedFields, ReviewField.lineItems),
      ),
    );
  }

  void _onLineItemCorrected(LineItemCorrected event, Emitter<ReviewState> emit) {
    final current = _current;
    if (current == null) return;

    final items = [...current.extraction.lineItems];
    if (event.index < 0 || event.index >= items.length) return;
    final before = items[event.index];
    final after = _applyLineItemField(before, event.field, event.value);
    items[event.index] = after;
    final changed = after.valueAt(event.field) != before.valueAt(event.field);

    emit(
      _reviewing(
        current.extraction.copyWith(lineItems: items),
        changed
            ? _recording(current.correctedFields, ReviewField.lineItems)
            : current.correctedFields,
      ),
    );
  }

  Future<void> _onCommitted(
    ReviewCommitted event,
    Emitter<ReviewState> emit,
  ) async {
    final current = _current;
    if (current == null || current.committing) return;

    emit(
      ReviewInProgress(
        extraction: current.extraction,
        check: current.check,
        correctedFields: current.correctedFields,
        committing: true,
      ),
    );

    final at = _now();
    try {
      await _store.add(
        Expense.fromExtraction(
          current.extraction,
          id: '${at.microsecondsSinceEpoch}-${++_committed}',
          source: ExpenseSource.manual,
          correctedFields: current.correctedFields,
          now: at,
        ),
      );
      emit(const ReviewIdle());
    } catch (error) {
      emit(
        ReviewInProgress(
          extraction: current.extraction,
          check: current.check,
          correctedFields: current.correctedFields,
          refusal: error.toString(),
        ),
      );
    }
  }

  ReviewInProgress _reviewing(
    Extraction extraction,
    List<String> correctedFields,
  ) => ReviewInProgress(
    extraction: extraction,
    check: Check.of(extraction, now: _now()),
    correctedFields: correctedFields,
  );

  static List<String> _recording(List<String> fields, ReviewField field) =>
      fields.contains(field.name) ? fields : [...fields, field.name];
}

const _blankLineItem = LineItem(
  description: '',
  amount: 0,
  category: 'other',
);

Extraction _applyField(Extraction extraction, ReviewField field, String value) {
  final text = value.trim();
  return switch (field) {
    ReviewField.merchant => extraction.copyWith(merchant: value),
    ReviewField.purchasedAt => extraction.copyWith(
      purchasedAt: text,
      clearPurchasedAt: text.isEmpty,
    ),
    ReviewField.currency => extraction.copyWith(currency: text.toUpperCase()),
    ReviewField.subtotal => extraction.copyWith(
      subtotal: _amount(text),
      clearSubtotal: _amount(text) == null,
    ),
    ReviewField.tax => extraction.copyWith(
      tax: _amount(text),
      clearTax: _amount(text) == null,
    ),
    ReviewField.tip => extraction.copyWith(
      tip: _amount(text),
      clearTip: _amount(text) == null,
    ),
    ReviewField.total => extraction.copyWith(total: _amount(text) ?? 0),
    ReviewField.paymentMethod => extraction.copyWith(paymentMethod: text),
    ReviewField.category => extraction.copyWith(category: text),
    ReviewField.lineItems => extraction,
  };
}

LineItem _applyLineItemField(
  LineItem item,
  LineItemField field,
  String value,
) {
  final text = value.trim();
  return switch (field) {
    LineItemField.description => item.copyWith(description: value),
    LineItemField.quantity => item.copyWith(
      quantity: _amount(text),
      clearQuantity: text.isEmpty,
    ),
    LineItemField.unitPrice => item.copyWith(
      unitPrice: _amount(text),
      clearUnitPrice: text.isEmpty,
    ),
    LineItemField.amount => item.copyWith(amount: _amount(text) ?? 0),
    LineItemField.category => item.copyWith(category: text),
  };
}

/// The Check runs on every keystroke, which means it runs on numbers that are
/// not finished being typed. "26." is a real thing to see mid-typing and should
/// read as 26; "-" is not a number yet and should read as nothing at all.
double? _amount(String text) {
  if (text.isEmpty) return null;
  return double.tryParse(text.endsWith('.') ? '${text}0' : text);
}
