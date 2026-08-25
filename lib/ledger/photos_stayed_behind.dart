import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../data/device_preferences.dart';
import '../data/ledger_store.dart';

/// Signing in on a new phone brings back every Expense and none of the receipt
/// photos, because images never leave the device they were taken on
/// (ADR-0003). That is the design working, but it reads as loss, so the app
/// says it once rather than leaving the user to notice.
///
/// True while there is something to say.
class PhotosStayedBehind extends Cubit<bool> {
  PhotosStayedBehind(this._store, this._preferences, this._uid) : super(false);

  final LedgerStore _store;
  final DevicePreferences _preferences;
  final String _uid;

  var _looked = false;

  Future<void> considered(List<Expense> expenses) async {
    final paths = [for (final expense in expenses) ?expense.receiptPath];

    if (paths.isEmpty || state || _looked) return;
    _looked = true;

    if (await _preferences.hasExplainedMissingPhotos(_uid)) return;
    // Stops at the first photo found, so the ordinary case costs one look and
    // only a Ledger that really has lost all of them is walked through.
    for (final path in paths) {
      if (await _store.hasReceiptAt(path)) return;
    }

    emit(true);
  }

  Future<void> acknowledged() async {
    await _preferences.rememberExplainingMissingPhotos(_uid);
    emit(false);
  }
}
