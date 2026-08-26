/// The boundary to the Ledger's persistence. Above this line an Expense is an
/// Expense; below it, and nowhere else, it is a Firestore document.
library;

import 'package:where_money_core/where_money_core.dart';

abstract interface class LedgerStore {
  /// The user's whole Ledger, newest first, updating as it changes.
  Stream<List<Expense>> ledger();

  Future<void> add(Expense expense);

  /// The user throwing an Expense away — a duplicate, or something refunded.
  /// The Receipt beside it is deliberately left alone: nothing points at it any
  /// more, and deleting a row in the Ledger should not reach into the camera
  /// roll.
  Future<void> remove(String expenseId);
}
