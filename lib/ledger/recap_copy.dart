import '../l10n/app_localizations.dart';
import 'ledger_bloc.dart';

/// The one exhaustive switch from a [WhyNoRecap] to words, so adding a reason
/// without copy is a compile error rather than a blank line on the screen. The
/// same shape as `finding_copy.dart` and for the same reason (ADR-0007).
String whyThereIsNoRecap(AppLocalizations words, WhyNoRecap why) =>
    switch (why) {
      WhyNoRecap.refused => words.rollupRecapRefused,
      WhyNoRecap.nothingToSay => words.rollupRecapNothingToSay,
      WhyNoRecap.allowanceSpent => words.rollupRecapAllowanceSpent,
      WhyNoRecap.tokenRefused => words.rollupRecapTokenRefused,
      WhyNoRecap.outOfReach => words.rollupRecapOutOfReach,
      WhyNoRecap.modelUnavailable => words.rollupRecapModelUnavailable,
    };
