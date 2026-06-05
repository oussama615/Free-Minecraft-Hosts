@@ -180,68 +180,65 @@ Plugin commands:
 - `/empcontrol unlink`
 - `/empcontrol reload`
 - `/empcontrol testalert`
 - `/empcontrol panic on`
 - `/empcontrol panic off`
 - Alias: `/empc`
 
 ## 6. Run the Flutter app locally
 
 Open a terminal in `mobile/`:
 
 ```bash
 cd mobile
 flutter pub get
 flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
 ```
 
 Use `http://10.0.2.2:3000` for the Android emulator.
 
 For a physical Android phone on the same Wi-Fi, use your PC LAN IP:
 
 ```bash
 flutter run --dart-define=API_BASE_URL=http://192.168.1.25:3000
 ```
 
-The app displays the API URL baked into the app so you can verify it.
+The API URL remains configured through `--dart-define=API_BASE_URL=...`, but the main app UI intentionally avoids exposing technical URL/debug clutter.
 
-### Local Demo Mode
+### MVP preview without backend
 
-The APK can open even when the backend is not running. On startup, the app checks `API_BASE_URL`; if the API is unreachable, it enters **Local Demo Mode** instead of crashing or blocking on login.
+The APK can open even when the backend is not running. During this MVP preview, any non-empty username/email and any non-empty password opens the premium control panel so the app can be reviewed immediately on an emulator or phone.
 
-In Local Demo Mode:
+Important preview behavior:
 
-- The premium login screen still opens when the backend is offline.
-- During the MVP, any non-empty username/email and any non-empty password can enter Demo Mode, or you can tap **Continue in Demo Mode**.
-- Demo login creates an in-memory Demo Owner session only; it does not create backend tokens and must never be treated as production security.
-- The dashboard shows mock server chips for Lobby, Survival, BoxPvP, Lifesteal, and SkyBlock.
-- Server chips are mock until plugin-linked servers exist in the backend.
+- The preview sign-in is only for local review; it does not create production credentials or backend tokens.
+- Real monitoring and remote control still require the EMP Control API, a real OWNER login, and a linked EMPControlAgent plugin.
+- The dashboard uses mock server chips for Lobby, Survival, BoxPvP, Lifesteal, and SkyBlock until plugin-linked servers exist in the backend.
 - Tapping a server chip updates the selected server dashboard card and stats.
-- Start, Stop, and Restart buttons are preview-only and do not control a real server.
-- The Restart button is demo-only until the backend and EMPControlAgent plugin are connected; real restart/remote console actions are OWNER-only once auth is active.
-- Activity and Security screens show mock logs/events.
-- Real monitoring and control require the backend plus the Paper plugin agent to be running and linked with a real OWNER login.
+- Start, Stop, Restart, and console commands are preview-only unless backend auth and the plugin connection are active.
+- Permissions are editable in the UI for MVP preview; backend enforcement must be connected before treating them as production access control.
+- Activity and Logs are separate: **Activity** records app/control-panel user actions, while **Logs** records Minecraft server, player, command, security, and system events.
 
 ## 7. Build a downloadable Android APK
 
 Open a terminal in the repository root.
 
 For Android emulator testing:
 
 ```bash
 cd mobile
 flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:3000
 mkdir -p ../dist
 cp build/app/outputs/flutter-apk/app-release.apk ../dist/EMP-Control.apk
 ```
 
 For a real phone on your Wi-Fi, replace the URL with your PC LAN IP:
 
 ```bash
 cd mobile
 flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.25:3000
 mkdir -p ../dist
 cp build/app/outputs/flutter-apk/app-release.apk ../dist/EMP-Control.apk
 ```
 
 Or use the helper script:
 
@@ -407,36 +404,36 @@ DATABASE_URL="postgresql://emp:emp_dev_password@localhost:5432/emp_control?schem
 Then rerun:
 
 ```bash
 cd backend
 npm run prisma:migrate
 npm run prisma:seed
 npm run dev
 ```
 
 ### Minecraft plugin connection failed
 
 Check:
 
 - Backend is running at `http://localhost:3000`.
 - You created a server and generated a fresh pairing token.
 - Pairing tokens expire after 15 minutes by default.
 - In the Paper console, use `empcontrol link TOKEN http://localhost:3000`.
 - Run `empcontrol status` in the Paper console.
 - Backend logs should show `Agent websocket connected`.
 
 ### Android app cannot log in
 
 - Emulator: rebuild/run with `--dart-define=API_BASE_URL=http://10.0.2.2:3000`.
 - Physical phone: rebuild APK with `--dart-define=API_BASE_URL=http://YOUR_PC_LAN_IP:3000`.
 - Tunnel: rebuild APK with the HTTPS tunnel URL.
