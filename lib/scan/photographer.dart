import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

/// The camera and the gallery, reduced to the only thing anything below here
/// wants from them. Everything downstream sees bytes, which is why the camera
/// needs no fake in tests — a function returning bytes is the whole seam.
typedef Photographer = Future<Uint8List?> Function(PhotoSource from);

Future<Uint8List?> photographWithDevice(
  PhotoSource from, {
  required int longEdge,
}) async {
  final picked = await ImagePicker().pickImage(
    source: switch (from) {
      PhotoSource.camera => ImageSource.camera,
      PhotoSource.gallery => ImageSource.gallery,
    },
    // The platform resizes far faster than Dart can, so it does the bulk of
    // the work and resizeTo is left guaranteeing the result. It is given the
    // knob rather than a constant, or a console asking for a larger image
    // would be capped here and quietly do nothing.
    maxWidth: longEdge.toDouble(),
    maxHeight: longEdge.toDouble(),
    imageQuality: 88,
  );
  return picked?.readAsBytes();
}
