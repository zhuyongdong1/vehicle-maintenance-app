import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../config.dart';

class ApiClient {
  late final Dio dio;
  bool _online = false;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          if (AppConfig.apiKey.isNotEmpty) 'X-API-Key': AppConfig.apiKey,
        },
      ),
    );
  }

  Future<bool> get isOnline async {
    try {
      await dio.get('/dashboard');
      _online = true;
    } catch (_) {
      _online = false;
    }
    return _online;
  }

  Future<T?> safeCall<T>(Future<T> Function() apiCall, {T? fallback}) async {
    try {
      return await apiCall();
    } catch (e) {
      debugPrint('API call failed: $e');
      return fallback;
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) =>
      dio.get(path, queryParameters: queryParameters);

  Future<Response> post(String path, {dynamic data}) =>
      dio.post(path, data: data);

  Future<Response> put(String path, {dynamic data}) =>
      dio.put(path, data: data);

  Future<Response> delete(String path) => dio.delete(path);

  Future<Response> uploadFile(
    String path,
    XFile file, {
    Map<String, String>? extraFields,
  }) async {
    final filename = file.name.isNotEmpty ? file.name : 'upload.jpg';
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        await file.readAsBytes(),
        filename: filename,
      ),
      if (extraFields != null) ...extraFields,
    });
    return dio.post(path, data: formData);
  }
}

final apiClientProvider = ApiClient();
