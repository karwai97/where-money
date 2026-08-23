import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../data/ledger_store.dart';
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
    return BlocProvider(
      create: (_) => LedgerBloc(store)..add(const LedgerOpened()),
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
        floatingActionButton: debugWrites
            ? Builder(
                builder: (context) => FloatingActionButton(
                  tooltip: 'Write a debug Expense',
                  onPressed: () => context.read<LedgerBloc>().add(
                    const DebugExpenseWritten(),
                  ),
                  child: const Icon(Icons.receipt_long),
                ),
              )
            : null,
        body: BlocBuilder<LedgerBloc, LedgerState>(
          builder: (context, state) => switch (state) {
            LedgerLoading() => const Center(child: CircularProgressIndicator()),
            LedgerUnavailable(:final reason) => _Message(
              'Your Ledger could not be read.',
              detail: reason,
            ),
            LedgerReady(expenses: []) => _Message(
              debugWrites
                  ? 'Nothing here yet.\nWrite one with the button below.'
                  : 'Nothing here yet.\nPhotograph a receipt to start.',
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
