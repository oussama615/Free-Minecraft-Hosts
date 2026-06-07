StrawIO VoiceChat

StrawIO VoiceChat is a Flutter Android application developed by StrawIO Studio for a future cross-platform Minecraft voice-chat system.

«Current phase: Flutter Android application foundation. Real Minecraft detection, backend integration, plugin communication, and voice transmission are still under development.»

Project structure

The Flutter application is located inside:

mobile/

Future system architecture:

StrawIO VoiceChat App
        ↕
StrawIO Voice Backend
        ↕
StrawIOVoiceChat Minecraft Plugin
        ↕
Minecraft Java and Bedrock players

Requirements

- Flutter stable
- Dart SDK included with Flutter
- Android SDK
- Java 17 or the Java version required by the installed Flutter release
- Android device or emulator

Check the development environment:

flutter doctor -v

Install dependencies

cd mobile
flutter pub get

Run on Android emulator

Android Emulator uses "10.0.2.2" to access services running on the host computer:

cd mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

"10.0.2.2" works only from an Android emulator.

Run on a physical Android phone

The phone and computer must be connected to the same Wi-Fi network.

Find the computer's local IP address and use it instead:

cd mobile
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:3000

Replace "192.168.1.50" with the actual local IP of the computer running the backend.

The backend must listen on:

0.0.0.0:3000

Using "localhost" on the phone would point to the phone itself, not the computer.

Build release APK

For emulator development configuration:

cd mobile
flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:3000

For a physical phone on the same network:

cd mobile
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.50:3000

The APK output is:

mobile/build/app/outputs/flutter-apk/app-release.apk

API base URL

The app should read the backend address using:

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

Do not hardcode local or production backend addresses into Dart source code.

Android embedding

The Android project must use Flutter Android embedding v2.

The main activity should import:

import io.flutter.embedding.android.FlutterActivity

Legacy Android v1 embedding APIs must not be used, including:

io.flutter.app.FlutterActivity
io.flutter.app.FlutterApplication
PluginRegistry.Registrar
GeneratedPluginRegistrant.registerWith

The Android manifest should include:

<meta-data
    android:name="flutterEmbedding"
    android:value="2" />

Development security

- Do not commit API keys.
- Do not commit database credentials.
- Do not commit ".env" files.
- Do not commit Android signing keystores.
- Do not commit signing passwords.
- Do not place backend master secrets inside the application.
- Do not disable TLS certificate validation.
- Do not enable unrestricted cleartext traffic in release builds.

HTTP may be permitted only in debug builds for local network testing.

Production communication must use HTTPS.

Current application state

The application currently focuses on:

- StrawIO VoiceChat branding
- Automatic connection status interface
- Safe configuration foundation
- Future backend integration preparation
- Future Minecraft integration preparation

The production interface must not hardcode a specific player name.

Values such as:

xk7
Hivel Network

may be used only as preview or debug data.

The default production state should be:

Player: Not detected
Server: Waiting for Minecraft
Status: Standby

Tests and analysis

Run:

cd mobile
flutter analyze
flutter test

Then verify the release build:

flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:3000

GitHub Actions

The build command must use a raw URL:

- name: Build release APK
  run: flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:3000

Do not use Markdown link syntax inside the shell command.

The artifact path is:

mobile/build/app/outputs/flutter-apk/app-release.apk

Known limitations

- Real backend integration is not complete.
- Real Minecraft Bedrock detection is not complete.
- The Minecraft plugin is developed separately.
- Voice recording and streaming are not complete.
- "10.0.2.2" does not work on physical phones.
- Local HTTP configuration must not be used for production.

Developed by

StrawIO Studio
Minecraft & Discord Development Studio

Website: "https://strawio.net"