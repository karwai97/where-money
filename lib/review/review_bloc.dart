import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../clock.dart';
import '../data/ledger_store.dart';
import '../data/receipt_store.dart';
import '../data/scan_store.dart';

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

/// Review what the Model read from a photographed receipt. Unconditional, even
/// when the Check found nothing: a clean Extraction earns a pre-filled form and
/// one tap, never a silent commit.
final class ScanReviewStarted extends ReviewEvent {
  const ScanReviewStarted(this.scan);

  final Scan scan;

  @override
  List<Object?> get props => [scan.id];
}

/// Correcting something that is already an Expense. The same screen and the
/// same Check as Review, over what the Ledger holds rather than over what the
/// Model read — a mistake noticed a week later is fixable.
final class ExpenseEditStarted extends ReviewEvent {
  const ExpenseEditStarted(this.expense);

  final Expense expense;

  @override
  List<Object?> get props => [expense.id];
}

final class _ReceiptArrived extends ReviewEvent {
  const _ReceiptArrived(this.lane, this.receipt);

  /// The lane the bytes were read for, so a receipt arriving after the user
  /// has moved on does not land in whatever is on screen now.
  final String lane;
  final Uint8List? receipt;

  @override
  List<Object?> get props => [lane, receipt];
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

/// The manual lane's key. Empty because no Scan has an empty id and an edit's
/// key is prefixed, so there is exactly one of it — which is what makes leaving
/// Review and coming back find the typing where it was.
const _manualLane = '';

final class ReviewInProgress extends ReviewState {
  const ReviewInProgress({
    required this.expenseId,
    required this.extraction,
    required this.check,
    required this.correctedFields,
    this.scan,
    this.editing,
    this.receipt,
    this.committing = false,
    this.refusal,
  });

  /// The document the committed Expense will be written to, decided when the
  /// Review starts rather than when it is committed. An edit keeps the id it
  /// already has, so a correction writes over the Expense rather than beside
  /// it; a Scan uses its own, so a Scan can only ever be one Expense however
  /// many times Review is reached; and a manual entry is given one here for
  /// the same reason the other two have one — a commit refused after the write
  /// has landed has to be able to land in the same place again.
  final String expenseId;

  /// The Scan being Reviewed, or null when the user is typing an Expense that
  /// had no receipt.
  final Scan? scan;

  /// The Expense being corrected, when this is an edit rather than a first
  /// Review. It carries the id, the source and the receipt the saved Expense
  /// has to keep.
  final Expense? editing;

  /// The receipt as it was photographed, to check the fields against. Null
  /// until it has been read off the disk, and always null for a manual entry.
  final Uint8List? receipt;

  final Extraction extraction;

  /// Re-run on every keystroke, so a total the Check disagrees with loses its
  /// Finding as soon as the user corrects it.
  final Check check;

  /// Field names, in the order the user first changed them.
  final List<String> correctedFields;

  final bool committing;

  /// Set when the last commit was turned away. The typing is still here.
  final String? refusal;

  /// Which half-finished Review this is. An edit is its own lane even when the
  /// Expense shares an id with the Scan it came from, so typing left in one
  /// cannot turn up in the other. The manual lane's key is empty, and no Scan
  /// has an empty id.
  String get lane => switch ((editing, scan)) {
    (final Expense expense, _) => 'expense:${expense.id}',
    (_, final Scan scan) => scan.id,
    _ => _manualLane,
  };

