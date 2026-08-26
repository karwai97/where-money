import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/data/device_scan_store.dart';
import 'package:where_money/data/receipt_store.dart';
import 'package:path/path.dart' as p;
import 'package:where_money_core/where_money_core.dart';

void main() {
  late Directory directory;

  setUp(() => directory = Directory.systemTemp.createTempSync('where_money'));
  tearDown(() => directory.deleteSync(recursive: true));

  final image = Uint8List.fromList([1, 2, 3, 4]);

  test('a Scan and its image are on disk the moment capture answers', () async {
    final store = DeviceScanStore(directory);

    final scan = await store.capture(image);

    expect(scan.state, ScanState.captured);
    expect(
      directory.listSync().map((entry) => p.basename(entry.path)),
      containsAll(['${scan.id}.jpg', '${scan.id}.json']),
    );
  });

  test('Scans are still there when the app is started again', () async {
    final first = await DeviceScanStore(directory).capture(image);

    final restarted = DeviceScanStore(directory);

    expect(await restarted.inbox().first, [
      isA<Scan>().having((scan) => scan.id, 'id', first.id),
    ]);
    expect(await restarted.bytesAt(receiptPathFor(first.id)), image);
  });

  test('the Inbox lists the newest Scan first', () async {
    final store = DeviceScanStore(directory);
    final older = await store.capture(image, at: DateTime.utc(2026, 8, 1));
    final newer = await store.capture(image, at: DateTime.utc(2026, 8, 20));

    expect((await store.inbox().first).map((scan) => scan.id), [
      newer.id,
      older.id,
    ]);
  });

  test('abandoning a Scan removes its image from disk', () async {
    final store = DeviceScanStore(directory);
    final scan = await store.capture(image);

    await store.abandon(scan.id);

    expect(await store.inbox().first, isEmpty);
    expect(await store.bytesAt(receiptPathFor(scan.id)), isNull);
    expect(directory.listSync(), isEmpty);
  });

  test('a Scan that has become an Expense has left the Inbox', () async {
    final store = DeviceScanStore(directory);
    final scan = await store.capture(image);

    await store.put(scan.movedTo(ScanState.committed));

    expect(await store.inbox().first, isEmpty);
  });

  test('a Scan carries its Extraction across a restart', () async {
    final store = DeviceScanStore(directory);
    final scan = await store.capture(image);
    await store.put(
      scan.movedTo(ScanState.extracted, extraction: cleanExtraction),
    );

    final reopened = await DeviceScanStore(directory).inbox().first;

    expect(reopened.single.state, ScanState.extracted);
    expect(reopened.single.extraction?.total, cleanExtraction.total);
  });

  test('a failed Scan still says why after the app is started again', () async {
    final store = DeviceScanStore(directory);
    final scan = await store.capture(image);
    await store.put(
      scan.movedTo(ScanState.failed, failure: ScanFailure.tokenRefused),
    );

    final restarted = await DeviceScanStore(directory).inbox().first;

    expect(restarted.single.failure, ScanFailure.tokenRefused);
  });

  test('a capped Scan still says when it resets after the app is started '
      'again', () async {
    final resetsAt = DateTime.utc(2026, 8, 26, 16);
    final store = DeviceScanStore(directory);
    final scan = await store.capture(image);
    await store.put(
      scan.movedTo(ScanState.capped, allowanceResetsAt: resetsAt),
    );

    final restarted = await DeviceScanStore(directory).inbox().first;

    expect(restarted.single.allowanceResetsAt, resetsAt);
  });

  test('an Expense can find its receipt by the path recorded on it', () async {
    final store = DeviceScanStore(directory);
    final scan = await store.capture(image);

    expect(await store.bytesAt(receiptPathFor(scan.id)), image);
  });

  test('a receipt that never came to this device reads as missing rather than '
      'throwing', () async {
    final store = DeviceScanStore(directory);

    expect(await store.bytesAt('a-phone-ago.jpg'), isNull);
  });

  test('a receipt path cannot reach outside the Scan directory', () async {
    final store = DeviceScanStore(directory);

    expect(await store.bytesAt('../../secrets.jpg'), isNull);
  });
}
