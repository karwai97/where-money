import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../scan/receipt_on_screen.dart';
import 'review_bloc.dart';

/// Review: what the Model read, beside the receipt it read it from, with
/// anything the Check noticed pinned above. The same screen serves an Expense
/// the user types themselves, which simply arrives with nothing pre-filled.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReviewBloc, ReviewState>(
      // Only a transition into idle means the Expense was committed. The very
      // first frame is idle too, because the route is pushed before the event
      // that seeds it has been handled.
      listenWhen: (previous, current) =>
          previous is ReviewInProgress && current is ReviewIdle,
      listener: (context, state) => Navigator.of(context).pop(),
      builder: (context, state) => switch (state) {
        ReviewIdle() => Scaffold(appBar: AppBar(title: const Text(_typed))),
        final ReviewInProgress reviewing => _Form(
          reviewing,
          key: ValueKey(reviewing.editing?.id ?? reviewing.scan?.id ?? _typed),
        ),
      },
    );
  }
}

const _typed = 'Add an Expense';
const _photographed = 'Review this receipt';
const _correcting = 'Correct this Expense';

/// Which of the three things this screen is doing. All three edit an
/// Extraction against a Check; only the words differ.
String _titleOf(ReviewInProgress state) => switch (state) {
  ReviewInProgress(editing: final Expense _) => _correcting,
  ReviewInProgress(scan: final Scan _) => _photographed,
  _ => _typed,
};

class _Form extends StatefulWidget {
  const _Form(this.state, {super.key});

  final ReviewInProgress state;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  /// Controllers are seeded once and never written back from state. The bloc is
  /// the truth about the Extraction; the text the user is halfway through
  /// typing is the field's own business, and pushing state into it mid-word is
  /// what makes a cursor jump to the end.
  late final Map<ReviewField, TextEditingController> _fields;

  /// Storage for the Line Item rows' controllers, kept the same length as the
  /// Extraction's Line Items. The Extraction is what decides how many rows
  /// there are; this only holds their typing.
  final _rows = <_RowControllers>[];