  /// [committing] and [refusal] are deliberately not carried over: each
  /// describes one attempt at the Ledger, and the next state is not that
  /// attempt.
  ReviewInProgress copyWith({
    Uint8List? receipt,
    Extraction? extraction,
    Check? check,
    List<String>? correctedFields,
    bool committing = false,
    String? refusal,
  }) => ReviewInProgress(
    expenseId: expenseId,
    scan: scan,
    editing: editing,
    receipt: receipt ?? this.receipt,
    extraction: extraction ?? this.extraction,
    check: check ?? this.check,
    correctedFields: correctedFields ?? this.correctedFields,
    committing: committing,
    refusal: refusal,
  );
}

class ReviewBloc extends Bloc<ReviewEvent, ReviewState> {
  ReviewBloc(this._ledger, this._scans, this._receipts, {Clock? clock})
    : _now = clock ?? DateTime.now,
      super(const ReviewIdle()) {
    on<ManualExpenseStarted>(_onManualExpenseStarted);
    on<ScanReviewStarted>(_onScanReviewStarted);
    on<ExpenseEditStarted>(_onExpenseEditStarted);
    on<_ReceiptArrived>(_onReceiptArrived);
    on<FieldCorrected>(_onFieldCorrected);
    on<LineItemAdded>(_onLineItemAdded);
    on<LineItemRemoved>(_onLineItemRemoved);
    on<LineItemCorrected>(_onLineItemCorrected);
    on<ReviewCommitted>(_onCommitted);
  }

  /// All three, because a Review really does touch all three: it reads the
  /// Receipt to check the fields against, writes the Expense, and moves the
  /// Scan out of the Inbox once that Expense is durable.
  final LedgerStore _ledger;
  final ScanStore _scans;
  final ReceiptStore _receipts;

  final Clock _now;

  /// What day it is, for the one thing on this screen that needs it and is not
  /// a Finding: the calendar the Date field opens has to be bounded, and a
  /// test that pins those bounds cannot be left reading the machine's clock.
  Clock get clock => _now;

  var _typedByHand = 0;

  /// An id for an Expense that has nothing to borrow one from. The counter is
  /// there because two Expenses typed in the same microsecond are not the same
  /// Expense.
  String _anIdFor(DateTime at) =>
      '${at.microsecondsSinceEpoch}-${++_typedByHand}';

  /// One half-finished Review per Scan, plus one for the manual lane. Leaving
  /// Review to look at something else and coming back should find the typing
  /// where it was, whichever lane it was in.
  final _unfinished = <String, ReviewInProgress>{};

  ReviewInProgress? get _current {
    final state = this.state;
    return state is ReviewInProgress ? state : null;
  }

  void _onManualExpenseStarted(
    ManualExpenseStarted event,
    Emitter<ReviewState> emit,
  ) {
    final held = _unfinished[_manualLane];
    _show(
      emit,
      held ??
          ReviewInProgress(
            expenseId: _anIdFor(_now()),
            extraction: Extraction.blank(),
            check: Check.of(Extraction.blank(), now: _now()),
            correctedFields: const [],
          ),
    );
  }

  void _onScanReviewStarted(
    ScanReviewStarted event,
    Emitter<ReviewState> emit,
  ) {
    final extraction = event.scan.extraction;
    if (extraction == null) return;

    final started = _unfinished[event.scan.id];
    _show(
      emit,
      started ??
          ReviewInProgress(
            expenseId: event.scan.id,
            scan: event.scan,
            extraction: extraction,
            check: Check.of(extraction, now: _now()),
            correctedFields: const [],
          ),
    );

    if (started == null) {
      _scans
          .receiptFor(event.scan.id)
          .then((receipt) => add(_ReceiptArrived(event.scan.id, receipt)));
    }
  }

  void _onExpenseEditStarted(
    ExpenseEditStarted event,
    Emitter<ReviewState> emit,
  ) {
    final extraction = event.expense.asExtraction();
    final fresh = ReviewInProgress(
      expenseId: event.expense.id,
      editing: event.expense,
      extraction: extraction,
      check: Check.of(extraction, now: _now(), alreadyReviewed: true),
      // What the user corrected before is carried in, so this edit adds to the
      // tally rather than starting it over.
      correctedFields: event.expense.correctedFields,
    );
    final started = _unfinished[fresh.lane];
    _show(emit, started ?? fresh);

    final path = event.expense.receiptPath;
    if (started == null && path != null) {
      _receipts
          .bytesAt(path)
          .then((receipt) => add(_ReceiptArrived(fresh.lane, receipt)));
    }
  }

