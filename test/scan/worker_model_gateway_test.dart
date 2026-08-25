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
  }) => WorkerModelGateway(
    endpoint: Uri.parse('https://where-money.example.workers.dev'),
    idToken: () async => token,
    client: MockClient(answer),
  );

  http.Response refusing(int status, Map<String, Object?> body) =>
      http.Response(jsonEncode(body), status);

  test('a receipt the Worker reads comes back as an Extraction', () async {
    final recorded = File(
      'worker/test/fixtures/model-response.json',
    ).readAsStringSync();

    final answer = await gateway(
      (_) async => http.Response(recorded, 200),
    ).extract(receipt);

    final read = ((answer as ModelAnswered).outcome as ExtractionRead);
    expect(read.extraction.merchant, 'Village Grocer Bangsar');
    expect(read.extraction.total, 44.10);
  });

  test('the receipt goes up as base64 and nothing else', () async {
    late http.Request sent;
    await gateway((request) async {
      sent = request;
      return http.Response('{}', 200);
    }).extract(receipt);

    expect(sent.body, base64Encode(receipt));
    expect(sent.headers['authorization'], 'Bearer an-id-token');
    expect(sent.url.path, '/extract');
  });

  test('a photo that is not a JPEG is not labelled one', () async {
    final png = img.encodePng(img.Image(width: 8, height: 8));
    late http.Request sent;
    await gateway((request) async {
      sent = request;
      return http.Response('{}', 200);
    }).extract(png);

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
      ).extract(receipt);

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
    ).extract(receipt);

    expect(answer, isA<AllowanceSpent>());
    expect((answer as AllowanceSpent).resetsAt, DateTime.utc(2026, 8, 26));
  });

  test('a token the Worker will not take says which way', () async {
    final answer = await gateway(
      (_) async =>
          refusing(403, {'error': 'invalid_token', 'reason': 'expired'}),
    ).extract(receipt);

    expect(answer, isA<TokenRefused>());
    expect((answer as TokenRefused).reason, 'expired');
  });

  test('nobody signed in never reaches the Worker at all', () async {
    final answer = await gateway(
      (_) async => fail('the Worker should not have been called'),
      token: null,
    ).extract(receipt);

    expect(answer, isA<TokenRefused>());
  });

  test('a dead network is not a refusal', () async {
    final answer = await gateway(
      (_) async => throw const SocketException('Network is unreachable'),
    ).extract(receipt);

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
      ).extract(receipt);

      expect(answer, isA<ModelUnavailable>());
    },
  );

  test('the Model being down is not the caller having no signal', () async {
    final answer = await gateway(
      (_) async => refusing(502, {
        'error': 'model_unavailable',
        'message': 'upstream refused',
      }),
    ).extract(receipt);

    expect(answer, isA<ModelUnavailable>());
  });
}
