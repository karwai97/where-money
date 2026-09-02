import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../data/device_preferences.dart';
import '../data/receipt_store.dart';
import '../data/stores.dart';
import '../l10n/app_localizations.dart';
import '../on_screen.dart';
import '../review/review_bloc.dart';
import '../review/review_screen.dart';
import '../scan/inbox_bloc.dart';
import '../scan/inbox_screen.dart';
import '../scan/model_gateway.dart';
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
    required this.uid,
    required this.stores,
    required this.model,
    required this.knobs,
    required this.photograph,
  });

  /// Whose Ledger this is. Only the once-per-account notice needs it; the
  /// stores already know.
  final String uid;

  final Stores stores;
  final ModelGateway model;
  final Knobs knobs;
  final Photographer photograph;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // The Receipt is a file on this phone rather than anything the
        // Ledger's states carry, so its seam has to be reachable from the
        // Expense a user opens.
        RepositoryProvider<ReceiptStore>.value(value: stores.receipts),
        BlocProvider(
          create: (_) =>
              LedgerBloc(stores.ledger, model)..add(const LedgerOpened()),
        ),
        // Held here rather than on the Review route, so leaving Review and
        // coming back finds the work still there.
        BlocProvider(
          create: (_) =>
              ReviewBloc(stores.ledger, stores.scans, stores.receipts),
        ),
        BlocProvider(
          create: (_) => InboxBloc(stores.scans, model, knobs: knobs)
            ..add(const InboxOpened()),
        ),
        BlocProvider(
          create: (context) => PhotosStayedBehind(
            stores.receipts,
            context.read<DevicePreferences>(),
            uid,
          ),
        ),
      ],
      child: _SaysThePhotosStayedBehind(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Ledger'),
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
                  tooltip: 'Add an Expense by hand',
                  onPressed: () => _addByHand(context),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'photograph',
                  tooltip: 'Photograph a receipt',
                  onPressed: () => _photographAReceipt(context),
                  child: const Icon(Icons.photo_camera),
                ),
              ],
            ),
          ),
          body: BlocBuilder<LedgerBloc, LedgerState>(
            builder: (context, state) => switch (state) {
              LedgerLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              LedgerUnavailable(:final reason) => _Message(
                'Your Ledger could not be read.',
                detail: reason,
              ),
              LedgerReady() => Column(
                children: [
                  _MonthBar(state),
                  Expanded(
                    child: switch (state) {
                      LedgerReady(expenses: []) => const _Message(
                        'Nothing here yet.\nAdd one with the button below.',
                      ),
                      LedgerReady(inMonth: []) => _Message(
                        'Nothing in ${state.rollup.monthLabel}.',
                      ),
                      LedgerReady(:final inMonth) => _Expenses(inMonth),
                    },
                  ),
                ],
              ),
            },
          ),
        ),
      ),
    );
  }

  Widget _settingsAction(BuildContext context) {
    // The Ledger, because Settings is where the Corrected Fields tally is read
    // and the route is outside the providers this screen holds.
    final ledger = context.read<LedgerBloc>();

    return IconButton(
      tooltip: 'Settings',
      icon: const Icon(Icons.settings),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider.value(
            value: ledger,
            child: SettingsScreen(knobs: knobs),
          ),
        ),
      ),
    );
  }

  void _addByHand(BuildContext context) {
    final review = context.read<ReviewBloc>()
      ..add(const ManualExpenseStarted());
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BlocProvider.value(value: review, child: const ReviewScreen()),
      ),
    );
  }

  Widget _chartsAction(BuildContext context) {
    final ledger = context.read<LedgerBloc>();

    return IconButton(
      tooltip: 'Charts',
      icon: const Icon(Icons.bar_chart),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              BlocProvider.value(value: ledger, child: const RollupScreen()),
        ),
      ),
    );
  }

  /// The count belongs where the user already is, so Scans cannot quietly pile
  /// up in a screen nobody opens.
  Widget _inboxAction(BuildContext context) {
    final state = context.watch<InboxBloc>().state;
    final waiting = state is InboxReady ? state.scans.length : 0;

    return IconButton(
      tooltip: waiting == 0 ? 'Inbox' : 'Inbox, $waiting waiting',
      icon: Badge(
        isLabelVisible: waiting > 0,
        label: Text('$waiting'),
        child: const Icon(Icons.inbox),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MultiBlocProvider(
            // Both, because Review is reached from the Inbox and the route is
            // outside the providers the Ledger holds.
            providers: [
              BlocProvider.value(value: context.read<InboxBloc>()),
              BlocProvider.value(value: context.read<ReviewBloc>()),
            ],
            child: const InboxScreen(),
          ),
        ),
      ),
    );
  }

  Future<void> _photographAReceipt(BuildContext context) async {
    final inbox = context.read<InboxBloc>();
    final from = await showModalBottomSheet<PhotoSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
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
    final ledger = context.read<LedgerBloc>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ledger.add(const MonthStepped(-1)),
          ),
          Expanded(
            child: Text(
              state.rollup.monthLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Next month',
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
      title: Text(expense.merchant),
      subtitle: Text(
        '${asDay(expense.date)} · ${categoryLabel(words, expense.category)}',
      ),
      trailing: Text(
        asMoney(expense.currency, expense.total),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: () => _open(context),
    );
  }

  void _open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MultiBlocProvider(
        // The Ledger for the Expense itself and for deleting it, Review for
        // correcting it. Both because the route is outside the providers the
        // Ledger screen holds.
        providers: [
          BlocProvider.value(value: context.read<LedgerBloc>()),
          BlocProvider.value(value: context.read<ReviewBloc>()),
        ],
        child: ExpenseScreen(
          expenseId: expense.id,
          receipts: context.read<ReceiptStore>(),
        ),
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
      builder: (context) => AlertDialog(
        title: const Text('The photos stayed behind'),
        content: const Text(
          'Every Expense in your Ledger came back from your account. Receipt '
          'photos never leave the phone they were taken on, so this one has '
          'none of them. Nothing else is missing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
    await notice.acknowledged();
  }
}
