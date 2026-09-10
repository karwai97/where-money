/// Picking a currency. Read by Review, which puts a currency on an Expense,
/// and by Settings, which puts one on the whole Ledger — so it sits here with
/// the app's other shared presentation rather than under either of them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import 'a_form_of_rows.dart';
import 'l10n/app_localizations.dart';
import 'ledger/ledger_bloc.dart';
import 'on_screen.dart';
import 'settings/settings_cubit.dart';

/// Asks for a currency and answers with a code, or with null if the user came
/// back without one.
///
/// A full-height sheet rather than a menu in an overlay: a hundred and eighty
/// rows dropped over a form is a small scrolling window fighting the keyboard,
/// and a sheet owns the screen and has room for a head.
///
/// [current] is whatever the caller holds, checked in the list if it is a code
/// and passed over if it is not. Never corrected and never fallen back from: a
/// `???` is a thing for the reader to replace, and checking the Home Currency
/// in its place would say the app had already chosen.
Future<String?> chooseACurrency(BuildContext context, {String? current}) {
  final home = context.read<SettingsCubit>().state.homeCurrency;
  final head = _alreadyInUse(context, home);

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // The Ledger's small radius rather than Material's 28, which is a corner
    // this design draws nowhere else.
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => FractionallySizedBox(
      heightFactor: 1,
      child: _Sheet(head: head, home: home, current: current),
    ),
  );
}

/// The currencies to put at the top: the Home Currency, then the ones this
/// Ledger already holds, most recent first. Read off [LedgerBloc] through the
/// context rather than subscribed to — which row sits where in a picker is
/// presentation, and Review has no business becoming a second reader of the
/// Ledger stream over it.
///
/// Codes only. A `???` in the Ledger is a thing to correct, not a thing to
/// offer somebody else.
List<String> _alreadyInUse(BuildContext context, String? home) {
  final expenses = context.read<LedgerBloc>().state.expenses;

  return {
    ?home,
    for (final expense in expenses) expense.currency,
  }.where(isoCurrencies.contains).toList();
}

class _Sheet extends StatefulWidget {
  const _Sheet({required this.head, required this.home, required this.current});

  final List<String> head;
  final String? home;
  final String? current;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  final _search = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Everything the head does not already carry, in the order the set is
  /// written in, which is alphabetical.
  List<String> get _tail =>
      isoCurrencies.where((code) => !widget.head.contains(code)).toList();

  List<String> _matching(List<String> codes) => _query.isEmpty
      ? codes
      : codes.where((code) => code.contains(_query)).toList();

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final head = _matching(widget.head);
    final tail = _matching(_tail);

    Widget row(String code) =>
        _Code(code, home: code == widget.home, current: code == widget.current);

    // A builder each rather than a list of widgets: a hundred and sixty rows
    // are constructed on every keystroke otherwise, and nobody scrolls to
    // more than a dozen of them.
    final rows = <WidgetBuilder>[
      if (head.isNotEmpty) ...[
        (context) => Head(words.currencyYours),
        for (final code in head) (context) => row(code),
      ],
      if (tail.isNotEmpty) ...[
        // The second head is the break between the groups, so there is no
        // rule between them to draw as well. Its figure counts the rows under
        // it rather than the currencies there are, so it follows the search.
        (context) => Head(words.currencyAll, trailing: '${tail.length}'),
        for (final code in tail) (context) => row(code),
      ],
    ];

    return Scaffold(
      appBar: barNamed(
        context,
        words.currencyChooseTitle,
        leading: IconButton(
          tooltip: words.currencyClose,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          _Search(
            controller: _search,
            onChanged: (value) =>
                setState(() => _query = value.trim().toUpperCase()),
          ),
          if (rows.isEmpty)
            Padding(
              // Under the cell it is about, at the indent the app says
              // things at, rather than centred in the room the list left
              // behind. The [Align] is what gives the padding a width to
              // indent inside: a Column sizes a child to itself, so without
              // it the sentence sits in the middle with the indent wrapped
              // harmlessly around it.
              padding: EdgeInsets.fromLTRB(
                16 + sayingIndent(context),
                12,
                16,
                0,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  words.currencyNoMatch(_query),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                // The sheet opens with the keyboard up over most of the list.
                // Somebody who has started scrolling has stopped typing and
                // is reading codes, so the keyboard goes rather than waiting
                // to be dismissed off the one row it is covering.
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: rows.length,
                itemBuilder: (context, index) => rows[index](context),
              ),
            ),
        ],
      ),
    );
  }
}

/// The search, drawn as a field of the form rather than as a box of Material's
/// own: its name in the label column, what is typed in the cell beside it.
class _Search extends StatelessWidget {
  const _Search({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Ruled(
      // The name goes in `InputDecoration.icon`, which a screen reader skips.
      child: Semantics(
        label: words.currencySearch,
        child: TextField(
          controller: controller,
          autofocus: true,
          // A code is upper-case wherever it is written, so the field matches
          // what the list shows rather than what was typed.
          textCapitalization: TextCapitalization.characters,
          // What is typed is a code, so it is set in the code's face.
          style: asACode(theme),
          cursorColor: theme.colorScheme.primary,
          // No hint: the mark in the label column already says what the cell
          // is for, and a hint under it would be the same words twice.
          decoration: asARow(context, words.currencySearch),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// One row. The code alone: it reads the same in every language and it is what
/// the receipt prints, so a name beside it would be the app's words over the
/// user's. What a row carries besides the code says why it is where it is —
/// the mark on the Home Currency, the check on the one already chosen.
class _Code extends StatelessWidget {
  const _Code(this.code, {required this.home, required this.current});

  final String code;
  final bool home;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colours = theme.colorScheme;

    return Semantics(
      // Null rather than false on the rest: a hundred and sixty rows that
      // each say they are not selected is noisier than the row that says it
      // is.
      selected: current ? true : null,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(code),
        child: Ruled(
          child: Row(
            children: [
              Expanded(child: Text(code, style: asACode(theme))),
              if (home)
                Text(cased(words, words.currencyHome), style: asAMark(theme)),
              if (home && current) const SizedBox(width: labelGap),
              if (current) Icon(Icons.check, size: 18, color: colours.primary),
            ],
          ),
        ),
      ),
    );
  }
}
