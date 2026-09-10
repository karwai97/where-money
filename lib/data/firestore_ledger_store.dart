import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:where_money_core/where_money_core.dart';

import 'expense_document.dart';
import 'ledger_store.dart';

/// The only place in the app that knows Firestore's shape. Above it there are
/// Expenses; here there are documents, and the converter is the border.
class FirestoreLedgerStore implements LedgerStore {
  FirestoreLedgerStore({
    required FirebaseFirestore firestore,
    required this.uid,
  }) : _expenses = firestore
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

  @override
  Future<void> remove(String expenseId) => _expenses.doc(expenseId).delete();

  @override
  Future<void> eraseTheLedger() async {
    // A page at a time, so a long Ledger is neither held in memory to be
    // deleted nor pushed past the 500 writes a batch takes.
    while (true) {
      final page = await _expenses.limit(_perErasedBatch).get();
      if (page.docs.isEmpty) return;

      final batch = _expenses.firestore.batch();
      for (final document in page.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }

  static const _perErasedBatch = 200;
}
