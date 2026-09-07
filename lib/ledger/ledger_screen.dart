import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../data/receipt_store.dart';
import '../l10n/app_localizations.dart';
import '../on_screen.dart';
import '../review/review_bloc.dart';
import '../review/review_screen.dart';
import '../scan/inbox_bloc.dart';
import '../scan/inbox_screen.dart';
import '../scan/photographer.dart';
import '../settings/settings_screen.dart';
import 'expense_screen.dart';
import 'how_it_got_here.dart';
import 'ledger_bloc.dart';
import 'left_out.dart';
import 'month_header.dart';
import 'photos_stayed_behind.dart';
import 'rollup_screen.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key, required this.photograph});

  final Photographer photograph;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);

    return _SaysThePhotosStayedBehind(
      child: Scaffold(
        appBar: AppBar(
          // The one title in the app set as a tracked upper case mark rather
          // than a heading — upper case here is typography, not wording, which
          // is why the message files hold it in sentence case.
          title: Text(
            words.ledgerTitle.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.8,
            ),
          ),
          actions: [
            Builder(builder: _chartsAction),
            Builder(builder: _inboxAction),
            Builder(builder: _settingsAction),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final colours = Theme.of(context).colorScheme;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Deliberately not accent-filled, unlike the camera below it.
                // Photographing a receipt is what this app is for; typing one in
                // is the way round it, and two filled buttons in a corner make
                // the reader choose between them.
                FloatingActionButton.small(
                  heroTag: 'manual',
                  tooltip: words.ledgerAddByHand,
                  backgroundColor: colours.surfaceContainer,
                  foregroundColor: colours.primary,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: colours.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onPressed: () => _addByHand(context),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'photograph',
                  tooltip: words.ledgerPhotograph,
                  onPressed: () => _photographAReceipt(context),
                  child: const Icon(Icons.photo_camera),
                ),
              ],
            );
          },
        ),
        body: BlocBuilder<LedgerBloc, LedgerState>(
          builder: (context, state) => switch (state) {
            LedgerLoading() => Center(
              child: CircularProgressIndicator(
                semanticsLabel: words.ledgerLoading,
              ),
            ),
            LedgerUnavailable(:final reason) => _Message(
              words.ledgerUnreadable,
              detail: reason,
            ),
            // No header: there is no Rollup to total, name a month with or
            // draw a trend from until the app knows what this Ledger's money
            // is. Ordinarily this is the empty Ledger a new user opens; it
            // holds Expenses only in the moment before the first one has been
            // learned from.
            LedgerWithoutHomeCurrency(expenses: []) => _Message(
              words.ledgerEmpty,
            ),
            LedgerWithoutHomeCurrency(:final expenses) => _Expenses(expenses),
            LedgerReady() => Column(
              children: [
                MonthHeader(
                  state.rollup,
                  state.trend,
                  onMonthPicked: (month) => context.read<LedgerBloc>().add(
                    MonthPicked(month.year, month.month),
                  ),
                ),
                Expanded(
                  child: switch (state) {
                    LedgerReady(expenses: []) => _Message(words.ledgerEmpty),
                    LedgerReady(inMonth: []) => _Message(
                      words.ledgerNothingInMonth(
                        state.rollup.monthLabel(words),
                      ),
                    ),
                    LedgerReady(:final inMonth) => _Expenses(
                      inMonth,
                      homeCurrency: state.rollup.homeCurrency,
                      months: [state.rollup],
                    ),
                  },
                ),
              ],
            ),
          },
        ),
      ),
    );
  }

  Widget _settingsAction(BuildContext context) => IconButton(
    // The screen it opens names itself the same thing, so it is one message.
    tooltip: AppLocalizations.of(context).settingsTitle,
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
  );

  void _addByHand(BuildContext context) {
    context.read<ReviewBloc>().add(const ManualExpenseStarted());
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ReviewScreen()));
  }

  Widget _chartsAction(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).ledgerCharts,
    icon: const Icon(Icons.bar_chart_outlined),
    onPressed: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const RollupScreen())),
  );

  /// The count belongs where the user already is, so Scans cannot quietly pile
  /// up in a screen nobody opens.
  Widget _inboxAction(BuildContext context) {
    final words = AppLocalizations.of(context);
    final colours = Theme.of(context).colorScheme;
    final state = context.watch<InboxBloc>().state;
    final waiting = state is InboxReady ? state.scans.length : 0;

    return IconButton(
      tooltip: waiting == 0
          ? words.ledgerInbox
          : words.ledgerInboxWaiting(waiting),
      icon: Badge(
        isLabelVisible: waiting > 0,
        // Scans waiting are a count, not a fault, and Material's badge is the
        // error red. The design fills it with the accent — and with the ink
        // measured against that accent rather than the white it sketched,
        // which the dark violet cannot carry.
        backgroundColor: colours.primary,
        textColor: colours.onPrimary,
        label: Text('$waiting'),
        child: const Icon(Icons.inbox_outlined),
      ),
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const InboxScreen())),
    );
  }

  Future<void> _photographAReceipt(BuildContext context) async {
    final inbox = context.read<InboxBloc>();
    final words = AppLocalizations.of(context);
    final from = await showModalBottomSheet<PhotoSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text(words.ledgerTakeAPhoto),
              onTap: () => Navigator.of(context).pop(PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(words.ledgerChooseFromGallery),
              onTap: () => Navigator.of(context).pop(PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (from == null) return;

    final taken = await photograph(from);
    if (taken != null) inbox.add(ScanCaptured(taken));
  }
}

/// The width the source mark is given, and the gap after it. Named because
/// the column heads have to clear exactly the same space.
const double _markWidth = 20;
const double _gutter = 12;

/// The list under the header, at direction C's density: 52px rows, the
/// merchant over when and what it was for, and the amount kept in its own
/// column so a month can be read down the figures.
class _Expenses extends StatelessWidget {
  const _Expenses(this.expenses, {this.homeCurrency, this.months = const []});

  final List<Expense> expenses;

  /// The axis the month is aggregated on, or null before the app has learned
  /// one — in which case no row is foreign, because there is nothing yet for
  /// a row to be foreign to (ADR-0009).
  final String? homeCurrency;

  /// The months the notice under the list speaks for. Empty when there is no
  /// Rollup to have excluded anything.
  final List<Rollup> months;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const _ColumnHeads(),
      Expanded(
        child: ListView.builder(
          // One past the end: what the totals leave out belongs under the
          // last row, not pinned below the scroll where it would sit on
          // screen with nothing above it to explain.
          itemCount: expenses.length + 1,
          itemBuilder: (context, index) => index == expenses.length
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LeftOut(months),
                )
              : _ExpenseRow(expenses[index], homeCurrency: homeCurrency),
        ),
      ),
    ],
  );
}

