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

/// Why a Scan has no Extraction. The state says which line the Inbox shows it
/// on; this says which words go on that line, because "the Model refused" and
/// "there was no signal" are not the same news and only one of them is worth
/// trying again on its own.
enum ScanFailure {
  /// The Model declined: a refusal block, arriving with a 200 like any other
  /// answer.
  refused,

  /// The call succeeded and said nothing at all, usually because reasoning
  /// consumed the whole output budget.
  saidNothing,

  /// Text came back that was not the JSON the schema promised.
  notLegible,

  /// Nothing got through from this phone. The one failure that answers to
  /// waiting.
  outOfReach,

  /// Something got through and the far end could not do it — the Model was
  /// down, or the Worker could not check who was calling. Not the same news as
  /// having no signal, and not worth going round on by itself: the attempt has
  /// already been counted against the day's allowance.
  modelUnavailable,

  /// The Worker would not take the token, so signing in again is the only
  /// thing that helps.
  tokenRefused,

  /// The Worker would not take the image. The same bytes will never work.
  imageNotAccepted;

  /// Trying the same bytes again only makes sense when the Model never saw
  /// them. Everything else here needs the user, or a different photograph.
  bool get triesAgainByItself => this == outOfReach;
}

class Scan {
  final String id;
  final DateTime capturedAt;
  final ScanState state;

  /// What the Model read, once it has read anything.
  final Extraction? extraction;

  /// Set only while [state] is `failed`.
  final ScanFailure? failure;

  /// Set only while [state] is `capped`, and null when the Worker did not say.
  final DateTime? allowanceResetsAt;

  const Scan({
    required this.id,
    required this.capturedAt,
    required this.state,
    this.extraction,
    this.failure,
    this.allowanceResetsAt,
  });

  factory Scan.captured({required String id, required DateTime at}) =>
      Scan(id: id, capturedAt: at, state: ScanState.captured);

  /// In the Inbox until the user has Reviewed it into an Expense. A Scan the
  /// user abandoned is gone rather than in a state, so there is nothing here
  /// for it.
  bool get inInbox => state != ScanState.committed;

  /// A Scan the Model has not read yet. Reading one that has already been read
  /// would spend the allowance to overwrite an Extraction the user is about to
  /// Review.
  bool get canBeReadAgain =>
      state == ScanState.failed || state == ScanState.capped;

  /// The Extraction survives the move; the failure does not. What went wrong
  /// last time describes where the Scan is now, so a Scan going round again
  /// carries none of it.
  Scan movedTo(
    ScanState state, {
    Extraction? extraction,
    ScanFailure? failure,
    DateTime? allowanceResetsAt,
  }) => Scan(
    id: id,
    capturedAt: capturedAt,
    state: state,
    extraction: extraction ?? this.extraction,
    failure: failure,
    allowanceResetsAt: allowanceResetsAt,
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
