# EMP Control — Local MVP

EMP Control is a secure local-test MVP for monitoring and controlling Minecraft Paper servers from an Android/Flutter app. You do **not** need a VPS for this pass.

## Project folders

- `backend/` — **EMP Control API** using Node.js, Fastify, Prisma, PostgreSQL, JWT auth, RBAC, audit logs, REST routes, and `/agent/ws` for Paper agents.
- `plugin/` — **EMPControlAgent** Paper plugin using Java 17, signed WebSocket messages, encrypted `agent.dat`, metrics heartbeats, dangerous-command monitoring, panic mode, and Bukkit-console-only remote command execution.
- `mobile/` — **EMP Control App** Flutter Android app with login, server list, stats dashboard, alerts, logs, security events, owner console, users, and settings.
- `dist/` — local build output folder. It is ignored by git and is used for `EMPControlAgent.jar` and `EMP-Control.apk`.

## Exact local URLs

Use these URLs depending on where the Android app is running:

- Backend on your PC: `http://localhost:3000`
- Android emulator talking to your PC: `http://10.0.2.2:3000`
- Physical Android phone talking to your PC: `http://YOUR_PC_LAN_IP:3000`, for example `http://192.168.1.25:3000`
- Optional tunnel for a phone outside your LAN: `https://xxxx.trycloudflare.com` or an ngrok URL

## 1. Start PostgreSQL locally with Docker Compose

Open a terminal in the repository root:

```bash
docker compose up -d postgres redis
```

What you should see:

- Docker starts containers named similar to `free-minecraft-hosts-postgres-1` and `free-minecraft-hosts-redis-1`.
- `docker compose ps` should show PostgreSQL running and port `5432` mapped.

If this fails, make sure Docker Desktop is running.

## 2. Run the backend locally

Open a terminal in `backend/`:

```bash
cd backend
cp .env.example .env
npm install
npm run prisma:generate
npm run prisma:migrate
npm run prisma:seed
npm run dev
```

What you should see:

- `npm install` downloads dependencies.
- Prisma applies the database migration.
- The seed creates the default OWNER only if no users exist.
- The API logs a startup message with the API port, database status, WebSocket status, and environment mode.
- The backend URL is `http://localhost:3000`.

Check it worked:

```bash
curl http://localhost:3000/health
```

Expected response includes:

```json
{"ok":true,"name":"EMP Control API","websocket":"enabled","database":"connected"}
```

Default login from `.env.example`:

- Username: `xk7`
- Email: `owner@example.com`
- Password: `change_this_password`

Change this password before using anything beyond local testing.

## 3. Build the EMPControlAgent Paper plugin JAR

Open a terminal in `plugin/`:

```bash
cd plugin
gradle build
```

What you should see:

- Gradle downloads Paper API, Gson, Java-WebSocket, and the Shadow plugin.
- Gradle creates the shaded plugin JAR.

Output paths:

- Normal Gradle output: `plugin/build/libs/EMPControlAgent-0.1.0.jar`
- Beginner-friendly copy: `dist/EMPControlAgent.jar`

## 4. Run a local Minecraft Paper test server

Create a separate folder anywhere on your PC, for example `paper-test-server/`.

Download a Paper server JAR from PaperMC and place it in that folder as `paper.jar`, then run:

```bash
java -Xms1G -Xmx2G -jar paper.jar --nogui
```

First run creates `eula.txt`. Open it and change:

```text
eula=false
```

to:

```text
eula=true
```

Then start again:

```bash
java -Xms1G -Xmx2G -jar paper.jar --nogui
```

What you should see:

- The Paper server console starts.
- A `plugins/` folder appears.

## 5. Install and link the plugin locally

Copy the plugin JAR:

```bash
cp /path/to/Free-Minecraft-Hosts/dist/EMPControlAgent.jar /path/to/paper-test-server/plugins/EMPControlAgent.jar
```

Restart the Paper server. In the server console, you should see `EMP Control Agent enabled`.

Create a server record and pairing token from the backend API. Replace `ACCESS_TOKEN` with the token returned by login:

```bash
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"usernameOrEmail":"xk7","password":"change_this_password"}'
```

Create the server:

```bash
curl -X POST http://localhost:3000/servers \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"displayName":"Local Paper","type":"PAPER","address":"localhost:25565"}'
```

Generate a pairing token:

