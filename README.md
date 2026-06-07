# StrawIO VoiceChat Android

StrawIO VoiceChat is a native Android application foundation for a future Minecraft Bedrock voice-chat ecosystem developed by **StrawIO Studio**.

> Current phase: Android application only. The backend, Minecraft plugin, voice relay, real Minecraft detection, and real voice transmission are not included yet.

## Product overview

The app presents the StrawIO VoiceChat brand, a premium dark status interface, and safe local connection states. It is designed to later connect automatically when Minecraft Bedrock joins a server that supports the future StrawIO VoiceChat plugin.

Future architecture target:

```text
StrawIO VoiceChat App
↕
Minecraft Bedrock Client Integration
↕
StrawIO VoiceChat Plugin
↕
StrawIO Voice Backend
```

## Supported Android versions

- Minimum SDK: Android 10 / API 29.
- Target SDK: API 35 in this repository configuration.
- Java compatibility: 17.
- UI: single-activity Jetpack Compose with Material 3.

## Build requirements

- Android SDK with API 35 and build tools installed.
- Gradle 8.14+ or compatible wrapper if added by the release engineer.
- JDK capable of compiling Java 17 bytecode.
- Network access for first dependency resolution.

## How to run

```bash
cd mobile/android
gradle :app:assembleDebug
```

Install the debug APK from:

```text
mobile/android/app/build/outputs/apk/debug/app-debug.apk
```

## Architecture summary

The Android app uses Kotlin, Jetpack Compose, Material 3, MVVM, StateFlow, Kotlin Coroutines, Hilt, DataStore, Android Keystore, Gradle Kotlin DSL, and a single-activity architecture.

Important package areas:

- `com.strawio.voicechat.ui` — Compose UI, premium dark theme, home screen, and local privacy dialog.
- `com.strawio.voicechat.domain` — strongly typed voice chat states, safe errors, state formatting, and future service interfaces.
- `com.strawio.voicechat.data` — safe local/no-op implementations for phase one.
- `com.strawio.voicechat.security` — Android Keystore device identity foundation.
- `com.strawio.voicechat.network` — HTTPS-only OkHttp foundation, TLS policy, redaction, and certificate pin rotation support.
- `com.strawio.voicechat.di` — Hilt bindings.

## State model

Production starts in `WaitingForMinecraft`, rendered as:

- Player: `Not detected`
- Server: `Waiting for Minecraft`
- Status: `Standby`

Supported state types include initializing, waiting for Minecraft, Minecraft detected, waiting for supported server, connecting, connected automatically, connection lost, unsupported server, permission required, app update required, and error.

`xk7` and `Hivel Network` are preview/debug sample values only and are not production identity defaults.

## Security model

- No production secrets are stored in source code, resources, assets, native libraries, or BuildConfig.
- Android Keystore generates a non-exportable EC P-256 device key pair.
- DataStore stores only the public key identifier and non-sensitive preferences.
- HTTPS-only network policy is configured.
- Cleartext traffic is disabled in the manifest and network security config.
- Certificate pinning support requires backup pins for rotation.
- Release builds enable minification and resource shrinking.
- Client anti-tamper/integrity checks are treated only as defense-in-depth signals.

## Privacy model

Phase one does not record audio, store audio, upload personal data, track users, show ads, use analytics, or create user accounts. Future voice features must request microphone permission explicitly before recording.

See [`PRIVACY.md`](PRIVACY.md) for the complete local privacy notice.

## Permissions

Only `android.permission.INTERNET` is declared for future backend communication. Microphone, storage, contacts, location, camera, SMS, phone, accessibility, overlay, VPN, and device administrator permissions are not declared in this phase.

## Known limitations

- No real Minecraft Bedrock detection yet.
- No backend connection yet.
- No Minecraft plugin yet.
- No voice relay or microphone recording yet.
- No production release signing material is committed.
- Certificate pins are not enabled until the backend endpoint and rotation plan are finalized.

## Future integration plan

### Backend next step

Define the public StrawIO VoiceChat backend API contract and implement a challenge-response handshake endpoint that accepts the Android Keystore public key identifier, verifies signed challenges server-side, enforces protocol version compatibility, and returns only sanitized connection metadata.

### Minecraft 1.21.11 Paper/Purpur plugin next step

Create a separate plugin project that exposes a signed server capability advertisement for supported servers, then implement a plugin-to-backend registration handshake. Keep plugin signing private keys outside the Android app and repository.

## Screenshots

Add approved production screenshots here after running the app on a device or emulator. The first screen should match the premium dark StrawIO microphone reference design.

## Release signing

Do not commit release keystores or passwords. Configure release signing with environment variables:

```bash
export STRAWIO_RELEASE_STORE_FILE=/secure/path/strawio-release.jks
export STRAWIO_RELEASE_STORE_PASSWORD='***'
export STRAWIO_RELEASE_KEY_ALIAS=strawio
export STRAWIO_RELEASE_KEY_PASSWORD='***'
cd mobile/android
gradle :app:assembleRelease
```

The current Gradle file falls back to the debug key only so CI can verify an unsigned-production-equivalent release build. Use a real signing config before distribution.

## Testing

Run:

```bash
cd mobile/android
gradle :app:testDebugUnitTest
gradle :app:lintDebug
gradle :app:assembleDebug
gradle :app:assembleRelease
```

## Warning: do not commit secrets

Never commit API keys, backend secrets, private keys, database credentials, plugin signing keys, keystores, signing passwords, local properties, generated credentials, or environment files.
