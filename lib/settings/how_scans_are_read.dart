import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../l10n/app_localizations.dart';
import '../ledger/ledger_bloc.dart';
import '../on_screen.dart';

/// The operator's half of Settings: what this launch asks a Scan to be read
/// with, and how well that has been going. It sits below the user's own
/// choices rather than among them, because a Knob is not a Setting — one is a
/// decision about how the Model is used, the other about this phone.
class HowScansAreRead extends StatelessWidget {
  const HowScansAreRead({super.key, required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(words.settingsScansHeading),
        _Line(words.settingsScansModel(knobs.model)),
        _Line(words.settingsScansEffort(knobs.effort)),
        _Line(words.settingsScansLongEdge(knobs.longEdge)),
        _Line(words.settingsScansDailyCap(knobs.dailyCap)),
        _Note(words.settingsScansFromConsole),
        _Note(words.settingsScansNotEnforced),
      ],
    );
  }
}

/// The Corrected Fields tally: how often Review had to change what the Model
/// read. It is the only evidence that answers whether the model above is
/// accurate enough, which is why it sits directly beneath it.
class WhatReviewHadToCorrect extends StatelessWidget {
  const WhatReviewHadToCorrect({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LedgerBloc>().state;
    final tally = CorrectedFields.across(
      state is LedgerReady ? state.expenses : const [],
    );

    final words = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(words.settingsCorrectedHeading),
        if (tally.scanned == 0)
          _Note(words.settingsCorrectedNothingYet)
        else ...[
          _Line(words.settingsCorrectedTally(tally.scanned, tally.clean)),
          for (final MapEntry(:key, :value) in tally.byField.entries)
            _Line(
              words.settingsCorrectedField(
                reviewFieldLabel(words, key),
                value,
                tally.scanned,
              ),
            ),
          _Note(words.settingsCorrectedManualExcluded),
        ],
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
    child: Text(text),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}
