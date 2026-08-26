import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// Pick images from the gallery and compress each to JPEG (the backend only
/// accepts image/jpeg|png, max ~5MB). Returns local files ready for multipart
/// upload. Silently returns [] if the user cancels.
Future<List<File>> pickCompressedImages({int limit = 5}) async {
  final picked = await ImagePicker().pickMultiImage();
  final out = <File>[];
  for (final x in picked.take(limit)) {
    out.add(await _compress(x.path));
  }
  return out;
}

/// Pick a single image (camera or gallery), compressed to JPEG.
Future<File?> pickCompressedImage({ImageSource source = ImageSource.gallery}) async {
  final x = await ImagePicker().pickImage(source: source, imageQuality: 90);
  if (x == null) return null;
  return _compress(x.path);
}

/// Capture a single photo LIVE from the camera (verification documents must be
/// photographed, not uploaded from the gallery). Selfie uses the front camera.
Future<File?> captureCompressedImage({bool front = false}) async {
  final x = await ImagePicker().pickImage(
    source: ImageSource.camera,
    imageQuality: 90,
    preferredCameraDevice: front ? CameraDevice.front : CameraDevice.rear,
  );
  if (x == null) return null;
  return _compress(x.path);
}

/// Compress an already-captured photo (e.g. from the in-app `camera` plugin)
/// to the same JPEG the uploads expect.
Future<File> compressToJpeg(String path) => _compress(path);

Future<File> _compress(String path) async {
  final target = '${path}_c.jpg';
  final result = await FlutterImageCompress.compressAndGetFile(
    path,
    target,
    quality: 70,
    minWidth: 1280,
    minHeight: 1280,
    format: CompressFormat.jpeg,
  );
  return File(result?.path ?? path);
}
