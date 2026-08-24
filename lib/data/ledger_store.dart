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

  /// Every Scan the user has not yet Reviewed, newest first.
  Stream<List<Scan>> inbox();

  /// Writes the image and the Scan together and answers only once both are
  /// durable. Touches no network, so it works on a plane and cannot fail for
  /// any reason the user could have avoided.
  Future<Scan> capture(Uint8List image, {DateTime? at});

  /// The image as it was stored, or null if the Scan is gone.
  Future<Uint8List?> imageFor(String scanId);

  /// The user throwing a Scan away. The only thing that ever removes one.
  Future<void> abandon(String scanId);
}