/// What the two columns are, said once above the list, so an amount does not
/// have to carry its own label on every row.
class _ColumnHeads extends StatelessWidget {
  const _ColumnHeads();

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colours = theme.colorScheme;

    final style = theme.textTheme.labelSmall?.copyWith(
      color: colours.outline,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.4,
    );

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colours.outlineVariant)),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          // Clears the mark in the rows below, so each head sits over the
          // column it names.
          const SizedBox(width: _markWidth + _gutter),
          // Upper case here is typography, not wording, which is why the
          // message files hold these in sentence case. It is a no-op in
          // Chinese, where the heads read as written.
          Expanded(
            child: Text(words.ledgerColumnMerchant.toUpperCase(), style: style),
          ),
          Text(words.ledgerColumnAmount.toUpperCase(), style: style),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow(this.expense, {this.homeCurrency});

  final Expense expense;
  final String? homeCurrency;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colours = theme.colorScheme;

    return InkWell(
      onTap: () => _open(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colours.outlineVariant)),
        ),
        child: ConstrainedBox(
          // A minimum rather than a fixed height: 52 is the density the
          // design asks for, and a reader who has turned text size up gets a
          // taller row instead of a clipped one.
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: _markWidth,
                  // How much of this Ledger the app produced, readable down
                  // the column rather than one Expense at a time. Dimmer than
                  // the merchant beside it: it is there to be scanned.
                  child: IconTheme.merge(
                    data: IconThemeData(color: colours.outline),
                    child: HowItGotHere(expense.source, size: 15),
                  ),
                ),
                const SizedBox(width: _gutter),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        merchantLabel(words, expense.merchant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dayAndCategory(words, expense.date, expense.category),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: _gutter),
                _Amount(expense, homeCurrency: homeCurrency),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      // The route's own context, not this row's. The Ledger is a live stream,
      // so the row can be gone while the Expense it opened is still on top,
      // and a rebuild of the route would then be reading a dead element.
      builder: (context) => ExpenseScreen(
        expenseId: expense.id,
        receipts: context.read<ReceiptStore>(),
      ),
    ),
  );
}

/// The ISO code split off the figure: smaller, and set on the baseline beside
/// it, so a column of amounts lines up on its digits rather than on however
/// wide each code happens to be.
///
/// An Expense in anything but the Home Currency is the one row whose code is
/// in the accent, because that code is the reason the row is not in the total
/// above it (ADR-0006). The code still says which currency it is, so nothing
/// here is said in colour alone.
class _Amount extends StatelessWidget {
  const _Amount(this.expense, {this.homeCurrency});

  final Expense expense;
  final String? homeCurrency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colours = theme.colorScheme;
    final counted = homeCurrency == null || expense.currency == homeCurrency;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          expense.currency,
          style: theme.textTheme.labelSmall?.copyWith(
            color: counted ? colours.outline : colours.primary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          asAmount(expense.total),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: counted ? colours.onSurface : colours.onSurfaceVariant,
            // A column of figures that does not jog when a 1 follows an 8.
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.detail});

  final String text;

  /// The underlying failure, kept small and below the sentence — legible to
  /// whoever is holding the phone, not the whole message.
  final String? detail;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          if (detail != null) ...[
            const SizedBox(height: 12),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    ),
  );
}

/// Watches the Ledger arrive and, on a phone it was restored onto rather than
/// photographed on, says once that the photos did not come with it.
class _SaysThePhotosStayedBehind extends StatelessWidget {
  const _SaysThePhotosStayedBehind({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<LedgerBloc, LedgerState>(
        listener: (context, state) {
          if (state case LedgerReady(:final expenses)) {
            context.read<PhotosStayedBehind>().considered(expenses);
          }
        },
      ),
      BlocListener<PhotosStayedBehind, bool>(
        listener: (context, saying) {
          if (saying) _say(context);
        },
      ),
    ],
    child: child,
  );

  Future<void> _say(BuildContext context) async {
    final notice = context.read<PhotosStayedBehind>();
    await showDialog<void>(
      context: context,
      builder: (context) {
        final words = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(words.ledgerPhotosStayedBehindTitle),
          content: Text(words.ledgerPhotosStayedBehindBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(words.ledgerPhotosStayedBehindGotIt),
            ),
          ],
        );
      },
    );
    await notice.acknowledged();
  }
}
