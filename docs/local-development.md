# Local development

## Mobile application

Install packages and start a device or simulator:

```bash
/Users/malamachiluwe/Programming/flutter/bin/flutter pub get
/Users/malamachiluwe/Programming/flutter/bin/flutter devices
/Users/malamachiluwe/Programming/flutter/bin/flutter run
```

Use a real device whenever a change touches Google sign-in, maps, media
capture, secure storage, or notifications. Widget tests and simulators do not
replace those checks.

## API connection

`ApiConfig` currently targets the local Laravel API on port 8000. Desktop and
web use `http://127.0.0.1:8000`; iOS and Android use
`http://malamas-MacBook-Pro.local:8000` by default. A physical phone must be
on the same network as this Mac. Start Laravel so it listens for devices:

```bash
cd '/Users/malamachiluwe/Programming/house backend'
php artisan serve --host=0.0.0.0 --port=8000 --no-reload
```

For an Android emulator, use `--dart-define=DEV_API_HOST=10.0.2.2` with
`flutter run`. If a phone cannot resolve the Mac hostname, set
`DEV_API_HOST` to the Mac's LAN IP instead. `API_ORIGIN` can override the
complete origin. Rebuild the app after changing Dart defines.

The API uses the `/api` prefix. Check the local health endpoint at:

```text
http://127.0.0.1:8000/api/health
```

## Paired backend

The app depends on the Laravel project at:

```text
/Users/malamachiluwe/Programming/house backend
```

For a normal local session:

```bash
cd '/Users/malamachiluwe/Programming/house backend'
php artisan migrate
```

Marketplace notifications, saved-search alerts, and reservation-expiry work
are queued. For local development, run a worker when `QUEUE_CONNECTION` is not
`sync`:

```bash
php artisan queue:work
```

The dashboard is in `admin-dashboard/`. Its README explains the administrator
bootstrap and `.env.local` setup.

## Common validation

```bash
/Users/malamachiluwe/Programming/flutter/bin/flutter analyze
/Users/malamachiluwe/Programming/flutter/bin/flutter test
/Users/malamachiluwe/Programming/flutter/bin/flutter build apk --debug
```

If native dependencies changed, also run:

```bash
cd ios
pod install
cd ..
/Users/malamachiluwe/Programming/flutter/bin/flutter build ios --simulator --no-codesign
```

An iOS simulator build proves compilation only. It cannot prove APNs delivery,
camera use, or production code signing.

## Working-tree hygiene

Flutter, CocoaPods, and Xcode may update generated files. Review source and
configuration changes separately from generated iOS files before committing.
Never reset a shared dirty checkout just to make a command pass.

Keep these out of version control:

- Android keystores and `android/key.properties`.
- Firebase service-account JSON.
- APNs `.p8` keys.
- Production API, database, and dashboard secrets.
