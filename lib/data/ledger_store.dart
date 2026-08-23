/// The boundary to persistence. Above this line an Expense is an Expense;
/// below it, and nowhere else, it is a Firestore document.
library;

import 'package:where_money_core/where_money_core.dart';

abstract interface class LedgerStore {
  /// The user's whole Ledger, newest first, updating as it changes.
  Stream<List<Expense>> ledger();

  Future<void> add(Expense expense);
}
