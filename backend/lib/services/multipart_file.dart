import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_multipart/shelf_multipart.dart';

import '../config.dart';

class UploadedFile {
  final String filename;
  final String contentType;
  final Uint8List bytes;

  UploadedFile({
    required this.filename,
    required this.contentType,
    required this.bytes,
  });
}

class MultipartFileService {
  static const _allowedMimeTypes = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
  };

  static Future<UploadedFile?> readImage(Request request) async {
    final form = request.formData();
    if (form == null) return null;

    await for (final data in form.formData) {
      if (data.filename == null) {
        await data.part.readBytes();
        continue;
      }

      final bytes = await data.part.readBytes();
      if (bytes.length > AppConfig.uploadMaxBytes) {
        throw const FormatException('Uploaded file is too large');
      }

      final contentType =
          data.part.headers['content-type'] ??
          lookupMimeType(data.filename!, headerBytes: bytes);

      if (contentType == null || !_allowedMimeTypes.containsKey(contentType)) {
        throw const FormatException(
          'Only jpg, png, and webp images are supported',
        );
      }

      final extension = _allowedMimeTypes[contentType]!;
      return UploadedFile(
        filename: '${DateTime.now().millisecondsSinceEpoch}.$extension',
        contentType: contentType,
        bytes: bytes,
      );
    }

    return null;
  }
}
