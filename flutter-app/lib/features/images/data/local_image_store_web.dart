import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'local_image.dart';

final _images = <String, Uint8List>{};

Future<String> saveImage(LocalImage image, {required String prefix}) async {
  final id = 'web_${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  _images[id] = image.bytes;
  return id;
}

Future<LocalImage?> readImage(String path) async {
  final bytes = _images[path];
  if (bytes == null) return null;
  return LocalImage(
    file: XFile.fromData(bytes, name: path),
    bytes: bytes,
    fileName: path,
  );
}