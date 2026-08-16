class ApiConfig {
  ApiConfig._();

  /// Server origin pointing to the local network IP and port of the backend server.
  /// Override for devices or hosted environments with:
  /// --dart-define=API_ORIGIN=http://172.20.10.7:8000
  static const origin = String.fromEnvironment(
    'API_ORIGIN',
    defaultValue: 'http://172.20.10.7:8000',
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
