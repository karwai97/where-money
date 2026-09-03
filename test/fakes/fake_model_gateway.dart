import 'dart:async';
import 'dart:typed_data';

import 'package:where_money/scan/model_gateway.dart';
import 'package:where_money_core/where_money_core.dart';

/// The ModelGateway seam's fake: the other of the two things this project
/// fakes. It hands back canned Extractions and can be told to produce every
/// member of the failure taxonomy, so each one can be watched arriving in the
/// Inbox without a network.
class FakeModelGateway implements ModelGateway {
  FakeModelGateway({ScanAnswer? answer, RecapAnswer? recapAnswer})
    : answer = answer ?? reading(cleanExtraction),
      recapAnswer = recapAnswer ?? wrote('August was quiet.');

  ScanAnswer answer;
  RecapAnswer recapAnswer;

  /// The bytes of the last receipt handed over, for asserting that what was
  /// sent is what was stored.
  Uint8List? sent;

  /// Every Rollup this gateway has been asked to write up, in order. A Recap
  /// that costs nothing is a request that was never made, so this is the only
  /// place in the suite where what is asserted on is the asking itself.
  final List<String> rollupsAsked = [];

  /// The language each call was made in, newest last. Two lists rather than
  /// one, because the two endpoints are asked by different blocs and a test
  /// about the Recap should not have to know a Scan happened.
  final List<String> extractedIn = [];
  final List<String> recappedIn = [];

  /// Thrown instead of answering. `ModelGateway` promises a typed answer for
  /// every way a call can fail, and the real one keeps that promise for
  /// everything it reaches over the wire — but it fetches an ID token first,
  /// outside its own `try`, and Firebase throws there on a dead connection or
  /// a revoked token. So a caller that trusts the promise absolutely is a
  /// caller that hangs, and this is how a test says so.
  Object? throws;

  Completer<void>? _held;

  /// Holds every call open until [release], so a Scan can be watched sitting at
  /// `extracting` rather than blinking through it.
  void hold() => _held ??= Completer<void>();

  void release() {
    _held?.complete();
    _held = null;
  }

  @override
  Future<ScanAnswer> extract(
    Uint8List receipt, {
    required String language,
  }) async {
    sent = receipt;
    extractedIn.add(language);
    await _held?.future;
    if (throws case final Object failure) throw failure;
    return answer;
  }

  @override
  Future<RecapAnswer> recap(
    String rollupJson, {
    required String language,
  }) async {
    rollupsAsked.add(rollupJson);
    recappedIn.add(language);
    await _held?.future;
    if (throws case final Object failure) throw failure;
    return recapAnswer;
  }

  static RecapAnswer wrote(String text) => RecapAnswered(
    RecapWritten(
      text: text,
      usage: const Usage(inputTokens: 412, outputTokens: 128),
      servedByModel: 'gpt-5-nano-2025-08-07',
    ),
  );

  static const recapRefused = RecapAnswered(
    RecapRefused(
      message: 'I cannot help with that.',
      usage: Usage(),
      servedByModel: 'gpt-5-nano-2025-08-07',
    ),
  );

  /// Reasoning ate the whole output budget, so there is nothing to print.
  static const recapSilence = RecapAnswered(
    RecapNoOutput(
      status: 'incomplete',
      reason: 'max_output_tokens',
      usage: Usage(),
      servedByModel: 'gpt-5-nano-2025-08-07',
    ),
  );

  static ScanAnswer reading(Extraction extraction) => ModelAnswered(
    ExtractionRead(
      extraction: extraction,
      usage: const Usage(inputTokens: 2717, outputTokens: 500),
      servedByModel: 'gpt-5-nano-2025-08-07',
    ),
  );

  static const refusal = ModelAnswered(
    ExtractionRefused(
      message: 'I cannot help with that.',
      usage: Usage(),
      servedByModel: 'gpt-5-nano-2025-08-07',
    ),
  );

  /// Reasoning ate the whole output budget, so there is no text at all.
  static const silence = ModelAnswered(
    ExtractionNoOutput(
      status: 'incomplete',
      reason: 'max_output_tokens',
      usage: Usage(),
      servedByModel: 'gpt-5-nano-2025-08-07',
    ),
  );

  static const gibberish = ModelAnswered(
    ExtractionMalformed(
      text: '{"merchant": "Jaya Gro',
      truncated: true,
      detail: 'Unterminated string',
      usage: Usage(),
      servedByModel: 'gpt-5-nano-2025-08-07',
    ),
  );
}
