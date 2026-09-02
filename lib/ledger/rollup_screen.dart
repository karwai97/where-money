import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../l10n/app_localizations.dart';
import '../on_screen.dart';
import 'charts.dart';
import 'ledger_bloc.dart';

/// A month of the Ledger as two charts: what it went on, and how it compares
/// to the months before it. Everything here is read from the Rollup the bloc
/// already computed — nothing is worked out twice, and nothing is written
/// anywhere.
class RollupScreen extends StatelessWidget {
  const RollupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);

    return BlocBuilder<LedgerBloc, LedgerState>(
      builder: (context, state) {
        if (state is! LedgerReady) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final rollup = state.rollup;
        final trend = state.trend;

        return Scaffold(
          appBar: AppBar(title: Text(rollup.monthLabel(words))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _Headline(rollup),
              _LeftOut([rollup]),
              const SizedBox(height: 24),
              _TheRecap(state.recap),
              const SizedBox(height: 24),
              _Heading(words.rollupByCategory),
              if (rollup.hasSpending)
                CategoryBreakdown(rollup)
              else
                Text(words.rollupNothingSpent(rollup.monthLabel(words))),
              if (trend.any((month) => month.hasSpending)) ...[
                const SizedBox(height: 32),
                _Heading(words.rollupMonthByMonth),
                MonthTrend(trend),
                // Every bar leaves out the same kind of spending the month
                // above does, so every bar has to say so too.
                _LeftOut(trend, acrossTheTrend: true),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// The one exhaustive switch from a [WhyNoRecap] to words, so adding a reason
/// without copy is a compile error rather than a blank line on the screen. The
/// same shape as `finding_copy.dart` and for the same reason (ADR-0007).
String _why(WhyNoRecap why, AppLocalizations words) => switch (why) {
  WhyNoRecap.refused => words.rollupRecapRefused,
  WhyNoRecap.nothingToSay => words.rollupRecapNothingToSay,
  WhyNoRecap.allowanceSpent => words.rollupRecapAllowanceSpent,
  WhyNoRecap.tokenRefused => words.rollupRecapTokenRefused,
  WhyNoRecap.outOfReach => words.rollupRecapOutOfReach,
  WhyNoRecap.modelUnavailable => words.rollupRecapModelUnavailable,
};

/// The month in words. It says nothing the charts below do not also say — it
/// is written from the same Rollup they are drawn from — so a month that could
/// not be written up costs the reader nothing but the words.
class _TheRecap extends StatelessWidget {
  const _TheRecap(this.recap);

  final RecapState recap;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(words.rollupRecapHeading, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          switch (recap) {
            RecapOnScreen(:final text) => Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
            RecapPending() => Row(
              children: [
                const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  words.rollupRecapPending,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            RecapTooFewExpenses(:final needed) => Text(
              words.rollupRecapTooFew(needed),
              style: theme.textTheme.bodyMedium,
            ),
            RecapUnavailable(:final why) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_why(why, words), style: theme.textTheme.bodyMedium),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () =>
                        context.read<LedgerBloc>().add(const RecapAskedAgain()),
                    child: Text(words.rollupRecapAskAgain),
                  ),
                ),
              ],
            ),
          },
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline(this.rollup);

  final Rollup rollup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          asMoney(rollup.homeCurrency, rollup.total),
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          _comparison(AppLocalizations.of(context)),
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  String _comparison(AppLocalizations words) {
    final previous = rollup.previousMonthLabel(words);
    final change = rollup.percentChange;

    if (change == null) return words.rollupNothingToCompare(previous);
    if (change.abs() < 0.5) return words.rollupAboutTheSame(previous);

    final percent = change.abs().round();
    return change > 0
        ? words.rollupMoreThan(percent, previous)
        : words.rollupLessThan(percent, previous);
  }
}

/// ADR-0006: an Expense in another currency is stored faithfully and left out
/// of the totals. Saying how many is what stops a total the user cannot
/// reconcile from looking like the whole month.
class _LeftOut extends StatelessWidget {
  const _LeftOut(this.months, {this.acrossTheTrend = false});

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

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}
