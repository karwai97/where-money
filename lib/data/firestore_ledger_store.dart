import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:where_money_core/where_money_core.dart';

import 'device_scan_store.dart';
import 'expense_document.dart';
import 'ledger_store.dart';

/// The only place in the app that knows Firestore's shape. Above it there are
/// Expenses; here there are documents, and the converter is the border.
///
/// The Scan half is handed straight to the device: receipt images never leave
/// the phone (ADR-0003), so a Scan has nowhere else it could live.
class FirestoreLedgerStore implements LedgerStore {
  FirestoreLedgerStore({
    required FirebaseFirestore firestore,
    required this.uid,
    required this.scans,
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
  final DeviceScanStore scans;
  final CollectionReference<Expense> _expenses;

  @override
  Stream<List<Expense>> ledger() => _expenses
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => [for (final doc in snapshot.docs) doc.data()]);

  @override
  Future<void> add(Expense expense) => _expenses.doc(expense.id).set(expense);

  @override
  Stream<List<Scan>> inbox() => scans.inbox();

  @override
  Future<Scan> capture(Uint8List image, {DateTime? at}) =>
      scans.capture(image, at: at);

  @override
  Future<void> put(Scan scan) => scans.put(scan);

  @override
  Future<Uint8List?> imageFor(String scanId) => scans.imageFor(scanId);

  @override
  Future<void> abandon(String scanId) => scans.abandon(scanId);
}
