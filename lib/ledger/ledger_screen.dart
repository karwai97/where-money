import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../data/ledger_store.dart';
import '../review/review_bloc.dart';
import '../review/review_screen.dart';
import '../session/session_bloc.dart';
import 'ledger_bloc.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({
    super.key,
    required this.store,
    required this.debugWrites,
  });

  final LedgerStore store;

  /// The stand-in for the camera until ticket 04. Off in release builds.
  final bool debugWrites;

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
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ledger'),
          actions: [
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
              if (debugWrites) ...[
                FloatingActionButton.small(
                  heroTag: 'debug',
                  tooltip: 'Write a debug Expense',
                  onPressed: () => context.read<LedgerBloc>().add(
                    const DebugExpenseWritten(),
                  ),
                  child: const Icon(Icons.receipt_long),
                ),
                const SizedBox(height: 12),
              ],
              FloatingActionButton(
                heroTag: 'manual',
                tooltip: 'Add an Expense by hand',
                onPressed: () => _addByHand(context),
                child: const Icon(Icons.add),
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
            LedgerReady(expenses: []) => const _Message(
              'Nothing here yet.\nAdd one with the button below.',
            ),
            LedgerReady(:final expenses, :final refusal) => _Expenses(
              expenses: expenses,
              refusal: refusal,
            ),
          },
        ),
      ),
    );
  }

  void _addByHand(BuildContext context) {
    final review = context.read<ReviewBloc>()..add(const ManualExpenseStarted());
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BlocProvider.value(value: review, child: const ReviewScreen()),
      ),
    );
  }
}

class _Expenses extends StatefulWidget {
  const _Expenses({required this.expenses, this.refusal});

  final List<Expense> expenses;
  final String? refusal;

  @override
  State<_Expenses> createState() => _ExpensesState();
}

class _ExpensesState extends State<_Expenses> {
  var _dismissed = false;

  @override
  void didUpdateWidget(_Expenses oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refusal != oldWidget.refusal) _dismissed = false;
  }

  @override
  Widget build(BuildContext context) {
    final expenses = widget.expenses;

    return Column(
      children: [
        if (widget.refusal != null && !_dismissed)
          MaterialBanner(
            content: const Text('That Expense was not saved.'),
            actions: [
              TextButton(
                onPressed: () => setState(() => _dismissed = true),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        Expanded(
          child: ListView.separated(
            itemCount: expenses.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _ExpenseTile(expenses[index]),
          ),
        ),
      ],
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile(this.expense);

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final date = expense.date;
    return ListTile(
      title: Text(expense.merchant),
      subtitle: Text(
        '${date.year}-${_two(date.month)}-${_two(date.day)} · ${expense.category}',
      ),
      trailing: Text(
        '${expense.currency} ${expense.total.toStringAsFixed(2)}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
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
