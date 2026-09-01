/// The boundary to the Receipts on this phone. Above this line a Receipt is
/// bytes; below it, and nowhere else, it is a file.
///
/// Read-only on purpose. The only thing that ever writes a Receipt is a Scan
/// being captured, which belongs to ScanStore, and leaving the write there is
/// what stops a Receipt existing with no Scan behind it.
library;

import 'dart:typed_data';

abstract interface class ReceiptStore {
  /// The Receipt at [path], or null when it is not on this device. Images never
  /// leave the phone they were taken on (ADR-0003), so a Ledger restored
  /// somewhere else has none of them and that is not a failure.
  Future<Uint8List?> bytesAt(String path);

  /// Whether that Receipt is here, without reading it. A Ledger restored onto a
  /// new phone has none of them, and finding that out should not cost a pass
  /// over every image on disk.
  Future<bool> hasAt(String path);
}

/// Where a Scan's Receipt lives, as an Expense records it.
///
/// A plain function rather than a member of [ReceiptStore]: an Expense is
/// stamped with this on commit and read back out of a Firestore document, and
/// neither of those places has a store in scope or any business acquiring one.
String receiptPathFor(String scanId) => '$scanId.jpg';
