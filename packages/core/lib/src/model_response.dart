/// Reading what the Model sent back.
///
/// The Worker owns request construction, because that is where the key is.
/// Parsing stays here, in tested pure Dart, because the traps are the part
/// that was hard-won:
///
/// - The `output` array interleaves reasoning items with message items, so the
///   text is never simply `output[0]` and every message's content is walked.
/// - A refusal arrives as a refusal content block with a 200 status, so it is
///   checked for before any text is trusted.
/// - If reasoning consumes the whole output budget the status is `incomplete`
///   with no text at all, which is a different failure from truncated JSON and
///   needs its own outcome.
library;

import 'dart:convert';

import 'extraction.dart';

class Usage {
  final int inputTokens;
  final int outputTokens;
  final int reasoningTokens;
  final int cachedTokens;

  const Usage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.reasoningTokens = 0,
    this.cachedTokens = 0,
  });

  factory Usage.fromJson(Map<String, dynamic> json) {
    final output = _map(json['output_tokens_details']);
    final input = _map(json['input_tokens_details']);
    return Usage(
      inputTokens: _int(json['input_tokens']),
      outputTokens: _int(json['output_tokens']),
      reasoningTokens: _int(output['reasoning_tokens']),
      cachedTokens: _int(input['cached_tokens']),
    );
  }
}

sealed class ExtractionOutcome {
  final Usage usage;
  final String servedByModel;

  const ExtractionOutcome({required this.usage, required this.servedByModel});
}

final class ExtractionRead extends ExtractionOutcome {
  final Extraction extraction;

  const ExtractionRead({
    required this.extraction,
    required super.usage,
    required super.servedByModel,
  });
}

/// A 200 that declined. Checked for before any text in the same message is
/// trusted.
final class ExtractionRefused extends ExtractionOutcome {
  final String message;

  const ExtractionRefused({
    required this.message,
    required super.usage,
    required super.servedByModel,
  });
}

/// The call succeeded and said nothing at all. Usually reasoning ate the whole
/// output budget, which [ranOutOfOutputTokens] separates from plain silence.
final class ExtractionNoOutput extends ExtractionOutcome {
  final String status;
  final String? reason;

  const ExtractionNoOutput({
    required this.status,
    required this.reason,
    required super.usage,
    required super.servedByModel,
  });

  bool get ranOutOfOutputTokens => reason == 'max_output_tokens';
}

/// Text arrived but was not the JSON the schema promised — cut off mid-write
/// when [truncated], and something else entirely otherwise.
final class ExtractionMalformed extends ExtractionOutcome {
  final String text;
  final bool truncated;
  final String detail;

  const ExtractionMalformed({
    required this.text,
    required this.truncated,
    required this.detail,
    required super.usage,
    required super.servedByModel,
  });
}

ExtractionOutcome parseExtraction(Map<String, dynamic> body) {
  final usage = Usage.fromJson(_map(body['usage']));
  final servedByModel = (body['model'] ?? '') as String;
  final status = (body['status'] ?? '') as String;

  final texts = <String>[];
  String? refusal;

  for (final item in (body['output'] ?? const []) as List) {
    if (item is! Map || item['type'] != 'message') continue;
    for (final block in (item['content'] ?? const []) as List) {
      if (block is! Map) continue;
      if (block['type'] == 'refusal') {
        refusal = (block['refusal'] ?? '') as String;
      } else if (block['type'] == 'output_text') {
        texts.add((block['text'] ?? '') as String);
      }
    }
  }

  if (refusal != null) {
    return ExtractionRefused(
      message: refusal,
      usage: usage,
      servedByModel: servedByModel,
    );
  }

  if (texts.isEmpty) {
    return ExtractionNoOutput(
      status: status,
      reason: _map(body['incomplete_details'])['reason'] as String?,
      usage: usage,
      servedByModel: servedByModel,
    );
  }

  final text = texts.last;
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    return ExtractionMalformed(
      text: text,
      truncated: status == 'incomplete',
      detail: e.message,
      usage: usage,
      servedByModel: servedByModel,
    );
  }

  if (decoded is! Map<String, dynamic>) {
    return ExtractionMalformed(
      text: text,
      truncated: false,
      detail: 'Expected a JSON object, got ${decoded.runtimeType}.',
      usage: usage,
      servedByModel: servedByModel,
    );
  }

  return ExtractionRead(
    extraction: Extraction.fromJson(decoded),
    usage: usage,
    servedByModel: servedByModel,
  );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

int _int(Object? value) => value is num ? value.toInt() : 0;
