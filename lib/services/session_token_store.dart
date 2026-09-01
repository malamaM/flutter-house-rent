import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores bearer tokens in Android Keystore, iOS Keychain, and the secure
/// storage web implementation. The SharedPreferences fallback is only for
/// platforms where the native secure-storage plugin is unavailable; any legacy
/// token is migrated on the first successful read/write and then removed.
class SessionTokenStore {
  SessionTokenStore._();

  static const _key = 'access_token';
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    webOptions: WebOptions(
      dbName: 'HavenSecureStorage',
      publicKey: 'HavenAccessToken',
    ),
  );

  static Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final legacyToken = preferences.getString(_key);
    String? secureToken;
    try {
      secureToken = await _storage.read(key: _key);
    } on MissingPluginException {
      // Tests and unsupported targets may not register a native secure
      // storage implementation. Preserve the legacy compatibility path only
      // for that explicit case.
      return legacyToken?.isNotEmpty == true ? legacyToken : null;
    } catch (_) {
      // A real keychain/keystore error must fail closed rather than downgrade
      // an existing session back to plaintext preferences.
      return null;
    }
    if (secureToken != null && secureToken.isNotEmpty) {
      await preferences.remove(_key);
      return secureToken;
    }

    if (legacyToken == null || legacyToken.isEmpty) return null;
    try {
      await _storage.write(key: _key, value: legacyToken);
      await preferences.remove(_key);
    } on MissingPluginException {
      // Keep the legacy value so an unsupported target can still function.
    } catch (_) {
      // Do not silently downgrade after a keychain/keystore failure.
      return null;
    }
    return legacyToken;
  }

  static Future<void> write(String token) async {
    final preferences = await SharedPreferences.getInstance();
    try {
      await _storage.write(key: _key, value: token);
      await preferences.remove(_key);
    } on MissingPluginException {
      // This is only a compatibility fallback for unsupported targets.
      await preferences.setString(_key, token);
    }
  }

  static Future<void> delete() async {
    final preferences = await SharedPreferences.getInstance();
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // The legacy cleanup below still invalidates the local session.
    }
    await preferences.remove(_key);
  }
}
