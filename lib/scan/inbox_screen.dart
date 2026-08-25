import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

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
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.receipt_long),
    title: Text(_waitingOn(scan.state)),
    subtitle: Text('Photographed ${asMoment(scan.capturedAt)}'),
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
      _ => _abandonButton(context),
    },
  );

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

/// One line a user can act on, per state.
String _waitingOn(ScanState state) => switch (state) {
  ScanState.captured => 'Waiting to be read',
  ScanState.extracting => 'Being read',
  ScanState.extracted => 'Ready to Review',
  ScanState.failed => 'Could not be read',
  ScanState.capped => 'Today\'s Scans are used up',
  ScanState.notReceipt => 'This does not look like a receipt',
  ScanState.committed => 'In your Ledger',
};
