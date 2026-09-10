/// The boundary to a Scan's own storage. Above this line a Scan is a Scan;
/// below it, and nowhere else, it is a JSON record beside an image on this
/// phone.
///
/// Nothing here touches the network. Capture has to work in a basement
/// (ADR-0004), and the image it writes never leaves the device it was taken on
/// (ADR-0003), so there is nowhere else a Scan could live.
library;

import 'dart:typed_data';

import 'package:where_money_core/where_money_core.dart';

abstract interface class ScanStore {
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

  /// The user throwing a Scan away. The only thing that ever removes one.
  Future<void> abandon(String scanId);

  /// The Receipt this Scan was read from, or null if the Scan is gone.
  ///
  /// Keyed by the Scan rather than by a path, because that is the question its
  /// callers have: they are holding a Scan, not an Expense. That this answers
  /// the same file as a ReceiptStore read of `receiptPathFor` is a fact about
  /// the directory, and it stays down there.
  Future<Uint8List?> receiptFor(String scanId);

  /// Every Scan and every Receipt on this phone, gone. The counterpart of
  /// [abandon] for a user leaving rather than for one photo they did not
  /// want, and here for the same reason [abandon] is: an image lives in a
  /// directory this store owns, and nothing above it can name a file.
  Future<void> eraseEveryScan();
}
