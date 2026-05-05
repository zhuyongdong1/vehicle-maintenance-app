import 'dart:io';
import '../config.dart';

class FileService {
  static Future<String> saveFile(List<int> bytes, String extension) async {
    final dir = Directory(AppConfig.uploadDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final filename = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final filePath = '${AppConfig.uploadDir}/$filename';
    await File(filePath).writeAsBytes(bytes);
    return '${AppConfig.uploadBaseUrl}/$filename';
  }
}
