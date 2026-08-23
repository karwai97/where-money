import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:where_money_core/where_money_core.dart';

import 'expense_document.dart';
import 'ledger_store.dart';

/// The only place in the app that knows Firestore's shape. Above it there are
/// Expenses; here there are documents, and the converter is the border.
class FirestoreLedgerStore implements LedgerStore {
  FirestoreLedgerStore({required FirebaseFirestore firestore, required this.uid})
    : _expenses = firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .withConverter<Expense>(
            fromFirestore: (snapshot, _) =>
                expenseFromDocument(snapshot.id, snapshot.data() ?? const {}),
            toFirestore: (expense, _) => expenseToDocument(expense),
          );

  final String uid;
  final CollectionReference<Expense> _expenses;

  @override
  Stream<List<Expense>> ledger() => _expenses
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => [for (final doc in snapshot.docs) doc.data()]);

  @override
  Future<void> add(Expense expense) => _expenses.doc(expense.id).set(expense);
}
