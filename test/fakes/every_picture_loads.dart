import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A picture that always arrives, for the tests that are about what the app
/// draws once one has.
///
/// `Image.network` in a widget test reaches the test harness's own
/// `HttpClient`, which answers 400 to everything. That is the right default —
/// no test should quietly go to the network — but it means a picture the app
/// was told to draw *always* takes the fallback, and a test could only ever
/// pin the fallback. Inside [whileEveryPictureLoads] every request is answered
/// with one transparent pixel instead.
Future<void> whileEveryPictureLoads(Future<void> Function() body) =>
    HttpOverrides.runZoned(body, createHttpClient: (_) => _AlwaysAPicture());

/// A 1×1 transparent PNG. The smallest thing the image loader will accept as
/// a picture, which is all any of these tests need it to be.
final _onePixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
  'hwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Each of these implements far more than it answers, so each answers what the
/// image loader actually calls and leaves the rest to `noSuchMethod`. Written
/// out rather than mocked: the surface is three methods deep and a mocking
/// package for it would be a dependency carrying one test helper.
class _AlwaysAPicture implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Request implements HttpClientRequest {
  @override
  final HttpHeaders headers = _Headers();

  @override
  Future<HttpClientResponse> close() async => _Response();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _onePixel.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(_onePixel).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
