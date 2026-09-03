import 'package:where_money_core/where_money_core.dart';

import '../l10n/app_localizations.dart';
import '../on_screen.dart';

/// What the Inbox says about a Scan: what happened, and what happens next
/// where the user would otherwise have to guess. The two travel together —
/// every way a Scan can fail means something different to the user and wants
/// something different done about it — so they are read off one switch rather
/// than two that could drift apart.
(String, String?) sayingFor(AppLocalizations words, Scan scan) =>
    switch (scan.state) {
      ScanState.captured => (words.inboxWaitingToBeRead, null),
      ScanState.extracting => (words.inboxBeingRead, null),
      ScanState.extracted => (words.inboxReadyToReview, null),
      ScanState.notReceipt => (words.inboxNotAReceipt, null),
      ScanState.committed => (words.inboxCommitted, null),
      ScanState.capped => (
        words.inboxCapped,
        switch (scan.allowanceResetsAt) {
          final resetsAt? => words.inboxMoreScansAt(asMoment(words, resetsAt)),
          null => words.inboxMoreScansTomorrow,
        },
      ),
      ScanState.failed => switch (scan.failure) {
        ScanFailure.refused => (
          words.inboxFailureRefused,
          words.inboxFailureRefusedNext,
        ),
        ScanFailure.saidNothing => (
          words.inboxFailureSaidNothing,
          words.inboxFailureSaidNothingNext,
        ),
        ScanFailure.notLegible => (
          words.inboxFailureNotLegible,
          words.inboxFailureNotLegibleNext,
        ),
        ScanFailure.outOfReach => (
          words.inboxFailureOutOfReach,
          words.inboxFailureOutOfReachNext,
        ),
        ScanFailure.modelUnavailable => (
          words.inboxFailureModelUnavailable,
          words.inboxFailureModelUnavailableNext,
        ),
        ScanFailure.tokenRefused => (
          words.inboxFailureTokenRefused,
          words.inboxFailureTokenRefusedNext,
        ),
        ScanFailure.imageNotAccepted => (
          words.inboxFailureImageNotAccepted,
          words.inboxFailureImageNotAcceptedNext,
        ),
        // A record written by a version of the app that could not yet say why.
        null => (words.inboxFailureUnsaid, null),
      },
    };
