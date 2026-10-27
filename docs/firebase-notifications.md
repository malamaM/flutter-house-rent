# Haven Firebase notifications

Haven is connected to the Firebase project `haven-zambia-20260909`.

## Mobile configuration

- Android app: `com.malamachiluwe.haven`
- iOS app: `com.malamachiluwe.haven`
- Android config: `android/app/google-services.json`
- iOS config: `ios/Runner/GoogleService-Info.plist`
- Flutter options: `lib/firebase_options.dart`

The Flutter client requests notification permission after a user signs in,
registers the FCM token with `POST /api/device-tokens`, retries token changes,
removes the token during logout, and refreshes the existing Haven notification
inbox when a push is received or opened.

## Backend delivery secret

The Laravel channel sends notification payloads through Firebase HTTP v1 when
these deployment secrets are configured:

```dotenv
HAVEN_FCM_PROJECT_ID=haven-zambia-20260909
HAVEN_FCM_SERVICE_ACCOUNT_PATH=/secure/path/haven-fcm-service-account.json
# Or use HAVEN_FCM_SERVICE_ACCOUNT_JSON as a secret instead of a file path.
```

Use a dedicated Google service account with the Firebase Cloud Messaging sender
permission. Store its private-key JSON only in the deployment secret store; do
not commit it or place it in the Flutter app. The existing provider-neutral
gateway remains available as a fallback through `HAVEN_PUSH_GATEWAY_URL`.

## iOS provider setup

Before testing on a physical Apple device, upload an APNs authentication key to
Firebase Console → Project settings → Cloud Messaging, providing the Apple key
ID and team ID. Apple push notifications also require a provisioning profile
with Push Notifications enabled.

`ios/Runner/Runner.entitlements` contains the `aps-environment` entitlement,
but it must be attached to the Runner target through the Xcode
`CODE_SIGN_ENTITLEMENTS` build setting before an iOS archive can receive APNs
notifications. Set `APS_ENVIRONMENT` to the appropriate development or
production value for the signing profile. The remote-notification background
mode is declared in `ios/Runner/Info.plist`.

## Verification

1. Build and install a fresh native app; hot reload cannot load Firebase native
   plugins.
2. Sign in and accept notifications.
3. Confirm the authenticated user has a row in `device_tokens`.
4. Confirm the Laravel deployment has `HAVEN_FCM_PROJECT_ID` and a valid
   service-account secret, plus an active queue worker when notifications are
   queued.
5. Trigger a Haven conversation, viewing, reservation, or saved-search event,
   then verify the system notification and the in-app notification inbox.

## What is not covered by automated tests

The Flutter test suite does not initialize Firebase native plugins, and the
Laravel feature suite does not send a real message to FCM. Treat the physical
device flow above as mandatory release verification, not an optional smoke
test.
