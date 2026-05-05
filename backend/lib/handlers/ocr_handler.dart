import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../services/multipart_file.dart';

class OcrHandler {
  static const _accurateBasicUrl =
      'https://aip.baidubce.com/rest/2.0/ocr/v1/accurate_basic';

  static String? _accessToken;
  static DateTime? _tokenExpireTime;

  static Future<String?> _getAccessToken() async {
    if (AppConfig.baiduApiKey.isEmpty || AppConfig.baiduSecretKey.isEmpty) {
      return null;
    }
    if (_accessToken != null &&
        _tokenExpireTime != null &&
        DateTime.now().isBefore(_tokenExpireTime!)) {
      return _accessToken;
    }
    try {
      final url =
          'https://aip.baidubce.com/oauth/2.0/token?grant_type=client_credentials&client_id=${AppConfig.baiduApiKey}&client_secret=${AppConfig.baiduSecretKey}';
      final response = await http.post(Uri.parse(url));
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
      final expiresIn = data['expires_in'] ?? 86400;
      _tokenExpireTime = DateTime.now().add(Duration(seconds: expiresIn - 60));
      return _accessToken;
    } catch (e) {
      print('Failed to get Baidu access token: $e');
      return null;
    }
  }

  static Future<Response> scanPlate(Request request) async {
    return _handleOcr(
      request,
      'https://aip.baidubce.com/rest/2.0/ocr/v1/license_plate',
      'plate_number',
    );
  }

  static Future<Response> scanVin(Request request) async {
    return _handleOcr(request, _accurateBasicUrl, 'vin');
  }

  static Future<Response> _handleOcr(
    Request request,
    String apiUrl,
    String resultKey,
  ) async {
    final token = await _getAccessToken();
    if (token == null) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get Baidu access token'}),
      );
    }

    try {
      final uploaded = await MultipartFileService.readImage(request);
      if (uploaded == null) {
        return Response(
          400,
          body: jsonEncode({'error': 'Expected image file'}),
        );
      }
      final base64Image = base64Encode(uploaded.bytes);
      final result = await _callBaiduOcr(apiUrl, token, base64Image, resultKey);
      final value = resultKey == 'plate_number'
          ? _normalizePlate(result.value)
          : result.value;
      if (resultKey == 'plate_number' && value.isEmpty) {
        final fallback = await _callBaiduOcr(
          _accurateBasicUrl,
          token,
          base64Image,
          resultKey,
        );
        if (fallback.value.isNotEmpty) {
          return Response.ok(
            jsonEncode({resultKey: _normalizePlate(fallback.value)}),
          );
        }
      }
      if (value.isEmpty && result.error != null) {
        return Response.ok(jsonEncode({resultKey: '', 'error': result.error}));
      }
      return Response.ok(jsonEncode({resultKey: value}));
    } on FormatException catch (e) {
      return Response(400, body: jsonEncode({'error': e.message}));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'OCR processing failed: $e'}),
      );
    }
  }

  static Future<_OcrResult> _callBaiduOcr(
    String apiUrl,
    String token,
    String base64Image,
    String resultKey,
  ) async {
    try {
      final url = '$apiUrl?access_token=$token';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'image=${Uri.encodeComponent(base64Image)}',
      );
      final data = jsonDecode(response.body);

      if (data['error_code'] != null) {
        return _OcrResult('', data['error_msg']?.toString() ?? 'OCR failed');
      }

      String result = '';
      if (resultKey == 'plate_number') {
        final wordsResult = data['words_result'];
        if (wordsResult != null && wordsResult is Map) {
          result = wordsResult['number']?.toString() ?? '';
        } else if (wordsResult is List && wordsResult.isNotEmpty) {
          result = wordsResult
              .map((w) => w['words']?.toString() ?? '')
              .join('');
        }
      } else {
        final wordsResult = data['words_result'] ?? [];
        if (wordsResult is List && wordsResult.isNotEmpty) {
          result = wordsResult
              .map((w) => w['words']?.toString() ?? '')
              .join('');
        }
      }

      if (resultKey == 'plate_number') {
        result = _normalizePlate(result);
      }
      return _OcrResult(result, null);
    } catch (e) {
      return _OcrResult('', 'OCR request failed: $e');
    }
  }

  static String _normalizePlate(String raw) {
    var text = raw
        .toUpperCase()
        .replaceAll('쑴', '京')
        .replaceAll('享', '京')
        .replaceAll('凉', '京')
        .replaceAll('粵', '粤');
    text = text.replaceAll(
      RegExp(r'[^A-Z0-9京津沪渝冀豫云辽黑湘皖鲁新苏浙赣鄂桂甘晋蒙陕吉闽贵粤青藏川宁琼使领警学港澳]'),
      '',
    );

    final match = RegExp(
      r'([京津沪渝冀豫云辽黑湘皖鲁新苏浙赣鄂桂甘晋蒙陕吉闽贵粤青藏川宁琼使领警学港澳][A-Z][A-Z0-9]{5,6})',
    ).firstMatch(text);
    if (match == null) {
      final fallback = RegExp(r'([A-Z][A-Z0-9]{5,6})').firstMatch(text);
      if (fallback == null) return text;
      text = '京${fallback.group(1)!}';
    }

    final plate = match?.group(1) ?? text;
    return '${plate.substring(0, 2)}·${plate.substring(2)}';
  }
}

class _OcrResult {
  final String value;
  final String? error;

  const _OcrResult(this.value, this.error);
}
