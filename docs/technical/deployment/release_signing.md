# Android Release Signing

The Android release build is wired to sign with a release keystore when
`mobile/android/key.properties` exists, and to fall back to the debug keystore
otherwise (so local `flutter build apk --release` keeps working without setup).

This document covers the one-time setup to produce a Play Store–ready,
properly signed release build.

## Why this matters

- Builds signed with the **debug keystore** cannot be uploaded to the Play
  Store and are not trusted on production devices.
- The **release keystore** identity must be preserved for the lifetime of the
  app: losing it means you cannot publish updates to the same listing. Back it
  up somewhere durable (password manager, encrypted backup, cloud vault).

## 1. Generate the keystore (one-time)

Run this once and store the generated `.jks` somewhere safe. Use a strong,
unique password and remember it.

```bash
keytool -genkey -v -keystore coverwise-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias coverwise
```

You will be prompted for:
- a keystore password
- a key password (can be the same)
- your name/org details

Move the keystore to `mobile/android/coverwise-upload.jks` (it is gitignored —
see below) or keep it in a secure location outside the repo and reference its
absolute path.

## 2. Create `mobile/android/key.properties`

Create this file (it is gitignored — never commit secrets):

```properties
storePassword=<your keystore password>
keyPassword=<your key password>
keyAlias=coverwise
storeFile=coverwise-upload.jks
```

`storeFile` is resolved relative to `mobile/android/`, so a bare filename works
if the keystore lives there. Use an absolute path if it lives elsewhere.

## 3. Build the release

```bash
cd mobile
flutter build apk --release       # APK for direct distribution
flutter build appbundle --release  # AAB for Play Store upload
```

The build reads `key.properties`, loads the keystore, and signs the output. If
`key.properties` is absent, the build still succeeds but uses the debug
keystore (with a clear note in the gradle config).

## Verification

Confirm the APK is signed with your release key (not the debug key):

```bash
# debug key alias is "androiddebugkey"; release should show "coverwise"
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

## Backing up the keystore

This keystore is the identity of the app for the Play Store. Losing it means
you cannot publish updates. Use Google Play App Signing (opt in in the Play
Console) so Google holds the signing key and your upload key is only for
uploading — this protects against total keystore loss.
