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

  /// The whole Ledger, gone, because the user it belongs to is going with it
  /// (ADR-0010). Not [remove] in a loop: a Ledger is deleted in as few
  /// writes as the store can manage, and only this side of the boundary
  /// knows how many that is.
  ///
  /// All or nothing from the caller's side. If this throws, the Ledger is
  /// still there and the user is still its owner — which is the only state
  /// they can try again from.
  Future<void> eraseTheLedger();
}
