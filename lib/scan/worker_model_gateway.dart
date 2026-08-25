import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:where_money_core/where_money_core.dart';

import 'model_gateway.dart';
import 'receipt_image.dart';

/// The deployed Worker, which is the only place the OpenAI key exists. This
/// end of the contract is thin on purpose: the prompt, the schema and the
/// output budget are the Worker's, and the client cannot name its own model.
///
/// The body is the base64 and nothing else. The Worker templates it into the
/// outgoing request rather than parsing it, which is what keeps a Scan inside
/// the free plan's 10ms of CPU — see `worker/README.md`.
class WorkerModelGateway implements ModelGateway {
  WorkerModelGateway({
    required this.endpoint,
    required this.idToken,
    http.Client? client,
    this.model = 'gpt-5-nano',
    this.effort = 'low',
    this.dailyCap = 40,
  }) : _client = client ?? http.Client();

  final Uri endpoint;

  /// The signed-in user's Firebase ID token, fetched per call because it
  /// expires in an hour and a Scan can wait longer than that.
  final Future<String?> Function() idToken;

  final http.Client _client;
  final String model;
  final String effort;
  final int dailyCap;

  @override
  Future<ModelAnswer> extract(Uint8List receipt) async {
    final token = await idToken();
    if (token == null) {
      return const TokenRefused('nobody is signed in on this device');
    }

    final http.Response answer;
    try {
      answer = await _client.post(
        endpoint.replace(
          path: '${endpoint.path}/extract',
          queryParameters: {
            'model': model,
            'effort': effort,
            'media': mediaTypeOf(receipt),
            'cap': '$dailyCap',
          },
        ),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'text/plain',
        },
        body: base64Encode(receipt),
      );
    } on SocketException catch (error) {
      return ModelOutOfReach(error.message);
    } on http.ClientException catch (error) {
      return ModelOutOfReach(error.message);
    } on TimeoutException {
      return const ModelOutOfReach('the Worker did not answer in time');
    }

    return _readAnswer(answer);
  }
}

ModelAnswer _readAnswer(http.Response answer) {
  final Map<String, dynamic> body;
  try {
    body = jsonDecode(answer.body) as Map<String, dynamic>;
  } catch (_) {
    return ModelOutOfReach(
      'the Worker answered ${answer.statusCode} with something that was not '
      'JSON',
    );
  }

  if (answer.statusCode == 200) return ModelAnswered(parseExtraction(body));

  // The statuses are `worker/README.md`'s, and each maps onto exactly one
  // member of the failure taxonomy.
  return switch (body['error']) {
    'cap_reached' => AllowanceSpent(
      resetsAt: DateTime.tryParse('${body['resets_at']}'),
    ),
    'missing_token' ||
    'invalid_token' => TokenRefused('${body['reason'] ?? body['error']}'),
    'bad_image' || 'image_too_large' => ImageNotAccepted(
      '${body['message'] ?? body['error']}',
    ),
    final Object? error => ModelOutOfReach(
      '${error ?? answer.statusCode}: ${body['message'] ?? answer.body}',
    ),
  };
}
