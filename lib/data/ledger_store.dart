/// The boundary to the Ledger's persistence. Above this line an Expense is an
/// Expense; below it, and nowhere else, it is a Firestore document.
///
/// The Scan and Receipt halves have moved out to [ScanStore] and
/// [ReceiptStore]. This still implements both so that one object can satisfy
/// all three while the callers narrow one at a time; the three methods below
/// them go when the last one has.
library;

import 'dart:typed_data';

import 'package:where_money_core/where_money_core.dart';

import 'receipt_store.dart';
import 'scan_store.dart';

abstract interface class LedgerStore implements ScanStore, ReceiptStore {
  /// The user's whole Ledger, newest first, updating as it changes.
  Stream<List<Expense>> ledger();

  Future<void> add(Expense expense);

  /// The user throwing an Expense away — a duplicate, or something refunded.
  /// The receipt photo beside it is deliberately left alone: nothing points at
  /// it any more, and deleting a row in the Ledger should not reach into the
  /// camera roll.
  Future<void> remove(String expenseId);

  /// Transitional, both: [ReceiptStore.bytesAt] and [ReceiptStore.hasAt] under
  /// their old names, until the two callers holding an Expense's path have
  /// moved onto the Receipt seam.
  Future<Uint8List?> receiptAt(String path);

  Future<bool> hasReceiptAt(String path);
}
