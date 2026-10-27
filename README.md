# Haven Zambia

Haven is a Flutter marketplace for discovering rentals in Zambia. Renters can
search homes, save searches, arrange viewings, chat with listers, reserve
available viewing slots, and receive marketplace updates. Listers can create
and manage listings, availability, media, and reservation schedules.

The mobile app works with the Haven Laravel API and the separate Haven Command
administration dashboard.

## What is in this repository

- `lib/` — Flutter application code.
- `assets/` — bundled Haven brand assets.
- `test/` — unit and widget tests.
- `android/` and `ios/` — native mobile projects.
- `docs/` — operational and release documentation.

The paired projects live alongside this repository:

- Laravel API: `/Users/malamachiluwe/Programming/house backend`
- Haven Command dashboard: `/Users/malamachiluwe/Programming/house backend/admin-dashboard`

## Requirements

- Flutter SDK compatible with the Dart constraint in `pubspec.yaml`.
- Android Studio / Android SDK for Android builds.
- Xcode and CocoaPods for iOS builds.
- A running Haven Laravel API for sign-in and live marketplace data.

On this machine, Flutter is installed at:

```bash
/Users/malamachiluwe/Programming/flutter/bin/flutter
```

## Get started

From this repository:

```bash
/Users/malamachiluwe/Programming/flutter/bin/flutter pub get
/Users/malamachiluwe/Programming/flutter/bin/flutter run
```

For iOS dependency changes, refresh pods before opening the workspace:

```bash
cd ios
pod install
cd ..
```

Open `ios/Runner.xcworkspace`, rather than `Runner.xcodeproj`, in Xcode.

## API environment

The app defaults to the local Laravel API on port 8000. Desktop and web use
`http://127.0.0.1:8000`; phones use `http://malamas-MacBook-Pro.local:8000`
and must be on the same network as this Mac.

Start Laravel from the paired backend directory:

```bash
php artisan serve --host=0.0.0.0 --port=8000
```

For an Android emulator, run Flutter with `--dart-define=DEV_API_HOST=10.0.2.2`.
For a different computer or a phone that cannot resolve the local hostname,
pass `--dart-define=DEV_API_HOST=YOUR_COMPUTER_LAN_IP`.
You can override the entire origin with `--dart-define=API_ORIGIN=http://HOST:PORT`.
Restart/rebuild the app after changing these values. Local HTTP connections are
allowed in the Android and iOS configuration.

## Authentication

- Email/password sign-in and account creation are supported.
- Google sign-in is supported when the Android/iOS OAuth client registrations
  and backend Google web client ID are configured.
- Password recovery, Sign in with Apple, and Facebook sign-in are visible in
  the UI but are not implemented yet.

OAuth client identifiers are public app identifiers, not secrets. Never put an
OAuth client secret in this repository or in the mobile app.

## Firebase notifications

Haven uses Firebase Cloud Messaging to refresh the marketplace notification
inbox and display device notifications. The complete setup, deployment-secret
requirements, platform-specific work, and verification procedure are in
[docs/firebase-notifications.md](docs/firebase-notifications.md).

Before committing Firebase work, ensure these application files are included:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `ios/Runner/Runner.entitlements`
- `lib/firebase_options.dart`
- `lib/services/push_notification_service.dart`

Firebase client configuration is safe to version-control. Service-account JSON,
APNs private keys, VAPID private keys, Android signing keys, and API secrets
are not; keep them in the appropriate secret store.

## Quality checks

Run these before proposing a mobile change:

```bash
/Users/malamachiluwe/Programming/flutter/bin/flutter analyze
/Users/malamachiluwe/Programming/flutter/bin/flutter test
/Users/malamachiluwe/Programming/flutter/bin/flutter build apk --debug
git diff --check -- . ':(exclude)ios/Pods/**' ':(exclude)ios/.symlinks/**'
```

When a change affects the API or dashboard, also run from the paired backend:

```bash
php artisan test
cd admin-dashboard && npm run lint && npm run typecheck && npm run build
```

Passing the Flutter test suite does not prove native push delivery, production
signing, Google OAuth, payment collection, or authenticated dashboard flows.
Those need the relevant device, credentials, and end-to-end checks.

## Release process

Use [docs/release-checklist.md](docs/release-checklist.md) for a test or
production release. In particular, do not distribute an unsigned release APK.
The Android release build requires an untracked `android/key.properties` file
or `ANDROID_KEYSTORE_*` environment variables.

## Documentation

- [Local development](docs/local-development.md)
- [Firebase notifications](docs/firebase-notifications.md)
- [Release checklist](docs/release-checklist.md)

## Current product gaps

The following are intentionally not complete and should not be described as
available to users until implemented and verified:

- Password recovery, Apple sign-in, and Facebook sign-in.
- A real help-and-support destination.
- Physical-device notification delivery across Android and iOS.
- Production Android/iOS signing and store distribution.

Empty states for homes, tours, recommendations, and reservation dates are
normal when the API has no qualifying live inventory.
