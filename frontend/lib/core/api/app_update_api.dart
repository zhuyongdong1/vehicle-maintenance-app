import 'dart:convert';

import 'package:dio/dio.dart';

import '../config.dart';

class AppUpdateInfo {
  final String versionName;
  final int versionCode;
  final String apkUrl;
  final String releaseNotes;
  final bool required;
  final String publishedAt;

  AppUpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.releaseNotes,
    required this.required,
    required this.publishedAt,
  });

  bool get hasUpdate => versionCode > AppConfig.appBuildNumber;

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      versionName: json['version_name']?.toString() ?? '',
      versionCode: _intValue(json['version_code']),
      apkUrl: json['apk_url']?.toString() ?? '',
      releaseNotes: _notesText(json['release_notes']),
      required: json['required'] == true,
      publishedAt: json['published_at']?.toString() ?? '',
    );
  }
}

class AppUpdateApi {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  Future<AppUpdateInfo> getLatest() async {
    final res = await _dio.get(
      AppConfig.updateManifestUrl,
      options: Options(headers: {'Cache-Control': 'no-cache'}),
    );
    final data = res.data is String ? jsonDecode(res.data) : res.data;
    return AppUpdateInfo.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _notesText(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).join('\n');
  }
  return value?.toString() ?? '';
}
