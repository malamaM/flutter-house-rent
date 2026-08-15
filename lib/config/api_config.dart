class ApiConfig {
  ApiConfig._();

  /// Override for devices or hosted environments with:
  /// --dart-define=API_ORIGIN=https://api.example.com
  static const origin = String.fromEnvironment(
    'API_ORIGIN',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const apiBase = '$origin/api';
  static const storageBase = '$origin/storage';

  static String storageUrl(Object? path) {
    final value = '${path ?? ''}'.replaceAll('\\', '/');
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '$storageBase/${value.replaceFirst(RegExp(r'^/+'), '')}';
  }
}
