/// Picking a currency. Read by Review, which puts a currency on an Expense,
/// and by Settings, which puts one on the whole Ledger — so it sits here with
/// the app's other shared presentation rather than under either of them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import 'l10n/app_localizations.dart';
import 'ledger/ledger_bloc.dart';
import 'settings/settings_cubit.dart';

/// Asks for a currency and answers with a code, or with null if the user came
/// back without one.
///
/// A full-height sheet rather than a menu in an overlay: a hundred and eighty
/// rows dropped over a form is a small scrolling window fighting the keyboard,
/// and a sheet owns the screen and has room for a head.
Future<String?> chooseACurrency(BuildContext context) {
  final head = _alreadyInUse(context);

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        FractionallySizedBox(heightFactor: 1, child: _Sheet(head: head)),
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
List<String> _alreadyInUse(BuildContext context) {
  final expenses = context.read<LedgerBloc>().state.expenses;

  return {
    ?context.read<SettingsCubit>().state.homeCurrency,
    for (final expense in expenses) expense.currency,
  }.where(isoCurrencies.contains).toList();
}

class _Sheet extends StatefulWidget {
  const _Sheet({required this.head});

  final List<String> head;

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

    return Scaffold(
      appBar: AppBar(
        title: Text(words.currencyChooseTitle),
        leading: IconButton(
          tooltip: words.currencyClose,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              // A code is upper-case wherever it is written, so the field
              // matches what the list shows rather than what was typed.
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: words.currencySearch,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toUpperCase()),
            ),
          ),
          Expanded(
            child: head.isEmpty && tail.isEmpty
                ? Center(child: Text(words.currencyNoMatch(_query)))
                : ListView(
                    children: [
                      if (head.isNotEmpty) ...[
                        _Heading(words.currencyYours),
                        for (final code in head) _Code(code),
                        const Divider(),
                      ],
                      if (tail.isNotEmpty) ...[
                        _Heading(words.currencyAll),
                        for (final code in tail) _Code(code),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

/// One row. The code alone: it reads the same in every language and it is what
/// the receipt prints, so a name beside it would be the app's words over the
/// user's.
class _Code extends StatelessWidget {
  const _Code(this.code);

  final String code;

  @override
  Widget build(BuildContext context) =>
      ListTile(title: Text(code), onTap: () => Navigator.of(context).pop(code));
}
