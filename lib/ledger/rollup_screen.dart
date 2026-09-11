import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../l10n/app_localizations.dart';
import '../on_screen.dart';
import '../settings/themes.dart';
import 'charts.dart';
import 'ledger_bloc.dart';
import 'left_out.dart';
import 'recap_copy.dart';

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
        // Nothing is aggregated until the app knows what this Ledger's money
        // is, and bars of zero would say the month was empty rather than that
        // there is no axis to draw them on yet (ADR-0009).
        if (state is LedgerWithoutHomeCurrency) {
          return Scaffold(
            appBar: AppBar(title: Text(words.rollupNoHomeCurrencyTitle)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  words.rollupNoHomeCurrency,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (state is! LedgerReady) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                semanticsLabel: words.rollupLoading,
              ),
            ),
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
              LeftOut([rollup]),
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
                MonthTrend(
                  trend,
                  showing: rollup,
                  onPicked: (month) => context.read<LedgerBloc>().add(
                    MonthPicked(month.year, month.month),
                  ),
                ),
                // Every bar leaves out the same kind of spending the month
                // above does, so every bar has to say so too.
                LeftOut(trend, acrossTheTrend: true),
              ],
            ],
          ),
        );
      },
    );
  }
}

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
                // Wordless on purpose, unlike every other spinner in the app:
                // the sentence beside it already says what it means, and a
                // label here would have a screen reader read that twice.
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
                Text(
                  whyThereIsNoRecap(words, why),
                  style: theme.textTheme.bodyMedium,
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
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
          style: asFigures(theme.textTheme.headlineMedium),
        ),
        const SizedBox(height: 4),
        Text(
          rollup.comparedWithPreviousMonth(AppLocalizations.of(context)),
          style: theme.textTheme.bodyMedium,
        ),
      ],
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
