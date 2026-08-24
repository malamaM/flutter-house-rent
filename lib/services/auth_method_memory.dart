import 'package:shared_preferences/shared_preferences.dart';

class RememberedAuthMethod {
  const RememberedAuthMethod({required this.provider, required this.email});

  final String provider;
  final String email;

  String get providerLabel => switch (provider) {
        'google' => 'Google',
        'apple' => 'Apple',
        'facebook' => 'Facebook',
        _ => 'Email and password',
      };

  bool matchesEmail(String value) =>
      email.isNotEmpty && email == value.trim().toLowerCase();
}

class AuthMethodMemory {
  AuthMethodMemory._();

  static const _providerKey = 'last_auth_provider';
  static const _emailKey = 'last_auth_email';

  static Future<RememberedAuthMethod?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final provider = preferences.getString(_providerKey);
    if (provider == null || provider.isEmpty) return null;
    return RememberedAuthMethod(
      provider: provider,
      email: (preferences.getString(_emailKey) ?? '').trim().toLowerCase(),
    );
  }

  static Future<void> remember({
    required String provider,
    required String email,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_providerKey, provider),
      preferences.setString(_emailKey, email.trim().toLowerCase()),
    ]);
  }
}
