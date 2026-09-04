import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../data/receipt_store.dart';
import '../l10n/app_localizations.dart';
import '../on_screen.dart';
import '../review/review_bloc.dart';
import '../review/review_screen.dart';
import '../scan/receipt_on_screen.dart';
import '../settings/settings_cubit.dart';
import 'how_it_got_here.dart';
import 'ledger_bloc.dart';

/// One Expense, opened: what was bought, and the receipt it was read from.
/// Read out of the Ledger by id rather than held, so a correction saved on the
/// Review screen is already here when that screen pops.
class ExpenseScreen extends StatelessWidget {
  const ExpenseScreen({
    super.key,
    required this.expenseId,
    required this.receipts,
  });

  final String expenseId;

  /// For the receipt, which is a file on this phone rather than anything the
  /// Ledger's states carry.
  final ReceiptStore receipts;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);

    return BlocBuilder<LedgerBloc, LedgerState>(
      builder: (context, state) {
        final expense = switch (state) {
          LedgerReady(:final expenses) =>
            expenses.where((held) => held.id == expenseId).firstOrNull,
          _ => null,
        };

        if (expense == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(words.expenseGone),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(merchantLabel(words, expense.merchant)),
            actions: [
              IconButton(
                tooltip: words.expenseCorrect,
                icon: const Icon(Icons.edit),
                onPressed: () => _correct(context, expense),
              ),
              IconButton(
                tooltip: words.expenseDelete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(context, expense),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _Headline(expense),
              const SizedBox(height: 16),
              _LineItems(expense),
              const SizedBox(height: 24),
              _Receipt(receipts: receipts, path: expense.receiptPath),
            ],
          ),
        );
      },
    );
  }

  void _correct(BuildContext context, Expense expense) {
    context.read<ReviewBloc>().add(ExpenseEditStarted(expense));
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ReviewScreen()));
  }

  Future<void> _delete(BuildContext context, Expense expense) async {
    final words = AppLocalizations.of(context);
    final ledger = context.read<LedgerBloc>();
    final navigator = Navigator.of(context);
    final amount = asMoney(expense.currency, expense.total);
    final merchant = merchantLabel(words, expense.merchant);

    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(words.expenseDeleteTitle),
        content: Text(
          // The photo is only worth mentioning where there is one to keep. An
          // Expense typed by hand never had one, and promising to keep it is a
          // promise about nothing.
          expense.receiptPath == null
              ? words.expenseDeleteBody(merchant, amount)
              : words.expenseDeleteBodyKeepsReceipt(merchant, amount),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(words.expenseDeleteKeep),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(words.expenseDeleteConfirm),
          ),
        ],
      ),
    );
    if (agreed != true) return;

    ledger.add(ExpenseDeleted(expense.id));
    navigator.pop();
  }
}

class _Headline extends StatelessWidget {
  const _Headline(this.expense);

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scanned = expense.source == ExpenseSource.scanned;
    final home = context.watch<SettingsCubit>().state.homeCurrency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          asMoney(expense.currency, expense.total),
          style: text.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(dayAndCategory(words, expense.date, expense.category)),
        const SizedBox(height: 8),
        Row(
          children: [
            HowItGotHere(expense.source, size: 20),
            const SizedBox(width: 8),
            Text(
              scanned ? words.expenseFromReceipt : words.expenseTypedByHand,
              style: text.bodySmall,
            ),
          ],
        ),
        // The Rollup counts one currency and says how many it left out
        // (ADR-0006). This is where the user finds out which one theirs was.
        // Nothing is left out while there is no Home Currency, so there is
        // nothing to say either.
        if (home != null && expense.currency != home) ...[
          const SizedBox(height: 8),
          Text(
            words.expenseForeignCurrency(expense.currency),
            style: text.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// What was actually bought. An Expense typed by hand usually has none, and an
/// empty section reads better than a heading over nothing.
class _LineItems extends StatelessWidget {
  const _LineItems(this.expense);

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);

    if (expense.lineItems.isEmpty) {
      return Text(
        words.expenseNoLineItems,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The same words Review's own Line Items section uses: one field of an
        // Extraction, named once.
        Text(
          words.fieldLineItems,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final item in expense.lineItems)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.description),
            subtitle: Text(
              _countOf(words, item) ?? categoryLabel(words, item.category),
            ),
            trailing: Text(asMoney(expense.currency, item.amount)),
          ),
      ],
    );
  }

  static String? _countOf(AppLocalizations words, LineItem item) {
    final quantity = item.quantity;
    final unitPrice = item.unitPrice;
    if (quantity == null || unitPrice == null) return null;
    return words.expenseLineItemCount(
      categoryLabel(words, item.category),
      _quantity(quantity),
      unitPrice.toStringAsFixed(2),
    );
  }

  /// Two of something is `2`, not `2.0`. A weighed item really is fractional,
  /// so the decimals only go where the receipt had them.
  static String _quantity(double of) =>
      of == of.roundToDouble() ? '${of.toInt()}' : '$of';
}

/// The receipt, read once. An Expense restored onto a new phone has a path and
/// no file behind it — images never leave the device they were taken on
/// (ADR-0003) — and that is worth saying rather than leaving a blank.
class _Receipt extends StatefulWidget {
  const _Receipt({required this.receipts, required this.path});

  final ReceiptStore receipts;
  final String? path;

  @override
  State<_Receipt> createState() => _ReceiptState();
}

class _ReceiptState extends State<_Receipt> {
  /// Started once rather than on every rebuild — the Expense above this
  /// changes as it is corrected, and the receipt does not.
  Future<Uint8List?>? _reading;

  @override
  void initState() {
    super.initState();
    final path = widget.path;
    if (path != null) _reading = widget.receipts.bytesAt(path);
  }

  @override
  Widget build(BuildContext context) {
    final reading = _reading;
    if (reading == null) return const SizedBox.shrink();

    return FutureBuilder<Uint8List?>(
      future: reading,
      builder: (context, read) => switch (read) {
        AsyncSnapshot(connectionState: ConnectionState.waiting) => Center(
          child: CircularProgressIndicator(
            semanticsLabel: AppLocalizations.of(context).expenseReceiptLoading,
          ),
        ),
        AsyncSnapshot(data: final Uint8List receipt) => ReceiptOnScreen(
          receipt,
        ),
        // Never here, or unreadable: either way it is not on this phone, and
        // which of the two it is is not something the user can act on.
        _ => Text(
          AppLocalizations.of(context).expenseReceiptNotOnThisDevice,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      },
    );
  }
}
