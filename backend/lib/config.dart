import 'dart:io';

class AppConfig {
  static String _env(String key, String fallback) =>
      Platform.environment[key]?.trim().isNotEmpty == true
      ? Platform.environment[key]!.trim()
      : fallback;

  static int _envInt(String key, int fallback) =>
      int.tryParse(Platform.environment[key] ?? '') ?? fallback;

  static final String domain = _env('APP_DOMAIN', 'ulbooks.cn');
  static final int port = _envInt('PORT', 8080);

  // MySQL configuration
  static final String dbHost = _env('DB_HOST', 'localhost');
  static final int dbPort = _envInt('DB_PORT', 3306);
  static final String dbUser = _env('DB_USER', 'root');
  static final String dbPassword = _env('DB_PASSWORD', 'your_password_here');
  static final String dbName = _env('DB_NAME', 'vehicle_maintenance');
  static final bool runSchemaMigrations =
      _env('RUN_SCHEMA_MIGRATIONS', 'false').toLowerCase() == 'true';

  // Baidu OCR
  static final String baiduApiKey = _env('BAIDU_API_KEY', '');
  static final String baiduSecretKey = _env('BAIDU_SECRET_KEY', '');

  // Upload
  static final String uploadDir = _env('UPLOAD_DIR', 'uploads');
  static final String uploadBaseUrl = _env(
    'UPLOAD_BASE_URL',
    'https://ulbooks.cn/uploads',
  );
  static final int uploadMaxBytes = _envInt(
    'UPLOAD_MAX_BYTES',
    20 * 1024 * 1024,
  );

  // Security
  static final String apiKey = _env('API_KEY', '');
  static final List<String> allowedOrigins =
      _env(
            'ALLOWED_ORIGINS',
            'https://ulbooks.cn,https://www.ulbooks.cn,http://localhost:3000,http://localhost:8080',
          )
          .split(',')
          .map((origin) => origin.trim())
          .where((origin) => origin.isNotEmpty)
          .toList();
}
