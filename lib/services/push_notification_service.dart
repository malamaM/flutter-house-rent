import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/firebase_options.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/services/session_token_store.dart';
import 'package:http/http.dart' as http;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Owns FCM registration while Haven's Laravel notification inbox remains the
/// authoritative record of notification state.
class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();
  static const _notificationCache = 'marketplace:notifications:v2';

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  Future<void>? _initialization;

  Future<void> initialize() =>
      _initialization ??= _initialize().catchError((_) {});

  Future<void> _initialize() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    _messageSubscription = FirebaseMessaging.onMessage.listen((_) {
      unawaited(_invalidateNotificationCache());
    });
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((_) {
      unawaited(_invalidateNotificationCache());
    });
    _tokenSubscription = _messaging.onTokenRefresh.listen(
      (token) => unawaited(_registerToken(token)),
      onError: (_) {},
    );
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _invalidateNotificationCache();
    }
  }

  /// Requests the platform permission only after Haven has an authenticated
  /// user, then associates the current FCM token with that Haven account.
  Future<void> registerForCurrentUser() async {
    await initialize();
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    final token = await SessionTokenStore.read();
    if (token == null || token.isEmpty) return;
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // iOS does not guarantee that APNs has issued its token before FCM token
    // requests. Give the native registration a short, bounded opportunity.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      String? apnsToken;
      for (var attempt = 0; attempt < 10 && apnsToken == null; attempt++) {
        apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
      if (apnsToken == null) return;
    }
    final fcmToken = await _messaging.getToken();
    if (fcmToken != null && fcmToken.isNotEmpty) {
      await _registerToken(fcmToken);
    }
  }

  Future<void> unregisterCurrentDevice() async {
    final token = await SessionTokenStore.read();
    if (token == null || token.isEmpty) return;
    try {
      await initialize();
      final fcmToken = await _messaging.getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;
      await http
          .delete(
            Uri.parse('${ApiConfig.apiBase}/device-tokens'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'token': fcmToken}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Logout must still clear the local session if the device is offline.
    }
  }

  Future<void> _registerToken(String fcmToken) async {
    final accessToken = await SessionTokenStore.read();
    if (accessToken == null || accessToken.isEmpty) return;
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : defaultTargetPlatform == TargetPlatform.android
            ? 'android'
            : null;
    if (platform == null) return;
    try {
      await http
          .post(
            Uri.parse('${ApiConfig.apiBase}/device-tokens'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'token': fcmToken, 'platform': platform}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Token refresh is retried on the next app start or token refresh event.
    }
  }

  Future<void> _invalidateNotificationCache() async {
    try {
      final key = await AppCache.instance.privateKey(_notificationCache);
      await AppCache.instance.remove(key);
      AppCache.instance.announce(_notificationCache, key);
    } catch (_) {
      // Notifications should never make an otherwise healthy app fail.
    }
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
