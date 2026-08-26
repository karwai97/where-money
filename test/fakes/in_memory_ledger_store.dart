import 'dart:async';
import 'dart:typed_data';

import 'package:where_money/data/ledger_store.dart';
import 'package:where_money/data/receipt_store.dart';
import 'package:where_money/data/scan_store.dart';
import 'package:where_money/data/stores.dart';
import 'package:where_money_core/where_money_core.dart';

/// All three data seams in one object: one of the two things this project
/// fakes. One rather than three because a Scan and its Receipt share a
/// directory on the real device too, and because a test that seeds a Ledger and
/// then photographs something wants both halves to agree.
class InMemoryLedgerStore implements LedgerStore, ScanStore, ReceiptStore {
  InMemoryLedgerStore([List<Expense> initial = const []])
    : _expenses = [...initial];

  final List<Expense> _expenses;
  final _changes = StreamController<List<Expense>>.broadcast();

  final _scans = <String, Scan>{};

  /// Keyed by path, the way the device store's files are named, so a receipt
  /// seeded here is reachable by exactly what an Expense records.
  final _receipts = <String, Uint8List>{};
  final _inbox = StreamController<List<Scan>>.broadcast();
  var _captured = 0;

  /// Set either of these to have the store refuse, standing in for a rules
  /// refusal or a dead network.
  Object? refuseReads;
  Object? refuseWrites;

  @override
  Stream<List<Expense>> ledger() async* {
    if (refuseReads case final failure?) throw failure;
    yield _newestFirst;
    yield* _changes.stream;
  }

  @override
  Future<void> add(Expense expense) async {
    if (refuseWrites case final failure?) throw failure;
    // Keyed by id, as Firestore is: one document per Expense, written over
    // rather than added beside.
    _expenses
      ..removeWhere((held) => held.id == expense.id)
      ..add(expense);
    _changes.add(_newestFirst);
  }

  @override
  Future<void> remove(String expenseId) async {
    if (refuseWrites case final failure?) throw failure;
    _expenses.removeWhere((held) => held.id == expenseId);
    _changes.add(_newestFirst);
  }

  @override
  Future<Uint8List?> bytesAt(String path) async => _receipts[path];

  @override
  Future<bool> hasAt(String path) async => _receipts.containsKey(path);

  /// This one object standing in for all three, for handing to the app.
  Stores get stores => (ledger: this, scans: this, receipts: this);

  /// A Receipt already on this phone, for a Ledger seeded without anyone
  /// having photographed anything.
  void keepReceipt(String path, Uint8List bytes) => _receipts[path] = bytes;

  @override
  Stream<List<Scan>> inbox() async* {
    yield _waiting;
    yield* _inbox.stream;
  }

  @override
  Future<Scan> capture(Uint8List image, {DateTime? at}) async {
    final scan = Scan.captured(
      id: 'scan-${++_captured}',
      at: at ?? DateTime.now(),
    );
    _scans[scan.id] = scan;
    _receipts[receiptPathFor(scan.id)] = image;
    _inbox.add(_waiting);
    return scan;
  }

  /// Mirrors the device store: a Scan is only written beside an image, so one
  /// abandoned mid-extraction stays abandoned.
  @override
  Future<void> put(Scan scan) async {
    if (!_receipts.containsKey(receiptPathFor(scan.id))) return;
    _scans[scan.id] = scan;
    _inbox.add(_waiting);
  }

  @override
  Future<Uint8List?> receiptFor(String scanId) async =>
      _receipts[receiptPathFor(scanId)];

  @override
  Future<void> abandon(String scanId) async {
    _scans.remove(scanId);
    _receipts.remove(receiptPathFor(scanId));
    _inbox.add(_waiting);
  }

  List<Expense> get contents => _newestFirst;

  List<Scan> get waiting => _waiting;

  List<Expense> get _newestFirst =>
      [..._expenses]..sort((a, b) => b.date.compareTo(a.date));

  List<Scan> get _waiting => _scans.values.waitingNewestFirst;
}
