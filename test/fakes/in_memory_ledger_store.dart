import 'dart:async';
import 'dart:typed_data';

import 'package:where_money/data/ledger_store.dart';
import 'package:where_money_core/where_money_core.dart';

/// The LedgerStore seam's fake: one of the two things this project fakes.
class InMemoryLedgerStore implements LedgerStore {
  InMemoryLedgerStore([List<Expense> initial = const []])
    : _expenses = [...initial];

  final List<Expense> _expenses;
  final _changes = StreamController<List<Expense>>.broadcast();

  final _scans = <String, Scan>{};
  final _images = <String, Uint8List>{};
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
    _expenses.add(expense);
    _changes.add(_newestFirst);
  }

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
    _images[scan.id] = image;
    _inbox.add(_waiting);
    return scan;
  }

  @override
  Future<Uint8List?> imageFor(String scanId) async => _images[scanId];

  @override
  Future<void> abandon(String scanId) async {
    _scans.remove(scanId);
    _images.remove(scanId);
    _inbox.add(_waiting);
  }

  List<Expense> get contents => _newestFirst;

  List<Expense> get _newestFirst =>
      [..._expenses]..sort((a, b) => b.date.compareTo(a.date));

  List<Scan> get _waiting => _scans.values.waitingNewestFirst;
}
