/// ADR-0006: an Expense in another currency is stored faithfully and left out
/// of the totals. Saying how many is what stops a total the user cannot
/// reconcile from looking like the whole month.
///
/// Its own file because two screens owe the reader this sentence — the Ledger,
/// under a month's list, and the chart detail, under both the month and the
/// trend — and a total that admits what it leaves out on one screen but not
/// the other is worse than one that never admitted it.
library;

import 'package:flutter/material.dart';
import 'package:where_money_core/where_money_core.dart';

import '../l10n/app_localizations.dart';

class LeftOut extends StatelessWidget {
  const LeftOut(this.months, {this.acrossTheTrend = false, super.key});

  final List<Rollup> months;

  /// Whether this is speaking for the trend rather than the month on screen.
  /// A flag rather than the words themselves: "this month" and "these months"
  /// sit in different places in different languages, so each is a whole
  /// message of its own.
  final bool acrossTheTrend;

  @override
  Widget build(BuildContext context) {
    final count = months.fold<int>(0, (sum, m) => sum + m.excludedCount);
    if (count == 0) return const SizedBox.shrink();

    final words = AppLocalizations.of(context);
    final currencies =
        (months.expand((m) => m.excludedCurrencies).toSet().toList()..sort())
            .join(', ');

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        acrossTheTrend
            ? words.rollupLeftOutTheseMonths(count, currencies)
            : words.rollupLeftOutThisMonth(count, currencies),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
