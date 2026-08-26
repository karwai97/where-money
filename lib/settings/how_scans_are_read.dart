import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Heading('What each Scan asks for'),
      _Line('Model: ${knobs.model}'),
      _Line('Reasoning effort: ${knobs.effort}'),
      _Line('Image long edge: ${knobs.longEdge} px'),
      _Line('Daily cap: ${knobs.dailyCap} Scans'),
      const _Note(
        'Set in the Firebase console and read when the app starts, so a change '
        'there needs the app closed and opened again, never a new version. '
        'Until one arrives these are the values the app shipped with.',
      ),
      const _Note(
        'What is asked for, not what is enforced: the Worker keeps the list of '
        'models it will call and the ceiling on the daily cap, so a name it '
        'does not know or a cap above its ceiling is quietly replaced at that '
        'end. If a change here has no effect, that is where it went.',
      ),
    ],
  );
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Heading('What Review had to correct'),
        if (tally.scanned == 0)
          const _Note(
            'No receipt has been read yet, so there is nothing to say.',
          )
        else ...[
          _Line(
            '${asReceipts(tally.scanned)} read, '
            '${tally.clean} left alone.',
          ),
          for (final MapEntry(:key, :value) in tally.byField.entries)
            _Line(
              '${reviewFieldLabel(key)}, corrected on '
              '$value of ${tally.scanned}',
            ),
          const _Note(
            'Expenses typed by hand are not counted: those record a change to '
            'every field, against an Extraction that never existed.',
          ),
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
