import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'receipt_image.dart';

enum PhotoSource { camera, gallery }

/// The camera and the gallery, reduced to the only thing anything below here
/// wants from them. Everything downstream sees bytes, which is why the camera
/// needs no fake in tests — a function returning bytes is the whole seam.
typedef Photographer = Future<Uint8List?> Function(PhotoSource from);

Future<Uint8List?> photographWithDevice(PhotoSource from) async {
  final picked = await ImagePicker().pickImage(
    source: switch (from) {
      PhotoSource.camera => ImageSource.camera,
      PhotoSource.gallery => ImageSource.gallery,
    },
    // The platform resizes far faster than Dart can, so it does the bulk of
    // the work and resizeForStorage is left guaranteeing the result.
    maxWidth: defaultLongEdge.toDouble(),
    maxHeight: defaultLongEdge.toDouble(),
    imageQuality: 88,
  );
  return picked?.readAsBytes();
}
