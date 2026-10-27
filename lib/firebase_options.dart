// Generated for the Haven Firebase project. These identifiers are public
// client configuration; server credentials remain in backend environment
// secrets and are never stored in this file.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Haven Firebase configuration is currently limited to iOS and Android.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Haven Firebase configuration is not available for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDO_FhettoTWGAZ6J_ZdcjGJBs-9UZY6Wo',
    appId: '1:733739202479:android:ca02a6986c77c2a87ee15a',
    messagingSenderId: '733739202479',
    projectId: 'haven-zambia-20260909',
    storageBucket: 'haven-zambia-20260909.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD4GNSz0B3tsf4LQfStteNah3_yUDuxp_w',
    appId: '1:733739202479:ios:b0999aa39b674ee97ee15a',
    messagingSenderId: '733739202479',
    projectId: 'haven-zambia-20260909',
    storageBucket: 'haven-zambia-20260909.firebasestorage.app',
    iosBundleId: 'com.malamachiluwe.haven',
  );
}
