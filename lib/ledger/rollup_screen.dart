import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

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
          appBar: AppBar(title: Text(rollup.monthLabel)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _Headline(rollup),
              _LeftOut([rollup]),
              const SizedBox(height: 24),
              _TheRecap(state.recap),
              const SizedBox(height: 24),
              const _Heading('By category'),
              if (rollup.hasSpending)
                CategoryBreakdown(rollup)
              else
                Text('Nothing spent in ${rollup.monthLabel}.'),
              if (trend.any((month) => month.hasSpending)) ...[
                const SizedBox(height: 32),
                const _Heading('Month by month'),
                MonthTrend(trend),
                // Every bar leaves out the same kind of spending the month
                // above does, so every bar has to say so too.
                _LeftOut(trend, across: 'these months'),
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
          Text('Where your money went', style: theme.textTheme.titleMedium),
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
                Text('Reading the month.', style: theme.textTheme.bodyMedium),
              ],
            ),
            RecapTooFewExpenses(:final needed) => Text(
              'A month needs $needed Expenses before there is anything worth '
              'writing up. The charts work either way.',
              style: theme.textTheme.bodyMedium,
            ),
            RecapUnavailable(:final why) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(why, style: theme.textTheme.bodyMedium),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () =>
                        context.read<LedgerBloc>().add(const RecapAskedAgain()),
                    child: const Text('Ask again'),
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
        Text(_comparison, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  String get _comparison {
    final change = rollup.percentChange;
    if (change == null) {
      return 'Nothing was spent in ${rollup.previousMonthLabel} to compare '
          'against.';
    }
    if (change.abs() < 0.5) {
      return 'About the same as ${rollup.previousMonthLabel}.';
    }
    final direction = change > 0 ? 'more' : 'less';
    return '${change.abs().round()}% $direction than '
        '${rollup.previousMonthLabel}.';
  }
}

/// ADR-0006: an Expense in another currency is stored faithfully and left out
/// of the totals. Saying how many is what stops a total the user cannot
/// reconcile from looking like the whole month.
class _LeftOut extends StatelessWidget {
  const _LeftOut(this.months, {this.across = 'this month'});

  final List<Rollup> months;
  final String across;

  @override
  Widget build(BuildContext context) {
    final count = months.fold<int>(0, (sum, m) => sum + m.excludedCount);
    if (count == 0) return const SizedBox.shrink();

    final currencies =
        (months.expand((m) => m.excludedCurrencies).toSet().toList()..sort())
            .join(', ');

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        '${asExpenses(count)} in $currencies, spent $across, '
        '${count == 1 ? 'is' : 'are'} not in these totals.',
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
