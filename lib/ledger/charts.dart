/// The two charts a month reduces to. Both draw a single series in one hue
/// taken from the theme, so they follow light and dark rather than carrying
/// colours of their own, and both read magnitude by length — the one channel
/// that survives a colourblind reader, a grayscale print and a phone in the
/// sun. Nothing is said in colour alone: the breakdown prints every row's
/// amount, the trend prints the month it is showing, and the rest of the
/// trend's numbers are on the bars for a screen reader.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:where_money_core/where_money_core.dart';

import '../l10n/app_localizations.dart';
import '../settings/themes.dart';
import '../on_screen.dart';

const double _barThickness = 10;
const double _columnWidth = 20;
const double _plotHeight = 140;

/// Between a bar and the month under it.
const double _labelGap = 6;

/// How many lines a month label may take before it is ellipsised. Two,
/// because at large text sizes a three-letter month is wider than a sixth of
/// a phone and there is nowhere sideways for it to go.
const int _labelLines = 2;

/// The least a bar is worth drawing at. Direction C's 40px trend is this plus
/// [_labelGap] plus one line of label at ordinary text size, which is why the
/// header still measures exactly 40 there.
const double _minimumBar = 18;

/// What each Category cost this month, biggest first.
class CategoryBreakdown extends StatelessWidget {
  const CategoryBreakdown(this.rollup, {super.key});

  final Rollup rollup;

  @override
  Widget build(BuildContext context) {
    if (rollup.byCategory.isEmpty) return const SizedBox.shrink();

    final words = AppLocalizations.of(context);
    final colours = Theme.of(context).colorScheme;
    final largest = rollup.byCategory.first.amount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final category in rollup.byCategory)
          Semantics(
            label: words.chartsCategoryTotal(
              category.labelIn(words),
              asMoney(rollup.homeCurrency, category.amount),
              category.count,
            ),
            // Its own node, or the rows merge and a screen reader reads the
            // whole column as one utterance with no way to step through it.
            container: true,
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(category.labelIn(words))),
                      Text(
                        asMoney(rollup.homeCurrency, category.amount),
                        style: asFigures(DefaultTextStyle.of(context).style),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _Track(
                    label: category.labelIn(words),
                    fraction: category.amount / largest,
                    fill: colours.primary,
                    track: colours.surfaceContainerHighest,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({
    required this.label,
    required this.fraction,
    required this.fill,
    required this.track,
  });

  final String label;
  final double fraction;
  final Color fill;
  final Color track;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(_barThickness / 2),
    child: Container(
      height: _barThickness,
      color: track,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        // A category that cost almost nothing still gets a mark, so a row with
        // a number beside it is never a row with nothing beside it.
        widthFactor: fraction.clamp(0.02, 1.0),
        // The height has to be asked for. Aligning inside the track leaves the
        // fill loosely constrained, and a DecoratedBox with no child of its own
        // answers that by taking no height at all — which drew every bar
        // invisible while every number beside it stayed right.
        heightFactor: 1,
        child: DecoratedBox(
          key: ValueKey('category bar: $label'),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(_barThickness / 2),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The months leading up to this one, so a total has a direction to be read
/// against. The month on screen is the only one in the accent colour: the
/// others are context, and colouring them all would bury the point.
class MonthTrend extends StatelessWidget {
  const MonthTrend(
    this.months, {
    required this.showing,
    required this.onPicked,
    super.key,
  });

  final List<Rollup> months;

  /// The month the screen is on. The window can reach past it, so which month
  /// this trend is about has to be said rather than read off the end.
  final Rollup showing;

  /// What a tapped column means. A callback rather than an event because this
  /// file draws Rollups and knows nothing else — the screen that has a bloc
  /// decides what a tap is worth.
  final void Function(Rollup month) onPicked;

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The one month the reader came for gets its number; a number on every
        // bar would be read by nobody.
        Text(
          asMoney(showing.homeCurrency, showing.total),
          style: asFigures(theme.textTheme.titleSmall),
        ),
        const SizedBox(height: 8),
        MonthColumns(months, showing: showing, onPicked: onPicked),
      ],
    );
  }
}

/// The bars on their own. Pulled out of [MonthTrend] because the Ledger's
/// header draws the same trend without a number above it — the total is
/// already the headline there — and shorter, so it can sit above the list
/// rather than fill a screen.
class MonthColumns extends StatelessWidget {
  const MonthColumns(
    this.months, {
    required this.showing,
    required this.onPicked,
    this.height = _plotHeight,
    super.key,
  });

  final List<Rollup> months;

  /// The month the screen is on, and so the one column in the accent. Named
  /// rather than taken as the last of [months]: the Ledger's header windows
  /// its trend so there are months after the one on screen, which is what
  /// gives a reader who has stepped back a way forward again.
  final Rollup showing;

  final void Function(Rollup month) onPicked;

  /// The height the trend is drawn at where the labels fit in it — direction
  /// C's 40 above the Ledger's list, the plot's own 140 on the chart detail.
  /// A floor rather than the last word: see [build].
  final double height;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, space) {
      // The labels are measured rather than assumed, and the trend takes
      // whatever they turn out to need. At 200% text a month label wraps to
      // two lines inside a sixth of a phone, which is 30px more than the
      // Ledger's 40px trend has to give — and a Column cannot give a child
      // more room than it has, so the label was clipped and the bar above it
      // squeezed to nothing. This is the one control that changes month, so
      // it grows instead.
      final labels = _labelExtent(
        context,
        months,
        space.maxWidth / math.max(months.length, 1),
      );

      return SizedBox(
        height: math.max(height, _minimumBar + _labelGap + labels),
        child: _Columns(months, showing, onPicked),
      );
    },
  );
}

