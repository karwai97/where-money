/// The boundary to persistence. Above this line an Expense is an Expense and a
/// Scan is a Scan; below it, and nowhere else, one is a Firestore document and
/// the other is a file on disk.
library;

import 'dart:typed_data';

import 'package:where_money_core/where_money_core.dart';

abstract interface class LedgerStore {
  /// The user's whole Ledger, newest first, updating as it changes.
  Stream<List<Expense>> ledger();

  Future<void> add(Expense expense);

  /// The user throwing an Expense away — a duplicate, or something refunded.
  /// The receipt photo beside it is deliberately left alone: nothing points at
  /// it any more, and deleting a row in the Ledger should not reach into the
  /// camera roll.
  Future<void> remove(String expenseId);

  /// The receipt an Expense was read from, by the path recorded on it, or null
  /// when the photo is not on this device. Images never leave the phone they
  /// were taken on (ADR-0003), so a Ledger restored somewhere else has none of
  /// them and that is not a failure.
  Future<Uint8List?> receiptAt(String path);

  /// Every Scan the user has not yet Reviewed, newest first.
  Stream<List<Scan>> inbox();

  /// Writes the image and the Scan together and answers only once both are
  /// durable. Touches no network, so it works on a plane and cannot fail for
  /// any reason the user could have avoided.
  Future<Scan> capture(Uint8List image, {DateTime? at});

  /// Moves a Scan on — into `extracting`, into `extracted` with what the
  /// Model read, or into `committed` once it is an Expense. A Scan the user
  /// has abandoned stays gone.
  Future<void> put(Scan scan);

  /// The image as it was stored, or null if the Scan is gone.
  Future<Uint8List?> imageFor(String scanId);

  /// The user throwing a Scan away. The only thing that ever removes one.
  Future<void> abandon(String scanId);
}

/// Where a Scan's receipt lives, as the Expense records it. Named here rather
/// than in the device store so that an Expense can carry the path without
/// anything above this boundary knowing there are files at all.
String receiptPathFor(String scanId) => '$scanId.jpg';
