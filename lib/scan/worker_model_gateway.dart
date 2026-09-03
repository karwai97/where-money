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
/// A receipt goes up as base64 and nothing else. The Worker templates it into
/// the outgoing request rather than parsing it, which is what keeps a Scan
/// inside the free plan's 10ms of CPU — see `worker/README.md`. A Rollup is
/// small enough that it goes up as ordinary JSON.
class WorkerModelGateway implements ModelGateway {
  WorkerModelGateway({
    required this.endpoint,
    required this.idToken,
    http.Client? client,
    this.knobs = const Knobs(),
  }) : _client = client ?? http.Client();

  final Uri endpoint;

  /// The signed-in user's Firebase ID token, fetched per call because it
  /// expires in an hour and a Scan can wait longer than that.
  final Future<String?> Function() idToken;

  final http.Client _client;

  /// Plain values rather than a collaborator to ask. They are whatever a
  /// console had to say when the app started, so a knob turned now reaches
  /// this on the next launch.
  final Knobs knobs;

  @override
  Future<ScanAnswer> extract(
    Uint8List receipt, {
    required String language,
  }) async {
    final (answer, failure) = await _post(
      'extract',
      query: {'media': mediaTypeOf(receipt), 'lang': language},
      contentType: 'text/plain',
      body: base64Encode(receipt),
    );
    if (failure != null) return failure;

    final body = _bodyOf(answer!);
    if (body == null) return _notJson(answer);
    if (answer.statusCode == 200) return ModelAnswered(parseExtraction(body));

    return switch (body['error']) {
      'bad_image' || 'image_too_large' => ImageNotAccepted(
        '${body['message'] ?? body['error']}',
      ),
      _ => _refusal(answer, body),
    };
  }

  @override
  Future<RecapAnswer> recap(
    String rollupJson, {
    required String language,
  }) async {
    final (answer, failure) = await _post(
      'recap',
      query: {'lang': language},
      contentType: 'application/json',
      body: rollupJson,
    );
    if (failure != null) return failure;

    final body = _bodyOf(answer!);
    if (body == null) return _notJson(answer);
    if (answer.statusCode == 200) return RecapAnswered(parseRecap(body));

    // `bad_rollup` and `rollup_too_large` have no case of their own: a Rollup
    // the Worker will not take is this app disagreeing with itself rather than
    // anything the user did, and it reads as the far end's problem below.
    return _refusal(answer, body);
  }

  /// One call to the Worker: the token, the knobs, and every way the wire can
  /// fail. What a 200 means is the caller's to say, which is the only thing
  /// the two endpoints do not share.
  Future<(http.Response?, ModelFailure?)> _post(
    String path, {
    Map<String, String> query = const {},
    required String contentType,
    required String body,
  }) async {
    // Guarded on its own, because it is the one call here that is not this
    // file's. In production it is Firebase's `getIdToken`, which throws on a
    // dead connection and on a revoked token, and this file promises the
    // taxonomy rather than an exception so that every failure becomes a state
    // a Scan can sit in. `ModelOutOfReach` because no signal is much the
    // commonest reason a token does not come, and it is the one failure that
    // goes round again by itself; a revoked token retrying on that schedule
    // costs nothing, because it never reaches the Worker.
    final String? token;
    try {
      token = await idToken();
    } on Object catch (error) {
      return (null, ModelOutOfReach('$error'));
    }

    if (token == null) {
      return (null, const TokenRefused('nobody is signed in on this device'));
    }

    try {
      final answer = await _client.post(
        endpoint.replace(
          path: '${endpoint.path}/$path',
          queryParameters: {
            'model': knobs.model,
            'effort': knobs.effort,
            'cap': '${knobs.dailyCap}',
            ...query,
          },
        ),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': contentType,
        },
        body: body,
      );
      return (answer, null);
    } on SocketException catch (error) {
      return (null, ModelOutOfReach(error.message));
    } on http.ClientException catch (error) {
      return (null, ModelOutOfReach(error.message));
    } on TimeoutException {
      return (null, const ModelOutOfReach('the Worker did not answer in time'));
    }
  }
}

Map<String, dynamic>? _bodyOf(http.Response answer) {
  try {
    return jsonDecode(answer.body) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

ModelFailure _notJson(http.Response answer) => ModelUnavailable(
  'the Worker answered ${answer.statusCode} with something that was not JSON',
);

/// The statuses are `worker/README.md`'s, and each maps onto exactly one
/// member of the failure taxonomy.
ModelFailure _refusal(http.Response answer, Map<String, dynamic> body) =>
    switch (body['error']) {
      'cap_reached' => AllowanceSpent(
        resetsAt: DateTime.tryParse('${body['resets_at']}'),
      ),
      'missing_token' ||
      'invalid_token' => TokenRefused('${body['reason'] ?? body['error']}'),
      // Everything left is the far end's problem, not the caller's:
      // `model_unavailable`, `signing_keys_unavailable`, and whatever a later
      // version of the Worker invents.
      final Object? error => ModelUnavailable(
        '${error ?? answer.statusCode}: ${body['message'] ?? answer.body}',
      ),
    };