  void _onReceiptArrived(_ReceiptArrived event, Emitter<ReviewState> emit) {
    final receipt = event.receipt;
    final started = _unfinished[event.lane];
    if (receipt == null || started == null) return;

    final withReceipt = started.copyWith(receipt: receipt);
    _unfinished[event.lane] = withReceipt;
    if (_current?.lane == event.lane) emit(withReceipt);
  }

  void _onFieldCorrected(FieldCorrected event, Emitter<ReviewState> emit) {
    final current = _current;
    if (current == null) return;

    final next = _applyField(current.extraction, event.field, event.value);
    final changed =
        next.valueAt(event.field) != current.extraction.valueAt(event.field);

    _show(
      emit,
      _rechecked(
        current,
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

    _show(
      emit,
      _rechecked(
        current,
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

    _show(
      emit,
      _rechecked(
        current,
        current.extraction.copyWith(lineItems: items),
        untouched
            ? current.correctedFields
            : _recording(current.correctedFields, ReviewField.lineItems),
      ),
    );
  }

  void _onLineItemCorrected(
    LineItemCorrected event,
    Emitter<ReviewState> emit,
  ) {
    final current = _current;
    if (current == null) return;

    final items = [...current.extraction.lineItems];
    if (event.index < 0 || event.index >= items.length) return;
    final before = items[event.index];
    final after = _applyLineItemField(before, event.field, event.value);
    items[event.index] = after;
    final changed = after.valueAt(event.field) != before.valueAt(event.field);

    _show(
      emit,
      _rechecked(
        current,
        current.extraction.copyWith(lineItems: items),
        changed
            ? _recording(current.correctedFields, ReviewField.lineItems)
            : current.correctedFields,
      ),
    );
  }

  /// Two writes to two stores, and nothing spans them: the Expense goes to
  /// Firestore and the Scan leaves a directory on this phone. So the middle is
  /// a state a user can be left in — the Expense saved, the Scan still in the
  /// Inbox, a refusal on screen — and the way out of it is committing again.
  ///
  /// That works only because the second attempt lands on the first.
  /// `LedgerStore.add` is `doc(expense.id).set(...)`, so an id that does not
  /// change between attempts is an overwrite and one that does is a second
  /// Expense for the same receipt. Which is why the id belongs to the Review
  /// rather than to the attempt.
  Future<void> _onCommitted(
    ReviewCommitted event,
    Emitter<ReviewState> emit,
  ) async {
    final current = _current;
    if (current == null || current.committing) return;

    final scan = current.scan;
    final editing = current.editing;
    _show(emit, current.copyWith(committing: true));

    final at = _now();
    try {
      await _ledger.add(
        Expense.fromExtraction(
          current.extraction,
          id: current.expenseId,
          source:
              editing?.source ??
              (scan == null ? ExpenseSource.manual : ExpenseSource.scanned),
          correctedFields: current.correctedFields,
          receiptPath:
              editing?.receiptPath ??
              (scan == null ? null : receiptPathFor(scan.id)),
          now: at,
        ),
      );
      // Only now does the Scan leave the Inbox: the Expense is what it was
      // waiting to become.
      if (scan != null) await _scans.put(scan.movedTo(ScanState.committed));

      _unfinished.remove(current.lane);
      emit(const ReviewIdle());
    } catch (error) {
      _show(emit, current.copyWith(refusal: error.toString()));
    }
  }

  void _show(Emitter<ReviewState> emit, ReviewInProgress state) {
    _unfinished[state.lane] = state;
    emit(state);
  }

  /// The Check runs again on every change, so a Finding stops being shown the
  /// moment the user answers it.
  ReviewInProgress _rechecked(
    ReviewInProgress current,
    Extraction extraction,
    List<String> correctedFields,
  ) => current.copyWith(
    extraction: extraction,
    check: Check.of(
      extraction,
      now: _now(),
      alreadyReviewed: current.editing != null,
    ),
    correctedFields: correctedFields,
  );

  static List<String> _recording(List<String> fields, ReviewField field) =>
      fields.contains(field.name) ? fields : [...fields, field.name];
}

const _blankLineItem = LineItem(description: '', amount: 0, category: 'other');

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

LineItem _applyLineItemField(LineItem item, LineItemField field, String value) {
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
