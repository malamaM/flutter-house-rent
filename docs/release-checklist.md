# Haven mobile release checklist

Use this checklist for every test distribution and production release. A
successful compilation alone is not a releasable mobile build.

## 1. Decide the release version

Update `version` in `pubspec.yaml` before building. The build number must
increase for every upload to a store or test-distribution channel.

Record the release version, commit SHA, API environment, and tester group in
the release notes.

## 2. Confirm backend readiness

- The deployed API health endpoint responds.
- Required migrations are applied.
- The database queue worker is running when `QUEUE_CONNECTION=database`.
- Firebase FCM server credentials are configured if push notifications are
  part of this release.
- The dashboard and API changes paired with the mobile build are deployed or
  deliberately held back behind compatible behavior.

## 3. Run automated checks

```bash
/Users/malamachiluwe/Programming/flutter/bin/flutter analyze
/Users/malamachiluwe/Programming/flutter/bin/flutter test
/Users/malamachiluwe/Programming/flutter/bin/flutter build apk --debug
git diff --check -- . ':(exclude)ios/Pods/**' ':(exclude)ios/.symlinks/**'
```

For cross-stack releases, also run:

```bash
cd '/Users/malamachiluwe/Programming/house backend'
php artisan test
cd admin-dashboard && npm run lint && npm run typecheck && npm run build
```

## 4. Verify on real devices

Test at least one supported Android device and one physical iPhone when iOS is
being distributed. Cover:

- New account, email/password sign-in, sign-out, and session expiry.
- Google sign-in when enabled for the release.
- Browse, search, filters, saved homes, listing details, and media playback.
- Listing creation/editing, viewing requests, conversations, and reservations.
- Offline recovery and relaunch.
- Notification permission, token registration, foreground delivery,
  background delivery, and notification tap behavior.

Record any intentionally unavailable feature in release notes; do not label it
as complete because its screen exists.

## 5. Build a signed Android release

Production Android builds need either an ignored `android/key.properties` file
or these environment variables:

```text
ANDROID_KEYSTORE_PATH
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

Then build:

```bash
/Users/malamachiluwe/Programming/flutter/bin/flutter build apk --release
```

The expected artifact is:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Verify the output before distribution:

```bash
unzip -tq build/app/outputs/flutter-apk/app-release.apk
zipalign -c -v 4 build/app/outputs/flutter-apk/app-release.apk
apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk
```

Do not distribute a release build that reports it is unsigned.

## 6. Prepare an iOS release

- Add `Runner.entitlements` to the Runner target through
  `CODE_SIGN_ENTITLEMENTS`.
- Set the APNs entitlement to the correct development or production value.
- Use a provisioning profile with Push Notifications enabled.
- Upload the APNs authentication key to the Firebase project.
- Archive and validate through Xcode or the configured distribution pipeline.

An iOS simulator build is insufficient for push or App Store readiness.

## 7. Final handoff

- Include release notes and known limitations.
- Keep signing files and service-account secrets out of Git.
- Confirm the artifact path, version, package ID, checksum, and signing
  certificate.
- Preserve a clear rollback target: the previous store release or tested APK.
