import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../l10n/app_localizations.dart';
import '../on_screen.dart';
import '../review/review_bloc.dart';
import '../review/review_screen.dart';
import 'inbox_bloc.dart';
import 'inbox_copy.dart';

/// Every Scan the user has not yet Reviewed, with the state it is sitting in.
/// Nothing here is a dialog: a Scan's whole story is a line in this list.
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(words.inboxTitle)),
      body: BlocBuilder<InboxBloc, InboxState>(
        builder: (context, state) => switch (state) {
          InboxLoading() => Center(
            child: CircularProgressIndicator(
              semanticsLabel: words.inboxLoading,
            ),
          ),
          InboxReady(scans: []) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(words.inboxEmpty, textAlign: TextAlign.center),
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
    final (saying, next) = sayingFor(words, scan);
    return ListTile(
      isThreeLine: next != null,
      leading: const Icon(Icons.receipt_long),
      title: Text(saying),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(words.inboxPhotographed(asMoment(words, scan.capturedAt))),
          if (next != null) Text(next),
        ],
      ),
      onTap: scan.state == ScanState.extracted ? () => _review(context) : null,
      trailing: switch (scan.state) {
        ScanState.notReceipt => FilledButton.tonal(
          onPressed: () => _abandon(context),
          child: Text(words.inboxDiscard),
        ),
        ScanState.extracted => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () => _review(context),
              child: Text(words.inboxReview),
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
              child: Text(words.inboxReadAgain),
            ),
            _abandonButton(context),
          ],
        ),
        _ => _abandonButton(context),
      },
    );
  }

  Widget _abandonButton(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).inboxAbandonThisScan,
    icon: const Icon(Icons.delete_outline),
    onPressed: () => _abandon(context),
  );

  void _review(BuildContext context) {
    context.read<ReviewBloc>().add(ScanReviewStarted(scan));
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ReviewScreen()));
  }

  Future<void> _abandon(BuildContext context) async {
    final inbox = context.read<InboxBloc>();
    final words = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          _discarding
              ? words.inboxDiscardingDeletesThePhoto
              : words.inboxAbandoningDeletesThePhoto,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(words.inboxKeep),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_discarding ? words.inboxDiscard : words.inboxAbandon),
          ),
        ],
      ),
    );

    if (confirmed ?? false) inbox.add(ScanAbandoned(scan.id));
  }
}
