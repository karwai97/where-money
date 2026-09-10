/// Everything a uid owns, deleted: the Expenses, the Scans and Receipts on
/// this phone, what the phone remembers about the account, and the account
/// itself.
///
/// Named for the act rather than for the caller, and it does not know what a
/// guest is. Today only a guest is ever erased — an account holder signs out
/// and their Ledger waits for them (ADR-0010) — but nothing here depends on
/// that, and a uid is a uid.
///
/// It deletes nothing itself. Each seam deletes its own: the repository is
/// the only thing that names a Firestore document (ADR-0002) and the device
/// store is the only thing that names a file, and both rules are checked
/// mechanically by the suite. What lives here is the order, which is the part
/// that can go wrong.
library;

import '../session/sign_in_gateway.dart';
import 'device_preferences.dart';
import 'stores.dart';

/// Built per uid, the way the Stores are, because everything it reaches is
/// keyed by one.
typedef ErasesFor = ErasingALedger Function(String uid);

abstract interface class ErasingALedger {
  /// In one order, and the order is the whole of it. The account goes last:
  /// the token that authorises every step before it dies with the account, so
  /// deleting it first would leave the Expenses behind and nobody able to
  /// reach them.
  ///
  /// The Expenses are all-or-nothing. If the Ledger refuses — no network,
  /// most likely — this throws and the user stays signed in, because signing
  /// them out over a failed delete would break the promise the dialog made
  /// *and* take away the only identity that could try again. What is left on
  /// the phone is best effort by comparison: local, invisible, and cleaned up
  /// by the next uid or by uninstalling.
  Future<void> erase();
}

class ErasingWhatAUidOwns implements ErasingALedger {
  ErasingWhatAUidOwns({
    required this.uid,
    required this.stores,
    required this.preferences,
    required this.identity,
  });

  final String uid;
  final Stores stores;
  final DevicePreferences preferences;
  final SignInGateway identity;

  @override
  Future<void> erase() async {
    await preferences.rememberErasureUnderWay(uid);

    await stores.ledger.eraseTheLedger();

    // From here on, failures are swallowed. Everything above was the promise;
    // everything below is tidying, and a phone that refuses to delete a
    // directory should not strand the user in a Ledger they asked to be rid
    // of.
    try {
      await stores.scans.eraseEveryScan();
    } catch (_) {}
    try {
      await preferences.forget(uid);
    } catch (_) {}

    // The account goes before the record of the erasure is cleared, not
    // after. Killed in between, the next launch finds a uid nobody can sign
    // into and a record naming it, and clears the record — which is the
    // truth. Cleared first, the same interruption would leave a live account
    // with an empty Ledger and nothing saying it was meant to be gone.
    await identity.deleteAccount();
    await preferences.forgetErasureUnderWay();
  }
}
