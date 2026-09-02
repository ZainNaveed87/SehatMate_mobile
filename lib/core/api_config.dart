abstract final class ApiConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sehatmate-api.secretstechies.com/api',
  );

  static String get baseUrl {
    final value = _configuredBaseUrl.trim();
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  static Uri endpoint(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }

  static bool get isConfigured => Uri.tryParse(baseUrl)?.hasScheme ?? false;
}
