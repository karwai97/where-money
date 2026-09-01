import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:where_money/scan/model_gateway.dart';
import 'package:where_money/scan/worker_model_gateway.dart';
import 'package:where_money_core/where_money_core.dart';

/// This end of `worker/README.md`. Nothing here reaches the network — the
/// Worker's own suite covers the far end, and what is left to get wrong is the
/// translation from its statuses into the failure taxonomy.
void main() {
  final receipt = Uint8List.fromList(List.generate(64, (i) => i));

  WorkerModelGateway gateway(
    Future<http.Response> Function(http.Request) answer, {
    String? token = 'an-id-token',
    Knobs knobs = const Knobs(),
  }) => WorkerModelGateway(
    endpoint: Uri.parse('https://where-money.example.workers.dev'),
    idToken: () async => token,
    client: MockClient(answer),
    knobs: knobs,
  );

  http.Response refusing(int status, Map<String, Object?> body) =>
      http.Response(jsonEncode(body), status);

  test('a receipt the Worker reads comes back as an Extraction', () async {
    final recorded = File(
      'worker/test/fixtures/model-response.json',
    ).readAsStringSync();

    final answer = await gateway(
      (_) async => http.Response(recorded, 200),
    ).extract(receipt, language: 'en');

    final read = ((answer as ModelAnswered).outcome as ExtractionRead);
    expect(read.extraction.merchant, 'Village Grocer Bangsar');
    expect(read.extraction.total, 44.10);
  });

  test('the receipt goes up as base64 and nothing else', () async {
    late http.Request sent;
    await gateway((request) async {
      sent = request;
      return http.Response('{}', 200);
    }).extract(receipt, language: 'en');

    expect(sent.body, base64Encode(receipt));
    expect(sent.headers['authorization'], 'Bearer an-id-token');
    expect(sent.url.path, '/extract');
  });

  test(
    'the knobs this launch is running on are what the Worker is asked for',
    () async {
      late http.Request scanned;
      late http.Request recapped;
      const knobs = Knobs(model: 'gpt-5-mini', effort: 'medium', dailyCap: 15);

      await gateway((request) async {
        scanned = request;
        return http.Response('{}', 200);
      }, knobs: knobs).extract(receipt, language: 'en');
      await gateway((request) async {
        recapped = request;
        return http.Response('{}', 200);
      }, knobs: knobs).recap('{}', language: 'en');

      for (final sent in [scanned, recapped]) {
        expect(sent.url.queryParameters['model'], 'gpt-5-mini');
        expect(sent.url.queryParameters['effort'], 'medium');
        expect(sent.url.queryParameters['cap'], '15');
      }
    },
  );

  test(
    'the language is asked for a call at a time, not held by the gateway',
    () async {
      final asked = <http.Request>[];
      final one = gateway((request) async {
        asked.add(request);
        return http.Response('{}', 200);
      });

      await one.extract(receipt, language: 'zh');
      await one.recap('{}', language: 'en');

      expect(asked.map((sent) => sent.url.queryParameters['lang']), [
        'zh',
        'en',
      ]);
    },
  );

  test('a photo that is not a JPEG is not labelled one', () async {
    final png = img.encodePng(img.Image(width: 8, height: 8));
    late http.Request sent;
    await gateway((request) async {
      sent = request;
      return http.Response('{}', 200);
    }).extract(png, language: 'en');

    expect(sent.url.queryParameters['media'], 'image/png');
  });

  test(
    'an image the Worker will not take is not worth sending again',
    () async {
      final answer = await gateway(
        (_) async => refusing(413, {
          'error': 'image_too_large',
          'message': 'over 700,000 characters of base64',
        }),
      ).extract(receipt, language: 'en');

      expect(answer, isA<ImageNotAccepted>());
    },
  );

  test('the daily allowance says when it resets, not that something went '
      'wrong', () async {
    final answer = await gateway(
      (_) async => refusing(429, {
        'error': 'cap_reached',
        'used': 40,
        'limit': 40,
        'resets_at': '2026-08-26T00:00:00.000Z',
      }),
    ).extract(receipt, language: 'en');

    expect(answer, isA<AllowanceSpent>());
    expect((answer as AllowanceSpent).resetsAt, DateTime.utc(2026, 8, 26));
  });

  test('a token the Worker will not take says which way', () async {
    final answer = await gateway(
      (_) async =>
          refusing(403, {'error': 'invalid_token', 'reason': 'expired'}),
    ).extract(receipt, language: 'en');

    expect(answer, isA<TokenRefused>());
    expect((answer as TokenRefused).reason, 'expired');
  });

  test('nobody signed in never reaches the Worker at all', () async {
    final answer = await gateway(
      (_) async => fail('the Worker should not have been called'),
      token: null,
    ).extract(receipt, language: 'en');

    expect(answer, isA<TokenRefused>());
  });

  test('a dead network is not a refusal', () async {
    final answer = await gateway(
      (_) async => throw const SocketException('Network is unreachable'),
    ).extract(receipt, language: 'en');

    expect(answer, isA<ModelOutOfReach>());
  });

  test(
    "Google's signing keys being unreachable is ours, not the caller's",
    () async {
      final answer = await gateway(
        (_) async => refusing(503, {
          'error': 'signing_keys_unavailable',
          'message': 'could not reach Google',
        }),
      ).extract(receipt, language: 'en');

      expect(answer, isA<ModelUnavailable>());
    },
  );

  test('the Model being down is not the caller having no signal', () async {
    final answer = await gateway(
      (_) async => refusing(502, {
        'error': 'model_unavailable',
        'message': 'upstream refused',
      }),
    ).extract(receipt, language: 'en');

    expect(answer, isA<ModelUnavailable>());
  });

  test('a Rollup the Worker writes up comes back as prose', () async {
    final recorded = File(
      'worker/test/fixtures/recap-response.json',
    ).readAsStringSync();

    final answer = await gateway(
      (_) async => http.Response(recorded, 200),
    ).recap('{"month":"August 2026"}', language: 'en');

    final written = ((answer as RecapAnswered).outcome as RecapWritten);
    expect(written.text, startsWith('August came to MYR 1806.75'));
  });

  test('the Rollup goes up as JSON, and no receipt goes with it', () async {
    late http.Request sent;
    await gateway((request) async {
      sent = request;
      return http.Response('{}', 200);
    }).recap('{"month":"August 2026"}', language: 'en');

    expect(sent.body, '{"month":"August 2026"}');
    expect(sent.headers['authorization'], 'Bearer an-id-token');
    expect(sent.url.path, '/recap');
    expect(sent.url.queryParameters, isNot(contains('media')));
  });

  test("a Recap past the day's allowance says when it comes back", () async {
    final answer = await gateway(
      (_) async => refusing(429, {
        'error': 'cap_reached',
        'resets_at': '2026-08-26T00:00:00.000Z',
      }),
    ).recap('{}', language: 'en');

    expect((answer as AllowanceSpent).resetsAt, DateTime.utc(2026, 8, 26));
  });

  test('a dead network is not a refusal for a Recap either', () async {
    final answer = await gateway(
      (_) async => throw const SocketException('Network is unreachable'),
    ).recap('{}', language: 'en');

    expect(answer, isA<ModelOutOfReach>());
  });
}
