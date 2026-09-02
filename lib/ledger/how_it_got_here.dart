/// Which Expenses the app read and which the user typed. One mark, so the list
/// and the Expense itself cannot start telling the user different things about
/// how much of the Ledger the app produced.
library;

import 'package:flutter/material.dart';
import 'package:where_money_core/where_money_core.dart';

import '../l10n/app_localizations.dart';
import '../on_screen.dart';

class HowItGotHere extends StatelessWidget {
  const HowItGotHere(this.source, {super.key, this.size});

  final ExpenseSource source;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final scanned = source == ExpenseSource.scanned;

    return Tooltip(
      message: source.labelIn(AppLocalizations.of(context)),
      child: Icon(scanned ? Icons.receipt_long : Icons.edit_note, size: size),
    );
  }
}
