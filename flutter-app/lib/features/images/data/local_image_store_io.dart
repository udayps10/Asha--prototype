import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'local_image.dart';

Future<String> saveImage(LocalImage image, {required String prefix}) async {
  final directory = await getApplicationDocumentsDirectory();
  final imagesDirectory = Directory(
    '${directory.path}${Platform.pathSeparator}pending_images',
  );
  await imagesDirectory.create(recursive: true);
  final extension = (image.fileName ?? image.file.name).split('.').last;
  final path =
      '${imagesDirectory.path}${Platform.pathSeparator}${prefix}_${DateTime.now().microsecondsSinceEpoch}.$extension';
  await File(path).writeAsBytes(image.bytes, flush: true);
  return path;
}

Future<LocalImage?> readImage(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  final bytes = await file.readAsBytes();
  final extension = path.toLowerCase().split('.').last;
  final mime = switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'application/octet-stream',
  };
  final name = path.split(Platform.pathSeparator).last;
  return LocalImage(
    file: XFile(path, name: name),
    bytes: bytes,
    fileName: name,
    mimeType: mime,
  );
}