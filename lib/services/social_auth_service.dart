import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/config/oauth_config.dart';
import 'package:house_rent/services/api_error.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/services/auth_method_memory.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SocialAuthService {
  SocialAuthService._();

  static const _webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: OAuthConfig.googleWebClientId,
  );
  static const _iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: OAuthConfig.googleIosClientId,
  );
  static Future<void>? _googleInitialization;

  static Future<SocialAuthResult> signInWithGoogle() async {
    if (_webClientId.isEmpty) {
      throw const SocialAuthException(
        'Google sign-in needs the Web OAuth client ID. Launch Haven with '
        '--dart-define=GOOGLE_WEB_CLIENT_ID=your-client-id.',
      );
    }
    if (Platform.isIOS && _iosClientId.isEmpty) {
      throw const SocialAuthException(
        'Google sign-in needs the iOS OAuth client ID for Haven Zambia.',
      );
    }

    try {
      final google = GoogleSignIn.instance;
      _googleInitialization ??= google.initialize(
        clientId: Platform.isIOS ? _iosClientId : null,
        serverClientId: _webClientId,
      );
      await _googleInitialization;
      if (!google.supportsAuthenticate()) {
        throw const SocialAuthException(
            'Google sign-in is unavailable on this device.');
      }

      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const SocialAuthException(
            'Google did not return a secure identity token. Try again.');
      }
      final response = await http
          .post(
            Uri.parse('${ApiConfig.apiBase}/auth/google'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'id_token': idToken}),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        final failure = HavenApiException.fromResponse(response,
            operation: 'sign you in with Google');
        if (failure.code == 'password_account_exists') {
          throw SocialAuthAccountConflict(
            email: account.email,
            requiredMethod: 'password',
            message: failure.message,
            identityToken: idToken,
          );
        }
        throw failure;
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final token = payload['access_token']?.toString();
      if (token == null || token.isEmpty) {
        throw const SocialAuthException(
            'Haven did not receive a valid account session from Google.');
      }
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('access_token', token);
      final user = payload['user'] is Map
          ? Map<String, dynamic>.from(payload['user'] as Map)
          : <String, dynamic>{};
      await AuthMethodMemory.remember(
        provider: 'google',
        email: user['email']?.toString() ?? account.email,
      );
      await SessionService.currentUser(forceRefresh: true);
      return SocialAuthResult(
        provider: 'google',
        isNewUser: payload['is_new_user'] == true,
        requiresProfileCompletion:
            payload['requires_profile_completion'] == true,
        user: user,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const SocialAuthCanceled();
      }
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw SocialAuthException(
          'Google sign-in is not configured correctly for this app build. '
                  '${error.description ?? ''}'
              .trim(),
        );
      }
      throw SocialAuthException(
          error.description ?? 'Google sign-in could not be completed.');
    } on MissingPluginException {
      // Native plugins cannot be added by hot reload/restart because the host
      // app binary and GeneratedPluginRegistrant must be rebuilt.
      _googleInitialization = null;
      throw const SocialAuthException(
        'Google sign-in was added after this copy of Haven started. Stop the '
        'app completely and launch it again so the native Google service can load.',
      );
    } on PlatformException catch (error) {
      _googleInitialization = null;
      final raw = '${error.code} ${error.message ?? ''}'.toLowerCase();
      if (raw.contains('channel') || raw.contains('connection')) {
        throw const SocialAuthException(
          'The native Google sign-in service is not loaded in this app build. '
          'Stop Haven completely and run a fresh build instead of hot restarting.',
        );
      }
      throw SocialAuthException(
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'This device could not complete Google sign-in (${error.code}).',
      );
    }
  }

  static Future<void> linkGoogleToSignedInAccount({
    required String accessToken,
    required String identityToken,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.apiBase}/auth/google/link'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'id_token': identityToken}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw HavenApiException.fromResponse(response,
          operation: 'connect Google to your Haven account');
    }
  }

  /// Starts Google’s native account picker without changing the current
  /// Haven session, then attaches the selected identity to that session.
  static Future<void> connectGoogleFromSettings({
    required String accessToken,
  }) async {
    if (_webClientId.isEmpty || (Platform.isIOS && _iosClientId.isEmpty)) {
      throw const SocialAuthException(
        'Google sign-in is not configured for this Haven build.',
      );
    }
    try {
      final google = GoogleSignIn.instance;
      _googleInitialization ??= google.initialize(
        clientId: Platform.isIOS ? _iosClientId : null,
        serverClientId: _webClientId,
      );
      await _googleInitialization;
      if (!google.supportsAuthenticate()) {
        throw const SocialAuthException('Google sign-in is unavailable on this device.');
      }
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const SocialAuthException('Google did not return a secure identity token. Try again.');
      }
      await linkGoogleToSignedInAccount(
        accessToken: accessToken,
        identityToken: idToken,
      );
      await SessionService.currentUser(forceRefresh: true);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const SocialAuthCanceled();
      }
      throw SocialAuthException(error.description ?? 'Google connection could not be completed.');
    }
  }
}

class SocialAuthResult {
  const SocialAuthResult({
    required this.provider,
    required this.isNewUser,
    required this.requiresProfileCompletion,
    required this.user,
  });

  final String provider;
  final bool isNewUser;
  final bool requiresProfileCompletion;
  final Map<String, dynamic> user;
}

class SocialAuthException implements Exception {
  const SocialAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SocialAuthCanceled extends SocialAuthException {
  const SocialAuthCanceled() : super('Google sign-in was cancelled.');
}

class SocialAuthAccountConflict extends SocialAuthException {
  const SocialAuthAccountConflict({
    required this.email,
    required this.requiredMethod,
    required this.identityToken,
    required String message,
  }) : super(message);

  final String email;
  final String requiredMethod;
  final String identityToken;
}
