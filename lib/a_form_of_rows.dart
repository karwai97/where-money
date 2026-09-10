/// The vocabulary C5 Graphite draws a form of rows with: no boxes, a field's
/// name as a tracked mark in a column of its own, its value in a filled cell
/// beside it, a hairline between rows and a filled strip over each group.
///
/// Read by Review, which draws an Extraction this way, and by Settings, which
/// draws its Settings the same — so it sits here with the app's other shared
/// presentation rather than under either of them, for the reason
/// `choosing_a_currency.dart` does. Two definitions of a cell would drift.
///
/// The bar over such a screen is here as well. It is not a row, but it is the
/// other thing the two screens have to draw identically to read as one app.
library;

import 'package:flutter/material.dart';
import 'package:where_money_core/where_money_core.dart';

import 'l10n/app_localizations.dart';
import 'on_screen.dart';

import 'settings/themes.dart';

/// The bar the Ledger wears, so every screen reads as one app: the name of
/// the screen as a tracked upper case mark rather than as a heading.
///
/// [leading] is here rather than left to a second bar composed by hand: the
/// currency sheet closes with a button, and a bar built beside this one is a
/// second definition of the app's title style.
AppBar barNamed(BuildContext context, String title, {Widget? leading}) =>
    AppBar(
      leading: leading,
      title: Text(
        cased(AppLocalizations.of(context), title),
        style: asScreenName(Theme.of(context).textTheme.labelLarge),
      ),
    );