```bash
curl -X POST http://localhost:3000/servers/SERVER_ID/pairing-token \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

In the Paper server console, link the agent:

```text
empcontrol link PAIRING_TOKEN http://localhost:3000
```

How to know it worked:

- The Minecraft console says the server was linked.
- The backend logs `Agent paired` and `Agent websocket connected`.
- `GET /servers` shows the server as `ONLINE` after heartbeats arrive.

Plugin commands:

- `/empcontrol status`
- `/empcontrol link <token> [apiBase]`
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

The login screen displays the API URL baked into the app so you can verify it.

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

```bash
./mobile/scripts/build_release_apk.sh http://192.168.1.25:3000
```

APK output paths:

- Flutter default: `mobile/build/app/outputs/flutter-apk/app-release.apk`
- Download/install copy: `dist/EMP-Control.apk`

## 8. Install the APK on Android

Option A: USB install with Android Platform Tools:

```bash
adb install -r dist/EMP-Control.apk
```

Option B: copy `dist/EMP-Control.apk` to your phone and open it. Android may ask you to allow installing unknown apps for your file manager/browser.

## 9. Optional: use a tunnel for your phone

If your phone cannot reach your PC LAN IP, use Cloudflare Tunnel or ngrok.

Cloudflare Tunnel example:

```bash
cloudflared tunnel --url http://localhost:3000
```

Then build the APK with the shown HTTPS URL:

```bash
./mobile/scripts/build_release_apk.sh https://xxxx.trycloudflare.com
```

ngrok example:

```bash
ngrok http 3000
./mobile/scripts/build_release_apk.sh https://xxxx.ngrok-free.app
```

## 10. GitHub Actions APK download

A workflow is included at `.github/workflows/android-apk.yml`.

To download the APK from GitHub:

1. Open the GitHub repository.
2. Go to **Actions**.
3. Run or open **Build EMP Control Android APK**.
4. Open the latest successful workflow run.
5. Download the artifact named **EMP-Control.apk**.

The workflow builds `mobile/build/app/outputs/flutter-apk/app-release.apk`, copies it to `dist/EMP-Control.apk`, and uploads that file as an artifact.

## 11. iOS status

iOS is not the focus of this MVP stabilization pass. Building iOS later requires:

- A Mac
- Xcode
- An Apple Developer Account
- TestFlight or App Store distribution setup

## Troubleshooting

### `localhost` confusion

- `localhost` inside the backend terminal means your PC.
- `localhost` inside an Android emulator means the emulator itself, not your PC.
- Use `http://10.0.2.2:3000` for Android emulator to reach your PC backend.
- Use `http://YOUR_PC_LAN_IP:3000` for a real Android phone.

### Find your PC LAN IP

Windows PowerShell:

```powershell
ipconfig
```

macOS/Linux:

```bash
ip addr
# or
ifconfig
```

Look for an address like `192.168.x.x` or `10.x.x.x`.

### Windows firewall

If a physical phone cannot connect:

- Allow Node.js through Windows Defender Firewall.
- Make sure your phone and PC are on the same Wi-Fi.
- Try `curl http://YOUR_PC_LAN_IP:3000/health` from another device.
- If your Wi-Fi blocks device-to-device traffic, use Cloudflare Tunnel/ngrok.

### Backend not reachable

Check:

```bash
curl http://localhost:3000/health
```

If it fails:

- Confirm `npm run dev` is still running in `backend/`.
- Confirm `.env` has `PORT=3000`.
- Confirm Docker PostgreSQL is running.

### Database connection failed

Run from repo root:

```bash
docker compose ps
docker compose up -d postgres
```

Check that `backend/.env` has:

```text
DATABASE_URL="postgresql://emp:emp_dev_password@localhost:5432/emp_control?schema=public"
```

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
- The login screen shows which API URL the APK is using.

## Security notes for this MVP

- There is no public registration. The first OWNER is seeded from environment variables only when no users exist.
- Passwords and refresh tokens are hashed with Argon2id.
- Pairing tokens are one-time and stored hashed in PostgreSQL.
- Agent credentials are stored encrypted in `agent.dat`; no readable YAML secrets are created.
- WebSocket envelopes include `serverId`, `timestamp`, `nonce`, `payload`, and `signature`; stale timestamps and nonce replays are rejected.
- Remote console is OWNER-only, policy-checked, audited, signed by the backend, and dispatched only through Bukkit's console sender.
- No file manager, plugin upload, shell command execution, server-file exposure, arbitrary class loading, or file browsing is implemented.
