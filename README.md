# SSHetu

SSH client and server manager for every device.

Generated with [beej](https://github.com/lohanidamodar/beej).

## Getting started

```sh
flutter pub get
flutter run
```

## What's in the box

- **Material** via `package:material_ui` (decoupled from the Flutter SDK)
- **Riverpod 3** for state, no code generation
- **go_router** for routing
- **Localization** in `lib/l10n/` — en
- **Theming** with a user-selectable accent, theme mode and text size
- **No backend and no account.** Hosts, keys and tunnels live on the device;
  moving them to another device is a direct one-shot transfer over the local
  network, sealed by a single-use secret in a QR code
- **sqflite** local database with numbered migrations
- **fastlane** lanes for Play and the App Store

See [PROJECT.md](PROJECT.md) for the full tour.