/// The tallest a month label lays out in [columnWidth], at the text size the
/// phone is set to. Measured against [_showingStyle] because that is the
/// heavier and more widely tracked of the two, and so the first to wrap.
double _labelExtent(
  BuildContext context,
  List<Rollup> months,
  double columnWidth,
) {
  final words = AppLocalizations.of(context);
  final style = _showingStyle(Theme.of(context));
  final scaler = MediaQuery.textScalerOf(context);
  var tallest = 0.0;

  for (final month in months) {
    final painter = TextPainter(
      text: TextSpan(text: _labelOf(month, words), style: style),
      textScaler: scaler,
      textDirection: Directionality.of(context),
      maxLines: _labelLines,
      ellipsis: '…',
    )..layout(maxWidth: columnWidth);
    tallest = math.max(tallest, painter.height);
    painter.dispose();
  }

  return tallest;
}

/// Upper case is typography, not wording — the message files hold the month
/// names as they are written, and this is a no-op in a language whose months
/// are not cased.
String _labelOf(Rollup month, AppLocalizations words) =>
    month.shortMonthLabel(words).toUpperCase();

/// The label of the month the screen is on. It carries the accent as well as
/// the bar, because a month nobody spent anything in draws a bar of no height
/// — so on the months where knowing where you are matters most, the bar alone
/// says nothing.
TextStyle? _showingStyle(ThemeData theme) => atItsWeight(
  theme.textTheme.labelSmall?.copyWith(
    color: theme.colorScheme.primary,
    fontWeight: FontWeight.w600,
  ),
);

TextStyle? _contextStyle(ThemeData theme) =>
    theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.6);

class _Columns extends StatelessWidget {
  const _Columns(this.months, this.showing, this.onPicked);

  final List<Rollup> months;
  final Rollup showing;
  final void Function(Rollup month) onPicked;

  @override
  Widget build(BuildContext context) {
    final tallest = months.map((r) => r.total).reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final month in months)
          Expanded(
            child: _MonthColumn(
              month,
              // A month is drawn against the tallest in the window rather than
              // its own total, or every column would be full height and the
              // trend would have no shape.
              fraction: tallest == 0
                  ? 0
                  : (month.total / tallest).clamp(0.0, 1.0),
              isShowing:
                  month.year == showing.year && month.month == showing.month,
              onTap: () => onPicked(month),
            ),
          ),
      ],
    );
  }
}

class _MonthColumn extends StatelessWidget {
  const _MonthColumn(
    this.month, {
    required this.fraction,
    required this.isShowing,
    required this.onTap,
  });

  final Rollup month;
  final double fraction;

  /// Whether this is the month the screen is on, which is the only one in the
  /// accent colour.
  final bool isShowing;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Semantics(
      label: words.chartsMonthTotal(
        month.monthLabel(words),
        asMoney(month.homeCurrency, month.total),
      ),
      container: true,
      excludeSemantics: true,
      button: true,
      // The gesture is on the InkWell below, but a screen reader never reaches
      // it: this node excludes its own subtree, so the action has to be
      // published here too or the column is a button that cannot be pressed.
      onTap: onTap,
      child: InkWell(
        // The whole column, label and all — a month that cost nothing draws no
        // bar, and a target you can only hit where there is ink is a target
        // that disappears exactly when the trend is most worth stepping into.
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        excludeFromSemantics: true,
        child: Column(
          children: [
            Expanded(
              child: FractionallySizedBox(
                heightFactor: fraction,
                alignment: Alignment.bottomCenter,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: _columnWidth,
                    decoration: BoxDecoration(
                      color: isShowing
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: _labelGap),
            Text(
              _labelOf(month, words),
              textAlign: TextAlign.center,
              // Held to what [_labelExtent] measured room for. Without these
              // a third line at some text size the trend was not sized for
              // would clip again.
              maxLines: _labelLines,
              overflow: TextOverflow.ellipsis,
              style: isShowing ? _showingStyle(theme) : _contextStyle(theme),
            ),
          ],
        ),
      ),
    );
  }
}
