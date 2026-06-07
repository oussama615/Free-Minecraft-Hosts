# Free Minecraft Hosts / Mobile App

This repository contains Minecraft server tooling, a backend, and an existing Flutter Android application under `mobile/`.

## Flutter Android app

The mobile application is built with Flutter and keeps its existing UI and behavior. Android integration uses Flutter Android embedding v2.

### Run locally

Use `http://10.0.2.2:3000` only when running on an Android emulator, because that address maps to the host machine from the emulator:

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

For a physical Android phone on the same Wi-Fi network, use the host machine's LAN IP instead, for example:

```bash
cd mobile
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:3000
```

The API URL is read through `String.fromEnvironment('API_BASE_URL')`; do not hardcode local emulator URLs or production credentials into Dart source code.

### Build release APK

For Android emulator testing:

```bash
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

For a real phone on your Wi-Fi, replace the URL with your host machine's LAN IP:

```bash
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.50:3000
```

The release APK output path is:

```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```

Or use the helper script and pass the API URL explicitly:

```bash
mobile/scripts/build_release_apk.sh http://10.0.2.2:3000
```

## Security notes

- Do not commit API keys, database credentials, keystore files, signing passwords, or generated secrets.
- Release Android manifest configuration disables cleartext traffic by default.
- Debug/profile Android manifests allow cleartext only for local development hosts such as `10.0.2.2`, `localhost`, and `127.0.0.1`.
- The emulator URL `http://10.0.2.2:3000` is a development value, not a production backend URL.

## IslandForge local island generator

IslandForge is a local Python tool that turns a top-down PNG/JPG island mask and a text prompt into a WorldEdit/FAWE-compatible `.schem` file.

### Install

```bash
python -m pip install -r requirements-islandforge.txt
```

### Basic usage

```bash
python islandforge.py input.png \
  --theme jungle \
  --prompt "Create a jungle island with a ruined temple, curved terrain, a hidden cave, rich foliage, and a warm green palette." \
  --size 150 \
  --height 25 \
  --detail detailed \
  --output jungle_island.schem
```

IslandForge writes three files next to the output path:

- `*.schem` — Sponge/WorldEdit v2 schematic containing generated terrain and features.
- `*.preview.png` — top-down color preview with feature markers.
- `*.metadata.json` — generation settings, seed, palette, and placed feature coordinates.
