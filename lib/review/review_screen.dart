import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

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
          appBar: _barNamed(context, words.reviewTitleTyped),
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

/// The bar the Ledger wears, so the two screens read as one app: the name of
/// the screen as a tracked upper case mark rather than as a heading.
AppBar _barNamed(BuildContext context, String title) => AppBar(
  title: Text(
    title.toUpperCase(),
    style: asScreenName(Theme.of(context).textTheme.labelLarge),
  ),
);

/// The label column's width, in the type's own scale rather than in pixels: a
/// reader who has turned text size up gets a wider column instead of a
/// clipped label.
double _labelWidth(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(88);

/// How far a Finding is indented to sit under the value it is about rather
/// than under the field's name. Capped, because at twice the text size the
/// column it is lining up with is wider than the sentence deserves.
double _sayingIndent(BuildContext context) =>
    (_labelWidth(context) + _gap).clamp(0, 120);

/// What [InputDecorator] leaves between the label column and the field.
const double _gap = 16;

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
      appBar: _barNamed(context, _titleOf(state, words)),
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
                  _Head(words.reviewSectionWhatThisWas),
                  _text(words, noted, ReviewField.merchant),
                  _under(
                    noted[ReviewField.purchasedAt],
                    _Ruled(
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
                    _Ruled(
                      ruled: noted[ReviewField.category].isEmpty,
                      child: _explained(
                        state.extraction.categoryReason.isEmpty
                            ? ''
                            : words.reviewCategoryReason(
                                state.extraction.categoryReason,
                              ),
                        _Closed(
                          name: ReviewField.category.name,
                          label: ReviewField.category.labelIn(words),
                          value: state.extraction.category,
                          options: categories,
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
                    _Ruled(
                      ruled: noted[ReviewField.paymentMethod].isEmpty,
                      child: _Closed(
                        name: ReviewField.paymentMethod.name,
                        label: ReviewField.paymentMethod.labelIn(words),
                        value: state.extraction.paymentMethod,
                        options: paymentMethods,
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
                  _Head(words.reviewSectionWhatItCost),
                  _under(
                    noted[ReviewField.currency],
                    _Ruled(
                      ruled: noted[ReviewField.currency].isEmpty,
                      child: _Chosen(
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
                  _Head(
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
              padding: EdgeInsets.only(left: _sayingIndent(context)),
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
      _Ruled(
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
        decoration: _asARow(
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

/// Every field on the form wears this: no box, the name in a tracked mark in
/// a column of its own, and the input beside it. The rule under the pair is
/// [_Ruled]'s, because a Finding can take it over.
///
/// The name goes in `icon` — the one slot [InputDecorator] puts outside the
/// input and to the left of it — so that a field is still reached by its name
/// however it is drawn.
InputDecoration _asARow(
  BuildContext context,
  String label, {
  Severity? marked,
  String? asking,
}) {
  final theme = Theme.of(context);
  final colours = theme.colorScheme;
  // What the Check said, on the name of the field it said it about. Never on
  // its own: the sentence under the row says the same thing in words.
  final colour = switch (marked) {
    Severity.fail => colours.error,
    Severity.warn => colours.primary,
    null => colours.outline,
  };

  // And on the cell's edge, where a warn cannot wear the accent: the accent
  // is what focus means, and a form with three warns on it would have looked
  // like a form with three cursors in it.
  final edge = switch (marked) {
    Severity.fail => colours.error,
    Severity.warn => colours.outline,
    null => null,
  };

  return InputDecoration(
    icon: ExcludeSemantics(
      child: SizedBox(
        width: _labelWidth(context),
        child: Text(
          label.toUpperCase(),
          maxLines: 2,
          style: _mark(theme, colour: colour),
        ),
      ),
    ),
    hintText: asking,
    hintStyle: theme.textTheme.bodyMedium?.copyWith(
      color: colours.onSurfaceVariant,
    ),
    // The cell. Every value on this form that answers a tap is drawn as one,
    // and the fill is the whole affordance: without it a field you type into
    // and a row you can only read are the same object.
    filled: true,
    fillColor: colours.surfaceContainerHighest,
    border: _cell(),
    // An edge only ever says something about state: what the Check said,
    // until the field takes focus and says the more useful thing.
    enabledBorder: _cell(edge),
    focusedBorder: _cell(colours.primary),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    constraints: const BoxConstraints(minHeight: 34),
  );
}

/// The mark the design labels a column with, in the second tier of ink
/// unless the Check wants it louder. The one place the face, the weight, the
/// tracking and the colour of a field's name are decided.
TextStyle? _mark(ThemeData theme, {Color? colour}) => asTrackedMark(
  theme.textTheme.labelSmall?.copyWith(
    color: colour ?? theme.colorScheme.outline,
  ),
);

/// The shape of a cell. Never [BorderSide.none] for the states that draw no
/// edge: a side is width, and a cell that gave one up on focus would move the
/// text under the cursor by a pixel.
InputBorder _cell([Color? edge]) => OutlineInputBorder(
  borderRadius: const BorderRadius.all(Radius.circular(6)),
  borderSide: BorderSide(color: edge ?? Colors.transparent),
);

/// Reports whether anything inside it holds focus. Two things on this form
/// are drawn as cells without being the widget that takes the focus — a Line
/// Item's cell is painted around its field, and the currency's is an
/// [InputDecorator] told what to draw — and both need the answer.
class _Focused extends StatefulWidget {
  const _Focused({required this.builder});

  final Widget Function(BuildContext context, bool focused) builder;

  @override
  State<_Focused> createState() => _FocusedState();
}

class _FocusedState extends State<_Focused> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    // Not a stop on the way round the form: this is here to watch, not to be
    // landed on.
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (focused) => setState(() => _focused = focused),
    child: widget.builder(context, _focused),
  );
}

/// A Line Item's cell, painted from outside. Its name is set over the value
/// rather than beside it, and `InputDecoration.icon` — the one slot that sits
/// outside the fill — puts a name to the left, so the fill for these is drawn
/// around the field instead of by it.
class _Cell extends StatelessWidget {
  const _Cell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colours = Theme.of(context).colorScheme;

    return _Focused(
      builder: (context, focused) => Container(
        // Taller than a row's 34: this one holds the field's name over its
        // value rather than beside it.
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
        decoration: BoxDecoration(
          color: colours.surfaceContainerHighest,
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          // Always drawn, transparent or not, for the reason [_cell] gives.
          border: Border.all(
            color: focused ? colours.primary : Colors.transparent,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// One cell of a Line Item's row: the same tracked mark, set over the value
/// instead of beside it. Three of these fit across a phone and three label
/// columns do not.
InputDecoration _asACell(BuildContext context, String label) {
  final theme = Theme.of(context);
  final style = _mark(theme);

  return InputDecoration(
    labelText: label.toUpperCase(),
    // Always up, and at the size it is written: Material floats a label at
    // three quarters of its style, and a mark this small cannot spare it.
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: style,
    floatingLabelStyle: style,
    border: InputBorder.none,
    isDense: true,
    contentPadding: const EdgeInsets.only(top: 4),
  );
}

/// One row of the form: the density the Ledger's list is set at, and the
/// hairline under it that stands in for the box Material would draw.
class _Ruled extends StatelessWidget {
  const _Ruled({
    required this.child,
    this.vertical = 7,
    this.ruled = true,
    this.above = false,
  });

  final Widget child;

  /// Tightened by the one row that shares itself with a 44px button: the
  /// Date's calendar is taller than a cell, and this row's ordinary padding
  /// on top of it would push the row past the rhythm the others are set to.
  final double vertical;

  /// Given up when a Finding follows, which then carries the rule instead.
  final bool ruled;

  /// A heavier rule over the row as well, which the design gives the one row
  /// the rows above it add up to. Material names no rule heavier than a
  /// divider; this is where the design's value landed when the palette was
  /// mapped onto the scheme.
  final bool above;

  @override
  Widget build(BuildContext context) {
    final colours = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: vertical),
          decoration: BoxDecoration(
            border: Border(
              top: above
                  // Not `surfaceContainerHighest`, which is what a cell is
                  // filled with: at the width of the form that read as a slab
                  // under the figures rather than as a rule over the total.
                  ? BorderSide(color: colours.outline)
                  : BorderSide.none,
            ),
          ),
          child: child,
        ),
        // Always the same pixel high, painted or not. Drawn as a rule under
        // the row rather than as a border on it, because a border is height:
        // a row that gave one up when a Finding appeared under it would move
        // the field the reader is correcting by the width of a hairline.
        _Hairline(painted: ruled),
      ],
    );
  }
}

/// The rule between rows, and the pixel it stands in.
class _Hairline extends StatelessWidget {
  const _Hairline({this.painted = true});

  final bool painted;

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    color: painted ? Theme.of(context).colorScheme.outlineVariant : null,
  );
}

/// What the rows under it are, said once above them — the strip the Ledger
/// puts over its list, so a row does not have to carry a heading of its own.
class _Head extends StatelessWidget {
  const _Head(this.text, {this.trailing, this.ruled = true});

  final String text;

  /// Whether the strip closes with a rule. Off where what comes next is about
  /// the set this head names — the Findings the Check returned about the Line
  /// Items as a whole — for the reason a field's row gives its own rule up: a
  /// rule between the two reads as if the sentence belonged to what follows.
  final bool ruled;

  /// A figure at the far end, where the set has one worth saying: how many
  /// Line Items there are.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colours = theme.colorScheme;
    final style = _mark(theme);

    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colours.surfaceContainer,
        border: Border(
          bottom: ruled
              ? BorderSide(color: colours.outlineVariant)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          // Upper case here is typography, not wording, which is why the
          // message files hold these in sentence case. It is a no-op in
          // Chinese, where the heads read as written.
          Expanded(child: Text(text.toUpperCase(), style: style)),
          if (trailing case final String count)
            Text(count, style: asFigures(style)),
        ],
      ),
    );
  }
}

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
            child: Text(label.toUpperCase()),
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
                  words.reviewToCheck(standing).toUpperCase(),
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
            beside ? _sayingIndent(context) : 16,
            0,
            16,
            10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final finding in findings) _Said(finding)],
          ),
        ),
        const _Hairline(),
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

/// A field whose value can only ever come from a closed list. There is no
/// free-text path into a Category by design — see ADR-0005.
class _Closed extends StatelessWidget {
  const _Closed({
    required this.name,
    required this.label,
    required this.value,
    required this.options,
    required this.copy,
    required this.onChosen,
    this.marked,
    this.cell = false,
  });

  /// What the Check said about this field, worn on the field's name.
  final Severity? marked;

  /// Whether this is one cell of a Line Item's row rather than a row of the
  /// form: the name goes over the value instead of beside it, because three
  /// cells across a phone have no room for a column each.
  final bool cell;

  /// The field's wire name, which is what the key is built from. The label
  /// would do the same job until somebody changed language mid-form.
  final String name;
  final String label;
  final String value;
  final List<String> options;
  final String Function(String) copy;
  final void Function(String) onChosen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final field = Semantics(
      label: label,
      child: DropdownButtonFormField<String>(
        // Seeded rather than driven, so the key is what keeps what is shown in
        // step with the Extraction after a Line Item above it is removed.
        key: ValueKey('$name:$value'),
        initialValue: options.contains(value) ? value : options.last,
        // Said out loud because the default is worse than it looks: a dropdown
        // lays its options out in an IndexedStack and takes the width of the
        // widest one, not of the one selected. At 200% text "Fees & charges"
        // wants 450px inside a 302px field, and the field overflows by the
        // difference whichever Category is chosen. Expanded, the stack takes
        // the field's width instead of the longest label's.
        isExpanded: true,
        style: atItsWeight(
          theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        icon: Icon(
          Icons.arrow_drop_down,
          size: 20,
          color: theme.colorScheme.outline,
        ),
        decoration: cell
            ? _asACell(context, label)
            : _asARow(context, label, marked: marked),
        items: [
          for (final option in options)
            DropdownMenuItem(
              value: option,
              // And a long Category ends in an ellipsis rather than in a
              // stripe, now that the room it gets is the field's.
              child: Text(copy(option), overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (chosen) => chosen == null ? null : onChosen(chosen),
      ),
    );

    return cell ? _Cell(child: field) : field;
  }
}

/// A field whose value is chosen somewhere else and comes back: the row shows
/// what is stored and opens the picker. Deliberately not typeable — a
/// currency that can be typed is a currency that can be a typo.
class _Chosen extends StatelessWidget {
  const _Chosen({
    required this.label,
    required this.value,
    required this.onTap,
    this.marked,
  });

  final String label;

  /// Whatever is stored, including what is not a code at all. Never replaced
  /// with a fallback: the Check is beside this field saying so.
  final String value;

  final VoidCallback onTap;

  final Severity? marked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colours = theme.colorScheme;
    // The only field drawn this way is the currency, and a code is set in the
    // figure face beside the amounts it units.
    final style = asFigures(
      theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
      ),
    );

    return Semantics(
      label: label,
      button: true,
      child: _Focused(
        builder: (context, focused) => InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: _asARow(context, label, marked: marked),
            // Said out loud because an [InputDecorator] is told what to draw
            // rather than working it out: without this the cell's focused
            // edge is unreachable on the one field that is tapped rather
            // than typed into.
            isFocused: focused,
            child: Row(
              children: [
                Expanded(child: Text(value, style: style)),
                Icon(Icons.chevron_right, size: 16, color: colours.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
                    child: _Cell(
                      child: TextField(
                        controller: controllers.description,
                        style: atItsWeight(
                          theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        decoration: _asACell(
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
              _Closed(
                name: ReviewField.category.name,
                label: ReviewField.category.labelIn(words),
                value: category,
                options: categories,
                copy: (slug) => categoryLabel(words, slug),
                cell: true,
                onChosen: (value) => onCorrected(LineItemField.category, value),
              ),
            ],
          ),
        ),
        const _Hairline(),
      ],
    );
  }

  Widget _number(
    BuildContext context,
    TextEditingController controller,
    String label,
    LineItemField field,
  ) => _Cell(
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
      decoration: _asACell(context, label),
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
