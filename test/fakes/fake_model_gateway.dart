import 'dart:async';
import 'dart:typed_data';

import 'package:where_money/scan/model_gateway.dart';
import 'package:where_money_core/where_money_core.dart';

/// The ModelGateway seam's fake: the other of the two things this project
/// fakes. It hands back canned Extractions and can be told to produce every
/// member of the failure taxonomy, so each one can be watched arriving in the
/// Inbox without a network.
class FakeModelGateway implements ModelGateway {
  FakeModelGateway({ModelAnswer? answer})
    : answer = answer ?? reading(cleanExtraction);

  ModelAnswer answer;

  /// The bytes of the last receipt handed over, for asserting that what was
  /// sent is what was stored.
  Uint8List? sent;

  Completer<void>? _held;

  /// Holds every call open until [release], so a Scan can be watched sitting at
  /// `extracting` rather than blinking through it.
  void hold() => _held ??= Completer<void>();

  void release() {
    _held?.complete();
    _held = null;
  }

  @override
  Future<ModelAnswer> extract(Uint8List receipt) async {
    sent = receipt;
    await _held?.future;
    return answer;
  }

  static ModelAnswer reading(Extraction extraction) => ModelAnswered(
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