-- The app header/about screen shows which API URL the APK is using.
+- If login cannot reach the backend, the app still opens in MVP preview with mock servers, logs, activity, security, users, and permissions.
 
 ## Security notes for this MVP
 
 - There is no public registration. The first OWNER is seeded from environment variables only when no users exist.
 - Passwords and refresh tokens are hashed with Argon2id.
 - Pairing tokens are one-time and stored hashed in PostgreSQL.
 - Agent credentials are stored encrypted in `agent.dat`; no readable YAML secrets are created.
 - WebSocket envelopes include `serverId`, `timestamp`, `nonce`, `payload`, and `signature`; stale timestamps and nonce replays are rejected.
 - Remote console is OWNER-only, policy-checked, audited, signed by the backend, and dispatched only through Bukkit's console sender.
 - No file manager, plugin upload, shell command execution, server-file exposure, arbitrary class loading, or file browsing is implemented.
 
EOF
)

## IslandForge local island generator

IslandForge is a local Python tool that turns a top-down PNG/JPG island mask and a text prompt into a WorldEdit/FAWE-compatible `.schem` file. The image controls land versus empty space, while the prompt and theme control structures, mood, decorations, and block palette.

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
- `*.metadata.json` — generation settings, seed, palette, placed feature coordinates, and layout-specific zone coordinates.

### Inputs and options

- Positional `image`: PNG/JPG mask. Bright, opaque pixels become land; dark or transparent pixels become empty space.
- `--prompt`: text description used to place details such as ruins, trees, paths, caves, docks, temples, boss areas, mob areas, towers, and statues.
- `--theme`: one of `starter`, `mine`, `desert`, `jungle`, `frost`, `arena`, or `ancient`.
- `--size`: output width/length in blocks, from 16 to 512.
- `--height`: maximum terrain relief, from 6 to 128.
- `--detail`: `simple`, `balanced`, `detailed`, or `epic`.
- `--output`: destination `.schem` path.
- `--layout`: `island` for prompt-led decorative islands, or `spawn_hub` for a structured premium RPG starter spawn island.
- `--seed`: optional deterministic seed for repeatable generation.

### Spawn hub layout

Use `--layout spawn_hub` when the island should be a readable RPG starter spawn instead of a generic decorative island. This mode always stamps a large central plaza, secondary plaza, roughly 12 NPC/bot pads, clean stone roads, medieval buildings, a raised windmill hill, an edge dock/travel area, and an elevated boss/combat arena. The prompt still controls mood and decorative flavor, but the hub structure remains fixed and clear. Metadata includes `main_plaza`, `secondary_plaza`, `npc_spots`, `boss_arena`, `dock_area`, and `windmill_area` entries for downstream server/plugin setup.

```bash
python islandforge.py masks/spawn.png \
  --layout spawn_hub \
  --theme starter \
  --prompt "Premium medieval RPG starter spawn with quest NPCs, cozy market buildings, warm lanterns, forest details, and a heroic boss portal." \
  --size 180 \
  --height 32 \
  --detail epic \
  --output rpg_spawn_hub.schem
```

### Theme examples

```bash
python islandforge.py masks/circle.png --theme starter --prompt "cozy starter island with trees, paths, and a small ruin" --size 96 --height 18 --detail balanced --output starter.schem
python islandforge.py masks/cavern.jpg --theme mine --prompt "rocky mine island with caves, mob area, ore details, and wooden supports" --size 128 --height 32 --detail detailed --output mine.schem
python islandforge.py masks/arena.png --theme arena --prompt "boss arena island with towers, mob spawns, statues, and dramatic red accents" --size 160 --height 28 --detail epic --output arena.schem
python islandforge.py masks/ancient.png --theme ancient --prompt "ancient floating ruin with statues, cracked paths, temple, and hidden cave" --size 140 --height 30 --detail detailed --output ancient.schem
```
