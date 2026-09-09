import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../a_form_of_rows.dart';
import '../choosing_a_currency.dart';
import '../l10n/app_localizations.dart';
import '../on_screen.dart';
import '../scan/receipt_on_screen.dart';
import '../settings/themes.dart';
import 'finding_copy.dart';
import 'review_bloc.dart';

/// Review: what the Model read, beside the receipt it read it from, with
/// anything the Check noticed said under the field it is about. The same screen
/// serves an Expense the user types themselves, which simply arrives with
/// nothing pre-filled.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);

    return BlocConsumer<ReviewBloc, ReviewState>(
      // Only a transition into idle means the Expense was committed. The very
      // first frame is idle too, because the route is pushed before the event
      // that seeds it has been handled.
      listenWhen: (previous, current) =>
          previous is ReviewInProgress && current is ReviewIdle,
      listener: (context, state) => Navigator.of(context).pop(),
      builder: (context, state) => switch (state) {
        ReviewIdle() => Scaffold(
          appBar: barNamed(context, words.reviewTitleTyped),
        ),
        final ReviewInProgress reviewing => _Form(
          reviewing,
          key: ValueKey(
            reviewing.editing?.id ?? reviewing.scan?.id ?? _typedByHand,
          ),
        ),
      },
    );
  }
}

/// Stands for "no Scan and no Expense" in the key that decides when the form is
/// rebuilt from scratch. A key, not a word — a title would change with the
/// language and throw away what the user was halfway through typing.
const _typedByHand = 'typed-by-hand';

