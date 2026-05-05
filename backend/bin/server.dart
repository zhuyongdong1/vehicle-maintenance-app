import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:backend/config.dart';
import 'package:backend/database/connection.dart';
import 'package:backend/middleware.dart';
import 'package:backend/router.dart';

void main(List<String> args) async {
  // Initialize database
  try {
    await Database.instance.initialize();
  } catch (e) {
    print('Fatal: MySQL connection failed - $e');
    exitCode = 1;
    return;
  }

  final ip = InternetAddress.anyIPv4;
  final port = int.parse(
    Platform.environment['PORT'] ?? AppConfig.port.toString(),
  );

  final handler = Pipeline()
      .addMiddleware(corsMiddleware())
      .addMiddleware(authMiddleware())
      .addMiddleware(jsonMiddleware())
      .addMiddleware(logRequests())
      .addHandler(createRouter().call);

  final server = await serve(handler, ip, port);
  print('Server listening on http://${server.address.host}:${server.port}');
  print('API base: http://${server.address.host}:${server.port}/api');
}
