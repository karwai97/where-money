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
import 'photos_stayed_behind.dart';
import 'rollup_screen.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({
    super.key,
    required this.knobs,
    required this.photograph,
  });

  /// Read by the Settings screen this one opens, not by anything here.
  final Knobs knobs;

  final Photographer photograph;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);

    return _SaysThePhotosStayedBehind(
      child: Scaffold(
        appBar: AppBar(
          title: Text(words.ledgerTitle),
          actions: [
            Builder(builder: _chartsAction),
            Builder(builder: _inboxAction),
            Builder(builder: _settingsAction),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'manual',
                tooltip: words.ledgerAddByHand,
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
          ),
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
            // No month bar: there is no Rollup to name a month with until the
            // app knows what this Ledger's money is. Ordinarily this is the
            // empty Ledger a new user opens; it holds Expenses only in the
            // moment before the first one has been learned from.
            LedgerWithoutHomeCurrency(expenses: []) => _Message(
              words.ledgerEmpty,
            ),
            LedgerWithoutHomeCurrency(:final expenses) => _Expenses(expenses),
            LedgerReady() => Column(
              children: [
                _MonthBar(state),
                Expanded(
                  child: switch (state) {
                    LedgerReady(expenses: []) => _Message(words.ledgerEmpty),
                    LedgerReady(inMonth: []) => _Message(
                      words.ledgerNothingInMonth(
                        state.rollup.monthLabel(words),
                      ),
                    ),
                    LedgerReady(:final inMonth) => _Expenses(inMonth),
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
    icon: const Icon(Icons.settings),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SettingsScreen(knobs: knobs)),
    ),
  );

  void _addByHand(BuildContext context) {
    context.read<ReviewBloc>().add(const ManualExpenseStarted());
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ReviewScreen()));
  }

  Widget _chartsAction(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).ledgerCharts,
    icon: const Icon(Icons.bar_chart),
    onPressed: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const RollupScreen())),
  );

  /// The count belongs where the user already is, so Scans cannot quietly pile
  /// up in a screen nobody opens.
  Widget _inboxAction(BuildContext context) {
    final words = AppLocalizations.of(context);
    final state = context.watch<InboxBloc>().state;
    final waiting = state is InboxReady ? state.scans.length : 0;

    return IconButton(
      tooltip: waiting == 0
          ? words.ledgerInbox
          : words.ledgerInboxWaiting(waiting),
      icon: Badge(
        isLabelVisible: waiting > 0,
        label: Text('$waiting'),
        child: const Icon(Icons.inbox),
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

/// The month the Ledger is filtered to, and the way through the months. There
/// is nothing to see past the month the app was opened in, so that way is shut
/// rather than leading to a run of empty months.
class _MonthBar extends StatelessWidget {
  const _MonthBar(this.state);

  final LedgerReady state;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final ledger = context.read<LedgerBloc>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: words.ledgerPreviousMonth,
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ledger.add(const MonthStepped(-1)),
          ),
          Expanded(
            child: Text(
              state.rollup.monthLabel(words),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: words.ledgerNextMonth,
            icon: const Icon(Icons.chevron_right),
            onPressed: state.hasLaterMonth
                ? () => ledger.add(const MonthStepped(1))
                : null,
          ),
        ],
      ),
    );
  }
}

class _Expenses extends StatelessWidget {
  const _Expenses(this.expenses);

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) => ListView.separated(
    itemCount: expenses.length,
    separatorBuilder: (_, _) => const Divider(height: 1),
    itemBuilder: (context, index) => _ExpenseTile(expenses[index]),
  );
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile(this.expense);

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);

    return ListTile(
      // How much of this Ledger the app produced, readable down the column
      // rather than one Expense at a time.
      leading: HowItGotHere(expense.source),
      title: Text(merchantLabel(words, expense.merchant)),
      subtitle: Text(dayAndCategory(words, expense.date, expense.category)),
      trailing: Text(
        asMoney(expense.currency, expense.total),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: () => _open(context),
    );
  }

  void _open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      // The route's own context, not this tile's. The Ledger is a live stream,
      // so the row can be gone while the Expense it opened is still on top,
      // and a rebuild of the route would then be reading a dead element.
      builder: (context) => ExpenseScreen(
        expenseId: expense.id,
        receipts: context.read<ReceiptStore>(),
      ),
    ),
  );
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
