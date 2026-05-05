class AppConfig {
  static const String domain = String.fromEnvironment(
    'APP_DOMAIN',
    defaultValue: 'ulbooks.cn',
  );
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ulbooks.cn/api',
  );
  static const String apiKey = String.fromEnvironment('API_KEY');
  static const String appName = '车辆维修管理';
  static const String appVersion = '1.0.0';
}
