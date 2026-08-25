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
sealed class ModelAnswer {
  const ModelAnswer();
}

/// The Model answered. [outcome] carries which kind of answer it was — a read
/// Extraction, a refusal, silence, or text that was not the promised JSON.
final class ModelAnswered extends ModelAnswer {
  const ModelAnswered(this.outcome);

  final ExtractionOutcome outcome;
}

/// Today's allowance is used up. [resetsAt] is when it is not, so the Inbox can
/// say when rather than sorry.
final class AllowanceSpent extends ModelAnswer {
  const AllowanceSpent({this.resetsAt});

  final DateTime? resetsAt;
}

/// The Worker would not take the caller's token. Signing in again is the only
/// thing that answers this.
final class TokenRefused extends ModelAnswer {
  const TokenRefused(this.reason);

  final String reason;
}

/// Nothing got through from this phone — no signal, or the Worker never
/// answered. The Scan is untouched, and what answers this is waiting.
final class ModelOutOfReach extends ModelAnswer {
  const ModelOutOfReach(this.detail);

  final String detail;
}

/// The Worker answered, and the answer was that it could not do it: the Model
/// was down, Google's signing keys were unreachable, or something nobody has
/// seen before. Separate from [ModelOutOfReach] because the user has a
/// connection and telling them otherwise is a lie, and because the call
/// reached the Worker and so has already spent an attempt.
final class ModelUnavailable extends ModelAnswer {
  const ModelUnavailable(this.detail);

  final String detail;
}

/// The Worker would not take the image: not base64, or past the size it
/// accepts. Sending the same bytes again will not help, which is what
/// separates this from [ModelOutOfReach] and what will keep ticket 08's
/// automatic retry off it.
final class ImageNotAccepted extends ModelAnswer {
  const ImageNotAccepted(this.detail);

  final String detail;
}

abstract interface class ModelGateway {
  /// Reads a stored receipt image. Never throws: a failure is an answer.
  Future<ModelAnswer> extract(Uint8List receipt);
}
