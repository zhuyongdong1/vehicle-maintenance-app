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
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.3',
  );
  static const int appBuildNumber = int.fromEnvironment(
    'APP_BUILD_NUMBER',
    defaultValue: 4,
  );
  static const String updateManifestUrl = String.fromEnvironment(
    'APP_UPDATE_MANIFEST_URL',
    defaultValue: 'https://ulbooks.cn/downloads/app-version.json',
  );
}
