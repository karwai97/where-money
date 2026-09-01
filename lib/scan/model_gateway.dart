/// The boundary to the Worker, and the second of the two things this project
/// fakes. Everything below the seam is bytes in and a typed answer out; the
/// key, the prompt and the schema are the Worker's and are not expressible
/// here.
library;

import 'dart:typed_data';

import 'package:where_money_core/where_money_core.dart';

/// What one call to the Model came back with. Every member of the failure
/// taxonomy is one of these rather than a thrown exception, because each one
/// becomes a state a Scan sits in where the user can see it.
///
/// Two answers, because the two endpoints cannot be answered with each other's
/// news: a Scan is never handed a Recap, and a month is never handed a
/// receipt. The failures below sit under both, so the taxonomy stays one
/// closed set rather than two that can drift.
sealed class ScanAnswer {}

sealed class RecapAnswer {}

/// The ways a call can come back with no news at all. Shared, because none of
/// them is about what was asked for: the allowance, the token, the connection
/// and the far end are the same four whichever endpoint was called.
sealed class ModelFailure implements ScanAnswer, RecapAnswer {
  const ModelFailure();
}

/// The Model read a receipt. [outcome] carries which kind of answer it was — a
/// read Extraction, a refusal, silence, or text that was not the promised
/// JSON.
final class ModelAnswered implements ScanAnswer {
  const ModelAnswered(this.outcome);

  final ExtractionOutcome outcome;
}

/// The Model wrote a month up, or said nothing worth printing.
final class RecapAnswered implements RecapAnswer {
  const RecapAnswered(this.outcome);

  final RecapOutcome outcome;
}

/// Today's allowance is used up. [resetsAt] is when it is not, so the Inbox can
/// say when rather than sorry.
final class AllowanceSpent extends ModelFailure {
  const AllowanceSpent({this.resetsAt});

  final DateTime? resetsAt;
}

/// The Worker would not take the caller's token. Signing in again is the only
/// thing that answers this.
final class TokenRefused extends ModelFailure {
  const TokenRefused(this.reason);

  final String reason;
}

/// Nothing got through from this phone — no signal, or the Worker never
/// answered. The Scan is untouched, and what answers this is waiting.
final class ModelOutOfReach extends ModelFailure {
  const ModelOutOfReach(this.detail);

  final String detail;
}

/// The Worker answered, and the answer was that it could not do it: the Model
/// was down, Google's signing keys were unreachable, or something nobody has
/// seen before. Separate from [ModelOutOfReach] because the user has a
/// connection and telling them otherwise is a lie, and because the call
/// reached the Worker and so has already spent an attempt.
final class ModelUnavailable extends ModelFailure {
  const ModelUnavailable(this.detail);

  final String detail;
}

/// The Worker would not take the image: not base64, or past the size it
/// accepts. Sending the same bytes again will not help, which is what
/// separates this from [ModelOutOfReach] and what keeps ticket 08's automatic
/// retry off it. A Scan's alone — a Rollup the Worker will not take is this
/// app disagreeing with itself, not a photograph.
final class ImageNotAccepted implements ScanAnswer {
  const ImageNotAccepted(this.detail);

  final String detail;
}

abstract interface class ModelGateway {
  /// Reads a stored receipt image. Never throws: a failure is an answer.
  ///
  /// [language] is the words the Model writes itself — the reason it gives for
  /// a Category, and anything it wants Reviewed. What it transcribes off the
  /// receipt is not translated.
  Future<ScanAnswer> extract(Uint8List receipt, {required String language});

  /// Writes a month up from its Rollup, which is the whole of what is sent —
  /// [rollupJson] is `rollupPrompt`'s. Never throws, for the same reason.
  Future<RecapAnswer> recap(String rollupJson, {required String language});
}

/// A call at a time, on both of them, rather than a language the gateway
/// holds: it is built once at startup before anyone has signed in, so a field
/// here would be stale the moment the Setting changed. The token callback
/// above is not a precedent for one — it exists because tokens expire.
