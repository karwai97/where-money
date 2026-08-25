import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../data/ledger_store.dart';
import '../on_screen.dart';
import '../review/review_bloc.dart';
import '../review/review_screen.dart';
import '../scan/inbox_bloc.dart';
import '../scan/inbox_screen.dart';
import '../scan/model_gateway.dart';
import '../scan/photographer.dart';
import '../session/session_bloc.dart';
import 'ledger_bloc.dart';
import 'rollup_screen.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({
    super.key,
    required this.store,
    required this.model,
    required this.photograph,
  });

  final LedgerStore store;
  final ModelGateway model;
  final Photographer photograph;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => LedgerBloc(store)..add(const LedgerOpened()),
        ),
        // Held here rather than on the Review route, so leaving Review and
        // coming back finds the work still there.
        BlocProvider(create: (_) => ReviewBloc(store)),
        BlocProvider(
          create: (_) => InboxBloc(store, model)..add(const InboxOpened()),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ledger'),
          actions: [
            Builder(builder: _chartsAction),
            Builder(builder: _inboxAction),
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () =>
                  context.read<SessionBloc>().add(const SignOutRequested()),
            ),
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
            LedgerLoading() => const Center(child: CircularProgressIndicator()),
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
    return ListTile(
      title: Text(expense.merchant),
      subtitle: Text('${asDay(expense.date)} · ${expense.category}'),
      trailing: Text(
        asMoney(expense.currency, expense.total),
        style: Theme.of(context).textTheme.titleMedium,
      ),
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
