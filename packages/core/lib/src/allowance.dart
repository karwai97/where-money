/// How much of a day's Scans the Worker says are gone.
///
/// A fact about the service rather than about the Ledger: the Worker counts,
/// the phone only remembers what it was last told. [limit] is the cap the
/// Worker enforces — the requested `Knobs.dailyCap` after the deployment's
/// ceiling clamps it — so it can be lower than the cap the app asked for.
///
/// Approximate by design. `worker/src/allowance.ts` says why, and nothing that
/// draws this should claim otherwise.
library;

class Allowance {
  const Allowance({
    required this.used,
    required this.limit,
    required this.resetsAt,
  });

  /// Scans spent today, including the one that carried this answer back.
  final int used;

  /// Scans a day, as enforced.
  final int limit;

  /// When the counter goes back to zero. The only clock that counts: the day
  /// rolls over in UTC, which is not midnight anywhere the app is read, so
  /// nothing works this out for itself.
  final DateTime resetsAt;

  /// How many Scans are spent at [now]. None once [resetsAt] has passed: an
  /// allowance whose day is over is not a stale figure to hide, it is a day
  /// with nothing spent in it yet.
  int usedAt(DateTime now) => resetsAt.isAfter(now) ? used : 0;

  /// How much of the day is gone at [now], as a fraction, never past one. The
  /// counter is approximate — two Scans at once read the same number and both
  /// go through — so the Worker can report more used than the limit, and a
  /// track filled past its end is not a thing to draw.
  double spentAt(DateTime now) =>
      limit <= 0 ? 1 : (usedAt(now) / limit).clamp(0, 1);

  @override
  bool operator ==(Object other) =>
      other is Allowance &&
      other.used == used &&
      other.limit == limit &&
      other.resetsAt == resetsAt;

  @override
  int get hashCode => Object.hash(used, limit, resetsAt);

  @override
  String toString() =>
      'Allowance(used: $used, limit: $limit, resetsAt: $resetsAt)';
}
