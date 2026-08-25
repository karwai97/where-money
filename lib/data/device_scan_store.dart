import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:where_money_core/where_money_core.dart';

import 'scan_record.dart';

/// Scans and their images, in a directory on the phone. Nothing here touches
/// the network — an image never leaves the device (ADR-0003), and capture has
/// to work in a basement.
///
/// One JSON file per Scan beside its image, rather than one index over all of
/// them: an index half-written by a force-quit would lose every Scan, and a
/// Scan is the one thing this app promises not to lose.
class DeviceScanStore {
  DeviceScanStore(this.directory);

  final Directory directory;
  final _changes = StreamController<List<Scan>>.broadcast();
  var _captured = 0;

  Stream<List<Scan>> inbox() async* {
    yield await _read();
    yield* _changes.stream;
  }

  Future<Scan> capture(Uint8List image, {DateTime? at}) async {
    final capturedAt = at ?? DateTime.now();
    final scan = Scan.captured(
      id: '${capturedAt.microsecondsSinceEpoch}-${++_captured}',
      at: capturedAt,
    );

    await directory.create(recursive: true);
    // The image first. A force-quit between the two leaves a stray file, which
    // costs nothing; the other order leaves a Scan with no receipt in it.
    await _imageFile(scan.id).writeAsBytes(image, flush: true);
    await put(scan);
    return scan;
  }

  /// Written only beside an image. Capture puts the image down first, so the
  /// one case this turns away is a Scan the user abandoned while the Model was
  /// still reading it — which must stay abandoned rather than reappear.
  Future<void> put(Scan scan) async {
    if (!_imageFile(scan.id).existsSync()) return;

    await directory.create(recursive: true);
    await _recordFile(
      scan.id,
    ).writeAsString(jsonEncode(scanToRecord(scan)), flush: true);
    _changes.add(await _read());
  }

  Future<Uint8List?> imageFor(String scanId) async {
    final file = _imageFile(scanId);
    return file.existsSync() ? file.readAsBytes() : null;
  }

  Future<void> abandon(String scanId) async {
    for (final file in [_recordFile(scanId), _imageFile(scanId)]) {
      if (file.existsSync()) await file.delete();
    }
    _changes.add(await _read());
  }

  Future<List<Scan>> _read() async {
    if (!directory.existsSync()) return const [];

    final scans = <Scan>[];
    for (final entry in directory.listSync().whereType<File>()) {
      final id = _idOfRecord(entry.path);
      if (id == null) continue;
      try {
        final record =
            jsonDecode(await entry.readAsString()) as Map<String, Object?>;
        scans.add(scanFromRecord(id, record));
      } on FormatException {
        // An unreadable record is not worth taking the whole Inbox down for.
        continue;
      }
    }

    return scans.waitingNewestFirst;
  }

  File _recordFile(String scanId) =>
      File(p.join(directory.path, '$scanId.json'));

  File _imageFile(String scanId) => File(p.join(directory.path, '$scanId.jpg'));

  static String? _idOfRecord(String path) {
    final name = p.basename(path);
    return name.endsWith('.json')
        ? name.substring(0, name.length - '.json'.length)
        : null;
  }
}
