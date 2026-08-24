/// One attempt to turn a photographed receipt into data. A Scan exists the
/// moment the shutter fires and is durable from then on; producing an
/// Extraction happens afterwards and may be pending, failed, or done.
library;

import 'extraction.dart';

/// The lifecycle from ADR-0004. `captured` requires no network and cannot
/// fail; everything after it can, which is why each failure is a state here
/// rather than a dialog somewhere else.
enum ScanState {
  captured,
  extracting,
  extracted,
  failed,
  capped,
  notReceipt,
  committed,
}

class Scan {
  final String id;
  final DateTime capturedAt;
  final ScanState state;

  /// What the Model read, once it has read anything.
  final Extraction? extraction;

  const Scan({
    required this.id,
    required this.capturedAt,
    required this.state,
    this.extraction,
  });

  factory Scan.captured({required String id, required DateTime at}) =>
      Scan(id: id, capturedAt: at, state: ScanState.captured);

  /// In the Inbox until the user has Reviewed it into an Expense. A Scan the
  /// user abandoned is gone rather than in a state, so there is nothing here
  /// for it.
  bool get inInbox => state != ScanState.committed;

  Scan movedTo(ScanState state, {Extraction? extraction}) => Scan(
    id: id,
    capturedAt: capturedAt,
    state: state,
    extraction: extraction ?? this.extraction,
  );
}

extension InboxOrder on Iterable<Scan> {
  /// What the Inbox is: everything still waiting on the user, newest first.
  /// Shared so a fake and a real store cannot disagree about what waiting
  /// means.
  List<Scan> get waitingNewestFirst => [
    for (final scan in this)
      if (scan.inInbox) scan,
  ]..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
}
