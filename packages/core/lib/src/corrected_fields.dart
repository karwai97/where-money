/// The Corrected Fields tally: how often Review had to change what the Model
/// read. It is the project's only real measure of extraction accuracy, and the
/// thing a change of model tier is judged by.
library;

import 'expense.dart';

class CorrectedFields {
  const CorrectedFields({
    required this.scanned,
    required this.clean,
    required this.byField,
  });

  /// How many Expenses this was measured over.
  final int scanned;

  /// How many of them the user changed nothing on.
  final int clean;

  /// Field name to the number of those it was corrected on, most corrected
  /// first — a tier is changed because one field keeps being misread, so the
  /// field that keeps being misread is the thing to read.
  final Map<String, int> byField;

  /// Expenses typed by hand are left out. One of those records a correction
  /// for every field the user filled in, against an Extraction that never
  /// existed, and counting them would put the number wherever the user's
  /// typing habits are rather than where the Model's accuracy is.
  factory CorrectedFields.across(Iterable<Expense> ledger) {
    final scanned = ledger.where((e) => e.source == ExpenseSource.scanned);

    final counts = <String, int>{};
    for (final expense in scanned) {
      for (final field in expense.correctedFields.toSet()) {
        counts[field] = (counts[field] ?? 0) + 1;
      }
    }

    return CorrectedFields(
      scanned: scanned.length,
      clean: scanned.where((e) => !e.wasCorrected).length,
      byField: {
        for (final entry
            in counts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
          entry.key: entry.value,
      },
    );
  }
}