/// The label column's width, in the type's own scale rather than in pixels: a
/// reader who has turned text size up gets a wider column instead of a
/// clipped label.
double labelWidth(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(88);

/// How far a sentence under a row is indented to sit under the value it is
/// about rather than under the field's name — a Finding on Review, what a
/// Setting governs on Settings. Capped, because at twice the text size the
/// column it is lining up with is wider than the sentence deserves.
double sayingIndent(BuildContext context) =>
    (labelWidth(context) + labelGap).clamp(0, 120);

/// What [InputDecorator] leaves between the label column and the field.
const double labelGap = 16;

/// Every field wears this: no box, the name in a tracked mark in a column of
/// its own, and the input beside it. The rule under the pair is [Ruled]'s,
/// because a Finding can take it over.
///
/// The name goes in `icon` — the one slot [InputDecorator] puts outside the
/// input and to the left of it — so that a field is still reached by its name
/// however it is drawn.
InputDecoration asARow(
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
    icon: inTheLabelColumn(context, label, colour: colour),
    hintText: asking,
    hintStyle: theme.textTheme.bodyMedium?.copyWith(
      color: colours.onSurfaceVariant,
    ),
    // The cell. Every value that answers a tap is drawn as one, and the fill
    // is the whole affordance: without it a field you type into and a row you
    // can only read are the same object.
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

/// A field's name where the design puts every field's name: a tracked upper
/// case mark in a column of its own, two lines at most.
///
/// Excluded from what is read out, because the case is typography rather than
/// wording — whatever draws this says the name itself, in the case the message
/// files hold it in. The one definition, so a row composed by hand and a row
/// [asARow] decorates cannot drift into two columns.
Widget inTheLabelColumn(BuildContext context, String label, {Color? colour}) =>
    ExcludeSemantics(
      child: SizedBox(
        width: labelWidth(context),
        child: Text(
          cased(AppLocalizations.of(context), label),
          maxLines: 2,
          style: asAMark(Theme.of(context), colour: colour),
        ),
      ),
    );

/// A currency code, wherever one is set at reading size: the field that shows
/// the chosen one, the search that is typed in codes, and every row of the
/// sheet those two open. Monospaced beside the amounts it units, for the
/// reason [asFigures] gives. The one place the code's face is decided.
TextStyle? asACode(ThemeData theme) => asFigures(
  theme.textTheme.bodyMedium?.copyWith(
    color: theme.colorScheme.onSurface,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  ),
);

/// The mark the design labels a column with, in the second tier of ink
/// unless the Check wants it louder. The one place the face, the weight, the
/// tracking and the colour of a field's name are decided.
TextStyle? asAMark(ThemeData theme, {Color? colour}) => asTrackedMark(
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

/// Reports whether anything inside it holds focus. Two things are drawn as
/// cells without being the widget that takes the focus — a Line Item's cell is
/// painted around its field, and the currency's is an [InputDecorator] told
/// what to draw — and both need the answer.
class Focused extends StatefulWidget {
  const Focused({required this.builder, super.key});

  final Widget Function(BuildContext context, bool focused) builder;

  @override
  State<Focused> createState() => _FocusedState();
}

class _FocusedState extends State<Focused> {
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
class Celled extends StatelessWidget {
  const Celled({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colours = Theme.of(context).colorScheme;

    return Focused(
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
InputDecoration asACell(BuildContext context, String label) {
  final theme = Theme.of(context);
  final style = asAMark(theme);

  return InputDecoration(
    labelText: cased(AppLocalizations.of(context), label),
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

/// One row: the density the Ledger's list is set at, and the hairline under
/// it that stands in for the box Material would draw.
class Ruled extends StatelessWidget {
  const Ruled({
    required this.child,
    super.key,
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
        Hairline(painted: ruled),
      ],
    );
  }
}

/// The rule between rows, and the pixel it stands in.
class Hairline extends StatelessWidget {
  const Hairline({this.painted = true, super.key});

  final bool painted;

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    color: painted ? Theme.of(context).colorScheme.outlineVariant : null,
  );
}

/// What the rows under it are, said once above them — the strip the Ledger
/// puts over its list, so a row does not have to carry a heading of its own.
class Head extends StatelessWidget {
  const Head(this.text, {this.trailing, this.ruled = true, super.key});

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
    final style = asAMark(theme);

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
          Expanded(
            child: Text(
              cased(AppLocalizations.of(context), text),
              style: style,
            ),
          ),
          if (trailing case final String count)
            Text(count, style: asFigures(style)),
        ],
      ),
    );
  }
}

/// A field whose value can only ever come from a closed list. There is no
/// free-text path into a Category by design — see ADR-0005.
///
/// Generic over what the list holds, because not every closed set in the app
/// is a set of strings: a Category, a payment method and a language are, and
/// the Theme is a [ThemeMode]. [copy] is how an arbitrary [T] is drawn and
/// [name] is how it is keyed, so this needs to know nothing else about it.
class Closed<T> extends StatelessWidget {
  const Closed({
    required this.name,
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.whenUnrecognised,
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

  /// What this field is called in the code rather than in front of a reader:
  /// the Review field's wire name, or the Setting's own. It is what the key is
  /// built from, so it has to be the one part of a row that does not change
  /// when somebody changes language mid-form — which rules the label out.
  final String name;
  final String label;
  final T value;
  final List<T> options;

  /// What to show when [value] is not one of [options] — a Category the Model
  /// invented, or a language stored by a build that knew more of them than
  /// this one does. Said by the caller because only the caller knows: a
  /// taxonomy has a catch-all to fall to, and a preference has a default.
  final T whenUnrecognised;

  final String Function(T) copy;
  final void Function(T) onChosen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final field = Semantics(
      label: label,
      child: DropdownButtonFormField<T>(
        // Seeded rather than driven, so the key is what keeps what is shown in
        // step with the Extraction after a Line Item above it is removed.
        key: ValueKey('$name:$value'),
        initialValue: options.contains(value) ? value : whenUnrecognised,
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
            ? asACell(context, label)
            : asARow(context, label, marked: marked),
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

    return cell ? Celled(child: field) : field;
  }
}

/// A field whose value is chosen somewhere else and comes back: the row shows
/// what is stored and opens the picker. Deliberately not typeable — a
/// currency that can be typed is a currency that can be a typo.
class Chosen extends StatelessWidget {
  const Chosen({
    required this.label,
    super.key,
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
    // The only field drawn this way is the currency.
    final style = asACode(theme);

    return Semantics(
      label: label,
      button: true,
      child: Focused(
        builder: (context, focused) => InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: asARow(context, label, marked: marked),
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
