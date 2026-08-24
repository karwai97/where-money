/// The translation between a Scan and the JSON file that holds it on disk.
///
/// The Extraction inside travels in the Model's own wire shape, which it
/// already has and which nothing here has any reason to restate.
library;

import 'package:where_money_core/where_money_core.dart';

Map<String, Object?> scanToRecord(Scan scan) => {
  'capturedAt': scan.capturedAt.toIso8601String(),
  'state': scan.state.name,
  'extraction': scan.extraction?.toJson(),
};

/// Throws [FormatException] if the record has no legible capture time. A Scan
/// whose state is unreadable falls back to `captured`, which is the state that
/// loses nothing: the worst case is a receipt read a second time.
Scan scanFromRecord(String id, Map<String, Object?> record) {
  final capturedAt = DateTime.tryParse(record['capturedAt'] as String? ?? '');
  if (capturedAt == null) {
    throw FormatException('Scan $id has no capture time');
  }

  final extraction = record['extraction'];
  return Scan(
    id: id,
    capturedAt: capturedAt,
    state: ScanState.values.firstWhere(
      (state) => state.name == record['state'],
      orElse: () => ScanState.captured,
    ),
    extraction: extraction is Map<String, dynamic>
        ? Extraction.fromJson(extraction)
        : null,
  );
}
