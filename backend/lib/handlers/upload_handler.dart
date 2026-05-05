import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import '../config.dart';
import '../services/multipart_file.dart';

class UploadHandler {
  static Future<Response> upload(Request request) async {
    try {
      final uploaded = await MultipartFileService.readImage(request);
      if (uploaded == null) {
        return Response(
          400,
          body: jsonEncode({'error': 'Expected image file'}),
        );
      }

      final dir = Directory(AppConfig.uploadDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final filePath = '${AppConfig.uploadDir}/${uploaded.filename}';
      final file = File(filePath);
      await file.writeAsBytes(uploaded.bytes);

      final url = '${AppConfig.uploadBaseUrl}/${uploaded.filename}';
      return Response.ok(
        jsonEncode({'url': url, 'filename': uploaded.filename}),
      );
    } on FormatException catch (e) {
      return Response(400, body: jsonEncode({'error': e.message}));
    }
  }
}
