/// The three seams a signed-in user's data sits behind, named together because
/// all three are keyed by the uid: their Ledger is theirs, and so is the
/// directory their Scans and Receipts live in.
///
/// Two of the three are usually the same object — Scans and their Receipts are
/// one directory on the phone — and that is not worth hiding. What matters is
/// that a caller is handed the one seam it uses.
library;

import 'ledger_store.dart';
import 'receipt_store.dart';
import 'scan_store.dart';

typedef Stores = ({LedgerStore ledger, ScanStore scans, ReceiptStore receipts});