  @override
  void initState() {
    super.initState();
    final extraction = widget.state.extraction;
    _fields = {
      ReviewField.merchant: TextEditingController(text: extraction.merchant),
      ReviewField.purchasedAt: TextEditingController(
        text: extraction.purchasedAt ?? '',
      ),
      ReviewField.currency: TextEditingController(text: extraction.currency),
      ReviewField.subtotal: TextEditingController(
        text: _amountText(extraction.subtotal),
      ),
      ReviewField.tax: TextEditingController(text: _amountText(extraction.tax)),
      ReviewField.tip: TextEditingController(text: _amountText(extraction.tip)),
      ReviewField.total: TextEditingController(
        text: _amountText(extraction.total),
      ),
    };
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  ReviewBloc get _bloc => context.read<ReviewBloc>();

  void _removeRow(int index) {
    _rows.removeAt(index).dispose();
    _bloc.add(LineItemRemoved(index));
  }

  Future<void> _pickDate() async {
    final controller = _fields[ReviewField.purchasedAt]!;
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? today,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
    );
    if (picked == null) return;

    final iso = picked.toIso8601String().split('T').first;
    controller.text = iso;
    _bloc.add(FieldCorrected(ReviewField.purchasedAt, iso));
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final items = state.extraction.lineItems;
    _matchRowsTo(items);

    return Scaffold(
      appBar: AppBar(title: Text(_titleOf(state))),
      body: Column(
        children: [
          if (state.refusal != null) _Refused(state.refusal!),
          // Above the fields and out of the scroll view, so what the Check
          // noticed does not scroll away while the user corrects it.
          if (state.check.findings.isEmpty)
            _Clean(photographed: state.scan != null && state.editing == null)
          else
            _Findings(state.check.findings),
          Expanded(
            child: _BesideTheReceipt(
              receipt: state.receipt,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _text(ReviewField.merchant),
                  Row(
                    children: [
                      Expanded(child: _text(ReviewField.purchasedAt)),
                      IconButton(
                        tooltip: 'Pick a date',
                        icon: const Icon(Icons.calendar_today),
                        onPressed: _pickDate,
                      ),
                    ],
                  ),
                  _text(ReviewField.currency),
                  _Closed(
                    label: ReviewField.category.label,
                    value: state.extraction.category,
                    options: categories,
                    copy: categoryLabel,
                    onChosen: (value) =>
                        _bloc.add(FieldCorrected(ReviewField.category, value)),
                  ),
                  if (state.extraction.categoryReason.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 6),
                      child: Text(
                        'The Model chose that because: '
                        '${state.extraction.categoryReason}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  _Closed(
                    label: ReviewField.paymentMethod.label,
                    value: state.extraction.paymentMethod,
                    options: paymentMethods,
                    copy: paymentMethodLabel,
                    onChosen: (value) => _bloc.add(
                      FieldCorrected(ReviewField.paymentMethod, value),
                    ),
                  ),
                  _text(ReviewField.subtotal, number: true),
                  _text(ReviewField.tax, number: true),
                  _text(ReviewField.tip, number: true),
                  _text(ReviewField.total, number: true),
                  const SizedBox(height: 24),
                  Text(
                    ReviewField.lineItems.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (var index = 0; index < items.length; index++)
                    _Row(
                      controllers: _rows[index],
                      category: items[index].category,
                      onCorrected: (field, value) =>
                          _bloc.add(LineItemCorrected(index, field, value)),
                      onRemoved: () => _removeRow(index),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _bloc.add(const LineItemAdded()),
                      icon: const Icon(Icons.add),
                      label: const Text('Add a Line Item'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: state.committing
                        ? null
                        : () => _bloc.add(const ReviewCommitted()),
                    child: Text(
                      state.editing == null ? 'Add to Ledger' : 'Save',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _matchRowsTo(List<LineItem> items) {
    while (_rows.length < items.length) {
      _rows.add(_RowControllers(items[_rows.length]));
    }
    while (_rows.length > items.length) {
      _rows.removeLast().dispose();
    }
  }

  Widget _text(ReviewField field, {bool number = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextField(
      controller: _fields[field],
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      onChanged: (value) => _bloc.add(FieldCorrected(field, value)),
    ),
  );
}

/// The receipt, next to the fields it was read into. Beside them where there
/// is width for it and above them where there is not — either way both are on
/// screen at once, which is the whole point of Review.
class _BesideTheReceipt extends StatelessWidget {
  const _BesideTheReceipt({required this.receipt, required this.child});

  final Uint8List? receipt;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final receipt = this.receipt;
    if (receipt == null) return child;

    return LayoutBuilder(
      builder: (context, space) => space.maxWidth >= 700
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: ReceiptOnScreen(receipt)),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            )
          : Column(
              children: [
                SizedBox(height: 200, child: ReceiptOnScreen(receipt)),
                const Divider(height: 1),
                Expanded(child: child),
              ],
            ),
    );
  }
}

/// The clean lane's framing. The Check found nothing, which is not permission
/// to commit silently — it is permission to ask for one tap.
class _Clean extends StatelessWidget {
  const _Clean({required this.photographed});

  /// Nothing to say to someone typing an Expense in themselves: they know what
  /// they wrote.
  final bool photographed;

  @override
  Widget build(BuildContext context) {
    if (!photographed) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Text(
        'Everything on this receipt adds up. Check it against the photo, then '
        'add it.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

/// What the Check noticed, in the words it wrote them in. A Finding is already
/// a sentence about the receipt; a rule name would be worse copy than what is
/// already on it.
class _Findings extends StatelessWidget {
  const _Findings(this.findings);

  final List<Finding> findings;

  @override
  Widget build(BuildContext context) {
    if (findings.isEmpty) return const SizedBox.shrink();

    final colours = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: colours.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final finding in findings)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      finding.severity == Severity.fail
                          ? Icons.error_outline
                          : Icons.info_outline,
                      size: 20,
                      color: finding.severity == Severity.fail
                          ? colours.error
                          : colours.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            finding.label,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            finding.detail,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Refused extends StatelessWidget {
  const _Refused(this.reason);

  final String reason;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('That Expense was not saved. Your typing is still here.'),
        Text(reason, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

/// A field whose value can only ever come from a closed list. There is no
/// free-text path into a Category by design — see ADR-0005.
class _Closed extends StatelessWidget {
  const _Closed({
    required this.label,
    required this.value,
    required this.options,
    required this.copy,
    required this.onChosen,
  });

  final String label;
  final String value;
  final List<String> options;
  final String Function(String) copy;
  final void Function(String) onChosen;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: DropdownButtonFormField<String>(
      // Seeded rather than driven, so the key is what keeps what is shown in
      // step with the Extraction after a Line Item above it is removed.
      key: ValueKey('$label:$value'),
      initialValue: options.contains(value) ? value : options.last,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(copy(option))),
      ],
      onChanged: (chosen) => chosen == null ? null : onChosen(chosen),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.controllers,
    required this.category,
    required this.onCorrected,
    required this.onRemoved,
  });

  final _RowControllers controllers;
  final String category;
  final void Function(LineItemField, String) onCorrected;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 6),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controllers.description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  onChanged: (value) =>
                      onCorrected(LineItemField.description, value),
                ),
              ),
              IconButton(
                tooltip: 'Remove this Line Item',
                icon: const Icon(Icons.close),
                onPressed: onRemoved,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _number(
                  controllers.quantity,
                  'Qty',
                  LineItemField.quantity,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _number(
                  controllers.unitPrice,
                  'Unit price',
                  LineItemField.unitPrice,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _number(
                  controllers.amount,
                  'Amount',
                  LineItemField.amount,
                ),
              ),
            ],
          ),
          _Closed(
            label: ReviewField.category.label,
            value: category,
            options: categories,
            copy: categoryLabel,
            onChosen: (value) => onCorrected(LineItemField.category, value),
          ),
        ],
      ),
    ),
  );

  Widget _number(
    TextEditingController controller,
    String label,
    LineItemField field,
  ) => TextField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (value) => onCorrected(field, value),
  );
}

class _RowControllers {
  _RowControllers(LineItem item)
    : description = TextEditingController(text: item.description),
      quantity = TextEditingController(text: _amountText(item.quantity)),
      unitPrice = TextEditingController(text: _amountText(item.unitPrice)),
      amount = TextEditingController(text: _amountText(item.amount));

  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  final TextEditingController amount;

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
    amount.dispose();
  }
}

/// Zero reads as an empty field rather than as 0.00: on a form the user is
/// filling in, a pre-typed zero is something to delete before typing.
String _amountText(double? value) =>
    value == null || value == 0 ? '' : value.toStringAsFixed(2);
