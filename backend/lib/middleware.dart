import 'package:shelf/shelf.dart';
import 'config.dart';

Middleware corsMiddleware() {
  return (Handler handler) {
    return (Request request) async {
      final origin = request.headers['origin'];
      final headers = <String, String>{
        'Vary': 'Origin',
        'Access-Control-Allow-Methods':
            'GET, POST, PUT, PATCH, DELETE, OPTIONS',
        'Access-Control-Allow-Headers':
            'Content-Type, Authorization, X-API-Key',
      };

      if (origin != null && AppConfig.allowedOrigins.contains(origin)) {
        headers['Access-Control-Allow-Origin'] = origin;
      }

      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: headers);
      }

      final response = await handler(request);
      return response.change(headers: headers);
    };
  };
}

Middleware authMiddleware() {
  return (Handler handler) {
    return (Request request) async {
      if (!request.url.path.startsWith('api/') ||
          request.url.path == 'api/health') {
        return handler(request);
      }

      if (AppConfig.apiKey.isEmpty) {
        return handler(request);
      }

      final provided =
          request.headers['x-api-key'] ??
          (request.headers['authorization']?.startsWith('Bearer ') == true
              ? request.headers['authorization']!.substring(7)
              : null);

      if (provided != AppConfig.apiKey) {
        return Response.forbidden('{"error":"Forbidden"}');
      }

      return handler(request);
    };
  };
}

Middleware jsonMiddleware() {
  return (Handler handler) {
    return (Request request) async {
      final response = await handler(request);
      final contentType =
          response.headers['Content-Type'] ?? response.headers['content-type'];
      if (contentType != null &&
          !contentType.startsWith('application/octet-stream') &&
          !contentType.startsWith('text/plain')) {
        return response;
      }
      return response.change(
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    };
  };
}
