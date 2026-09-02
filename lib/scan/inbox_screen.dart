import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../l10n/app_localizations.dart';
import '../on_screen.dart';
import '../review/review_bloc.dart';
import '../review/review_screen.dart';
import 'inbox_bloc.dart';

/// Every Scan the user has not yet Reviewed, with the state it is sitting in.
/// Nothing here is a dialog: a Scan's whole story is a line in this list.
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Inbox')),
    body: BlocBuilder<InboxBloc, InboxState>(
      builder: (context, state) => switch (state) {
        InboxLoading() => const Center(child: CircularProgressIndicator()),
        InboxReady(scans: []) => const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('No receipts waiting.', textAlign: TextAlign.center),
          ),
        ),
        InboxReady(:final scans) => ListView.separated(
          itemCount: scans.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, index) => _ScanTile(scans[index]),
        ),
      },
    ),
  );
}

class _ScanTile extends StatelessWidget {
  const _ScanTile(this.scan);

  final Scan scan;

  /// A photo the Model says is not a receipt has nothing to Review, so the
  /// only thing offered for it is getting rid of it.
  bool get _discarding => scan.state == ScanState.notReceipt;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final (saying, next) = _saying(words, scan);
    return ListTile(
      isThreeLine: next != null,
      leading: const Icon(Icons.receipt_long),
      title: Text(saying),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Photographed ${asMoment(words, scan.capturedAt)}'),
          if (next != null) Text(next),
        ],
      ),
      onTap: scan.state == ScanState.extracted ? () => _review(context) : null,
      trailing: switch (scan.state) {
        ScanState.notReceipt => FilledButton.tonal(
          onPressed: () => _abandon(context),
          child: const Text('Discard'),
        ),
        ScanState.extracted => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () => _review(context),
              child: const Text('Review'),
            ),
            _abandonButton(context),
          ],
        ),
        _ when scan.canBeReadAgain => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.tonal(
              onPressed: () =>
                  context.read<InboxBloc>().add(ScanReadAgain(scan.id)),
              child: const Text('Read again'),
            ),
            _abandonButton(context),
          ],
        ),
        _ => _abandonButton(context),
      },
    );
  }

  Widget _abandonButton(BuildContext context) => IconButton(
    tooltip: 'Abandon this Scan',
    icon: const Icon(Icons.delete_outline),
    onPressed: () => _abandon(context),
  );

  void _review(BuildContext context) {
    final review = context.read<ReviewBloc>()..add(ScanReviewStarted(scan));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BlocProvider.value(value: review, child: const ReviewScreen()),
      ),
    );
  }

  Future<void> _abandon(BuildContext context) async {
    final inbox = context.read<InboxBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          _discarding
              ? 'Discarding this photo deletes it from the phone.'
              : 'Abandoning this Scan deletes its photo from the phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_discarding ? 'Discard' : 'Abandon'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) inbox.add(ScanAbandoned(scan.id));
  }
}

/// What the Inbox says about a Scan: what happened, and what happens next
/// where the user would otherwise have to guess. The two travel together —
/// every way a Scan can fail means something different to the user and wants
/// something different done about it — so they are read off one switch rather
/// than two that could drift apart.
/// Still English, and ticket 07's. It takes the words only because the
/// moment a Scan was photographed reads the way the language reads dates.
(String, String?) _saying(AppLocalizations words, Scan scan) =>
    switch (scan.state) {
      ScanState.captured => ('Waiting to be read', null),
      ScanState.extracting => ('Being read', null),
      ScanState.extracted => ('Ready to Review', null),
      ScanState.notReceipt => ('This does not look like a receipt', null),
      ScanState.committed => ('In your Ledger', null),
      ScanState.capped => (
        "Today's Scans are used up",
        switch (scan.allowanceResetsAt) {
          final resetsAt? => 'More Scans at ${asMoment(words, resetsAt)}.',
          null => 'More Scans tomorrow.',
        },
      ),
      ScanState.failed => switch (scan.failure) {
        ScanFailure.refused => (
          'The Model would not read this photo',
          'A clearer photograph is the likeliest fix.',
        ),
        ScanFailure.saidNothing => (
          'The Model answered with nothing at all',
          'Reading it again usually works.',
        ),
        ScanFailure.notLegible => (
          "The Model's answer was not readable",
          'Reading it again usually works.',
        ),
        ScanFailure.outOfReach => (
          'No connection when this was read',
          'It will keep trying on its own.',
        ),
        ScanFailure.modelUnavailable => (
          'The Model was not available',
          'This usually passes. Read it again in a minute.',
        ),
        ScanFailure.tokenRefused => (
          'Your sign-in was not accepted',
          'Sign in again, then read it again.',
        ),
        ScanFailure.imageNotAccepted => (
          'This photo could not be sent',
          'Photograph the receipt again.',
        ),
        // A record written by a version of the app that could not yet say why.
        null => ('This could not be read', null),
      },
    };
