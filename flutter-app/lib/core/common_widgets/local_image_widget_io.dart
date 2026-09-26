import 'dart:io';

import 'package:flutter/widgets.dart';

Widget? localImageWidget(
  String path, {
  required double width,
  required double height,
  BoxFit fit = BoxFit.cover,
}) {
  final file = File(path);
  if (!file.existsSync()) return null;
  return Image.file(file, width: width, height: height, fit: fit);
}