/// Which of the three things this screen is doing. All three edit an
/// Extraction against a Check; only the words differ.
String _titleOf(ReviewInProgress state, AppLocalizations words) =>
    switch (state) {
      ReviewInProgress(editing: final Expense _) => words.reviewTitleCorrecting,
      ReviewInProgress(scan: final Scan _) => words.reviewTitlePhotographed,
      _ => words.reviewTitleTyped,
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
    final today = _bloc.clock();
    final inTheField = DateTime.tryParse(controller.text) ?? today;
    final earliest = DateTime(today.year - 5);

    // Five years back to today is the ordinary range, and the end the field
    // falls outside of stretches to reach it. A date in the future or one
    // older than the range is exactly what the user opened the calendar to
    // correct — the Check is complaining about it under this very field — and
    // a calendar that will not open on the date in the field is no use for
    // correcting it. Widening only ever happens when the field is already
    // outside, so an ordinary date still cannot be moved past today.
    final picked = await showDatePicker(
      context: context,
      initialDate: inTheField,
      firstDate: inTheField.isBefore(earliest) ? inTheField : earliest,
      lastDate: inTheField.isAfter(today) ? inTheField : today,
    );
    if (picked == null) return;

    final iso = picked.toIso8601String().split('T').first;
    controller.text = iso;
    _bloc.add(FieldCorrected(ReviewField.purchasedAt, iso));
  }

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final state = widget.state;
    final items = state.extraction.lineItems;
    _matchRowsTo(items);

    final noted = _SortedFindings(state.check.findings);

    return Scaffold(
      appBar: barNamed(context, _titleOf(state, words)),
      body: _BesideTheReceipt(
        receipt: state.receipt,
        child: Column(
          children: [
            // The one Finding that earns room of its own, above the form and
            // out of the scroll view: it is a claim about the whole
            // photograph, and the Check returns it alone.
            if (noted.notAReceipt case final NotAReceipt finding)
              _WholePhoto(finding),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  // Everything at the top of the form is about the form rather
                  // than about a field, and scrolls away with it: none of it is
                  // worth height on a phone with the keyboard up. The header
                  // is in the scroll for the same reason, unlike the Ledger's.
                  if (state.refusal != null) _Refused(state.refusal!),
                  _TotalSoFar(state),
                  _Findings(noted.aboutNoField),
                  Head(words.reviewSectionWhatThisWas),
                  _text(words, noted, ReviewField.merchant),
                  _under(
                    noted[ReviewField.purchasedAt],
                    Ruled(
                      // As every other row does: a rule between a field and
                      // the sentence about it reads as if the sentence
                      // belonged to the row below.
                      ruled: noted[ReviewField.purchasedAt].isEmpty,
                      vertical: 4,
                      child: Row(
                        children: [
                          Expanded(
                            child: _bareText(
                              words,
                              ReviewField.purchasedAt,
                              marked: _worstOf(noted[ReviewField.purchasedAt]),
                            ),
                          ),
                          IconButton(
                            tooltip: words.reviewPickDate,
                            iconSize: 20,
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.calendar_today),
                            onPressed: _pickDate,
                          ),
                        ],
                      ),
                    ),
                  ),
                  _under(
                    noted[ReviewField.category],
                    Ruled(
                      ruled: noted[ReviewField.category].isEmpty,
                      child: _explained(
                        state.extraction.categoryReason.isEmpty
                            ? ''
                            : words.reviewCategoryReason(
                                state.extraction.categoryReason,
                              ),
                        Closed(
                          name: ReviewField.category.name,
                          label: ReviewField.category.labelIn(words),
                          value: state.extraction.category,
                          options: categories,
                          whenUnrecognised: 'other',
                          copy: (slug) => categoryLabel(words, slug),
                          marked: _worstOf(noted[ReviewField.category]),
                          onChosen: (value) => _bloc.add(
                            FieldCorrected(ReviewField.category, value),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _under(
                    noted[ReviewField.paymentMethod],
                    Ruled(
                      ruled: noted[ReviewField.paymentMethod].isEmpty,
                      child: Closed(
                        name: ReviewField.paymentMethod.name,
                        label: ReviewField.paymentMethod.labelIn(words),
                        value: state.extraction.paymentMethod,
                        options: paymentMethods,
                        whenUnrecognised: 'unknown',
                        copy: (slug) => paymentMethodLabel(words, slug),
                        marked: _worstOf(noted[ReviewField.paymentMethod]),
                        onChosen: (value) => _bloc.add(
                          FieldCorrected(ReviewField.paymentMethod, value),
                        ),
                      ),
                    ),
                  ),
                  // The currency heads the figures rather than sitting with
                  // the merchant: it is the unit every one of them is in.
                  Head(words.reviewSectionWhatItCost),
                  _under(
                    noted[ReviewField.currency],
                    Ruled(
                      ruled: noted[ReviewField.currency].isEmpty,
                      child: Chosen(
                        label: ReviewField.currency.labelIn(words),
                        value: state.extraction.currency,
                        marked: _worstOf(noted[ReviewField.currency]),
                        onTap: () async {
                          final chosen = await chooseACurrency(context);
                          if (chosen != null) {
                            _bloc.add(
                              FieldCorrected(ReviewField.currency, chosen),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  _text(words, noted, ReviewField.subtotal, number: true),
                  _text(words, noted, ReviewField.tax, number: true),
                  _text(words, noted, ReviewField.tip, number: true),
                  // What the parts add to, and the one figure on the form the
                  // Ledger will read: given the rule the design puts over a
                  // total and a weight over the figures above it.
                  _text(
                    words,
                    noted,
                    ReviewField.total,
                    number: true,
                    summed: true,
                  ),
                  Head(
                    ReviewField.lineItems.labelIn(words),
                    trailing: items.isEmpty ? null : '${items.length}',
                    ruled: noted[ReviewField.lineItems].isEmpty,
                  ),
                  // Between the head and the first row. All three of these
                  // are about the set of rows rather than about any one of
                  // them: the sum is a property of the set, and the other two
                  // carry a description with no index to match a row on.
                  _Findings(noted[ReviewField.lineItems]),
                  for (var index = 0; index < items.length; index++)
                    _Row(
                      controllers: _rows[index],
                      category: items[index].category,
                      onCorrected: (field, value) =>
                          _bloc.add(LineItemCorrected(index, field, value)),
                      onRemoved: () => _removeRow(index),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _bloc.add(const LineItemAdded()),
                        icon: const Icon(Icons.add, size: 20),
                        label: Text(words.reviewAddLineItem),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // The one action the screen is for, kept out of the scroll: a
            // form long enough to need scrolling is a form whose button was
            // reachable only by getting to the end of it.
            _Commit(
              committing: state.committing,
              label: state.editing == null
                  ? words.reviewAddToLedger
                  : words.reviewSave,
              onPressed: () => _bloc.add(const ReviewCommitted()),
            ),
          ],
        ),
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

  /// A field with whatever the Check said about it underneath: the correction
  /// and the reason for it in one place. The row gives up its own rule when
  /// something is said, so the sentence stays inside the row it belongs to
  /// rather than being ruled off from it.
  Widget _under(List<Finding> findings, Widget field) => findings.isEmpty
      ? field
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [field, _Findings(findings, beside: true)],
        );

  /// A field with the Model's reason for what it chose under it, lined up
  /// with the value the way a Finding is — but inside the row's rule rather
  /// than outside it, because a reason is part of what the field is showing
  /// and not a correction waiting to be made. Composed here rather than
  /// inside the field so that the rule decision above and the thing that
  /// wants the rule kept are read together.
  Widget _explained(String note, Widget field) => note.isEmpty
      ? field
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            field,
            Padding(
              padding: EdgeInsets.only(left: sayingIndent(context)),
              child: Text(note, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        );

  Widget _text(
    AppLocalizations words,
    _SortedFindings noted,
    ReviewField field, {
    bool number = false,
    bool summed = false,
  }) {
    final findings = noted[field];

    return _under(
      findings,
      Ruled(
        ruled: findings.isEmpty,
        above: summed,
        child: _bareText(
          words,
          field,
          number: number,
          summed: summed,
          marked: _worstOf(findings),
        ),
      ),
    );
  }

  /// The input alone, unruled. Only the Date needs it from outside: a calendar
  /// shares its row, and what the Check said belongs under the pair rather
  /// than under half of it.
  Widget _bareText(
    AppLocalizations words,
    ReviewField field, {
    bool number = false,
    bool summed = false,
    Severity? marked,
  }) {
    final text = Theme.of(context).textTheme;
    // A figure is monospaced wherever the app draws one, and the total is set
    // a step heavier than the parts above it.
    final style = number
        ? asFigures(
            (summed ? text.bodyLarge : text.bodyMedium)?.copyWith(
              fontWeight: summed ? FontWeight.w500 : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          )
        : atItsWeight(text.bodyMedium?.copyWith(fontWeight: FontWeight.w500));

    return Semantics(
      // The field's name is drawn as a tracked mark beside the input rather
      // than inside it, and `InputDecoration.icon` is not read out. Said here
      // so the field is still named to whoever cannot see the column.
      label: field.labelIn(words),
      child: TextField(
        controller: _fields[field],
        style: style,
        textAlign: number ? TextAlign.right : TextAlign.start,
        decoration: asARow(
          context,
          field.labelIn(words),
          marked: marked,
          // Something to do, where the Check has complained and the field is
          // empty: without it a blank cell on a form of blank cells says
          // nothing about which of them is waiting on the reader. An empty
          // field nobody has complained about is not a task and gets none.
          asking: marked != null && _fields[field]!.text.isEmpty
              ? words.reviewTypeItIn
              : null,
        ),
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        onChanged: (value) => _bloc.add(FieldCorrected(field, value)),
      ),
    );
  }
}

/// The worst thing the Check said about one field, or nothing where it said
/// nothing. A field can hold a fail and a warn at once, and the mark on its
/// name is the louder of the two.
Severity? _worstOf(List<Finding> findings) => findings.isEmpty
    ? null
    : findings.any((finding) => finding.severity == Severity.fail)
    ? Severity.fail
    : Severity.warn;

/// The one action the screen exists for, under a rule and out of the scroll.
class _Commit extends StatelessWidget {
  const _Commit({
    required this.committing,
    required this.label,
    required this.onPressed,
  });

  final bool committing;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Out of the way while the keyboard is up. Between the bar and the keys
    // a phone has three rows of form left, and somebody typing into it is
    // filling the form in rather than looking for the way out of it — the
    // button is one keyboard dismissal away, which is where their thumb
    // already is.
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: FilledButton(
            onPressed: committing ? null : onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: asScreenName(
                theme.textTheme.labelLarge,
                tracking: 1.2,
              ),
            ),
            child: Text(cased(AppLocalizations.of(context), label)),
          ),
        ),
      ),
    );
  }
}

/// What the receipt claims, over the form that claims it: the figure, and how
/// many Findings stand beside it.
///
/// The Ledger's month header, borrowed — same ground, same figure at the same
/// size, same tracked mark in the accent at the far end — because the two are
/// the same shape of statement. Inside the scroll, unlike the Ledger's: on a
/// phone with the keyboard up this is not worth permanent height, and the
/// count changing as fields are corrected must not move the field under the
/// finger, which is why nothing but the mark comes and goes.
class _TotalSoFar extends StatelessWidget {
  const _TotalSoFar(this.state);

  final ReviewInProgress state;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colours = theme.colorScheme;
    // How many Findings are still standing. Deliberately not the count the
    // spec left out of scope — one beside the button that scrolled to the
    // first Finding: nothing here gates the commit or moves the form, and the
    // sentence under the figure says the same thing in words.
    final standing = state.check.findings.length;

    return Container(
      decoration: BoxDecoration(
        color: colours.surfaceContainer,
        border: Border(bottom: BorderSide(color: colours.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: _Claimed(state.extraction)),
              // Not flexible: a Flexible would take a share of the room the
              // figure gave up and leave the mark stranded mid-row. Unflexed
              // it is offered the whole width, so it wraps rather than
              // overflowing when the text size is turned up.
              if (standing > 0)
                Text(
                  cased(words, words.reviewToCheck(standing)),
                  style: asTrackedMark(
                    theme.textTheme.labelSmall?.copyWith(
                      color: colours.primary,
                    ),
                  ),
                ),
            ],
          ),
          // The clean lane's framing, and the only thing under the figure. The
          // Check found nothing, which is not permission to commit silently —
          // it is permission to ask for one tap. Nothing to say to someone
          // typing an Expense in themselves: they know what they wrote.
          if (standing == 0 && state.scan != null && state.editing == null) ...[
            const SizedBox(height: 6),
            Text(words.reviewClean, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// The total as the form has it. A dash until there is one: a zero in the
/// headline is a claim the receipt never made, and the fields below leave a
/// zero blank for the same reason.
class _Claimed extends StatelessWidget {
  const _Claimed(this.extraction);

  final Extraction extraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = extraction.currency;

    return Text(
      extraction.total == 0
          ? '—'
          : currency.isEmpty
          ? asAmount(extraction.total)
          : asMoney(currency, extraction.total),
      style: asClaimedFigure(theme.textTheme.titleLarge),
    );
  }
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

/// The Check's Findings sorted into the places they are said. [Finding.field]
/// has carried the answer since the Check was written; this is only the
/// dispatch. The form asks for every [ReviewField] by name, so a Finding
/// naming one is shown — a field added to the enum without a slot on this form
/// would collect Findings nobody reads.
class _SortedFindings {
  factory _SortedFindings(List<Finding> findings) {
    NotAReceipt? photograph;
    final aboutNoField = <Finding>[];
    final byField = <ReviewField, List<Finding>>{};

    for (final finding in findings) {
      if (finding is NotAReceipt) {
        photograph = finding;
      } else if (finding.field case final ReviewField field) {
        (byField[field] ??= []).add(finding);
      } else {
        aboutNoField.add(finding);
      }
    }

    return _SortedFindings._(photograph, aboutNoField, byField);
  }

  const _SortedFindings._(this.notAReceipt, this.aboutNoField, this._byField);

  final NotAReceipt? notAReceipt;

  /// A Finding no correction settles, which by default is where a new kind
  /// added with a null field lands — the safe place for it.
  final List<Finding> aboutNoField;

  final Map<ReviewField, List<Finding>> _byField;

  List<Finding> operator [](ReviewField field) =>
      _byField[field] ?? const <Finding>[];
}

/// What the Check noticed, said in full. A Finding carries only its kind and
/// the values it found; the sentence comes from [sayingFor], because a rule
/// name would be worse copy than a sentence about this receipt.
///
/// Deliberately not `InputDecoration.errorText`: that is one string, and
/// [sayingFor] returns a subject and a sentence under it. A field can also hold
/// two of these at once — an empty total is both missing and not what the parts
/// add to.
class _Findings extends StatelessWidget {
  const _Findings(this.findings, {this.beside = false});

  final List<Finding> findings;

  /// Whether this sits under a field, in which case it lines up with the
  /// value rather than with the name of the field — and carries the rule the
  /// row above gave up, so the two read as one row.
  final bool beside;

  @override
  Widget build(BuildContext context) {
    if (findings.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            beside ? sayingIndent(context) : 16,
            0,
            16,
            10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final finding in findings) _Said(finding)],
          ),
        ),
        const Hairline(),
      ],
    );
  }
}

/// One Finding: the severity, the subject, the sentence. A `fail` reads as an
/// error and a `warn` as a note, so arithmetic that does not add up stays
/// distinguishable from something merely unusual.
class _Said extends StatelessWidget {
  const _Said(this.finding);

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colours = theme.colorScheme;
    final failed = finding.severity == Severity.fail;
    final (label, detail) = sayingFor(AppLocalizations.of(context), finding);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              failed ? Icons.error_outline : Icons.info_outline,
              // The size and tier the card drew these at before the form was
              // redrawn around them. A Finding is a sentence about the field
              // above it rather than a column head, so it is not set at a
              // tracked mark's size in the third tier of ink.
              size: 20,
              color: failed ? colours.error : colours.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: atItsWeight(
                    theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A photograph that was never a receipt. Said across the whole form, because
/// there is no field to go and fix — and the Check short-circuits on it, so it
/// never shares the screen with anything.
class _WholePhoto extends StatelessWidget {
  const _WholePhoto(this.finding);

  final NotAReceipt finding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colours = theme.colorScheme;
    final (label, detail) = sayingFor(AppLocalizations.of(context), finding);

    return Container(
      width: double.infinity,
      color: colours.errorContainer,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colours.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colours.onErrorContainer,
                  ),
                ),
                Text(
                  detail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colours.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Refused extends StatelessWidget {
  const _Refused(this.reason);

  final String reason;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context).reviewRefused),
        Text(reason, style: Theme.of(context).textTheme.bodySmall),
      ],
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
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);

    final theme = Theme.of(context);

    // A card each would put a box back on a form the design took the boxes
    // off. The rule under the row does the same work: the rows are a table.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Celled(
                      child: TextField(
                        controller: controllers.description,
                        style: atItsWeight(
                          theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        decoration: asACell(
                          context,
                          words.reviewLineDescription,
                        ),
                        onChanged: (value) =>
                            onCorrected(LineItemField.description, value),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: words.reviewRemoveLineItem,
                    iconSize: 18,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close),
                    onPressed: onRemoved,
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _number(
                      context,
                      controllers.quantity,
                      words.reviewLineQuantity,
                      LineItemField.quantity,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _number(
                      context,
                      controllers.unitPrice,
                      words.reviewLineUnitPrice,
                      LineItemField.unitPrice,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _number(
                      context,
                      controllers.amount,
                      words.reviewLineAmount,
                      LineItemField.amount,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Closed(
                name: ReviewField.category.name,
                label: ReviewField.category.labelIn(words),
                value: category,
                options: categories,
                whenUnrecognised: 'other',
                copy: (slug) => categoryLabel(words, slug),
                cell: true,
                onChosen: (value) => onCorrected(LineItemField.category, value),
              ),
            ],
          ),
        ),
        const Hairline(),
      ],
    );
  }

  Widget _number(
    BuildContext context,
    TextEditingController controller,
    String label,
    LineItemField field,
  ) => Celled(
    child: TextField(
      controller: controller,
      // Left, unlike the figures on the form above: these are three cells with
      // a name over each rather than a column read down, and a figure pushed to
      // the far side of its cell reads away from the name it belongs to.
      style: asFigures(
        Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      decoration: asACell(context, label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (value) => onCorrected(field, value),
    ),
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
