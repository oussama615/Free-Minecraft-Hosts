The app displays the API URL baked into the app so you can verify it.

### Local Demo Mode

The APK can open even when the backend is not running. On startup, the app checks `API_BASE_URL`; if the API is unreachable, it enters **Local Demo Mode** instead of crashing or blocking on login.

In Local Demo Mode:

- The premium login screen still opens when the backend is offline.
- During the MVP, any non-empty username/email and any non-empty password can enter Demo Mode, or you can tap **Continue in Demo Mode**.
- Demo login creates an in-memory Demo Owner session only; it does not create backend tokens and must never be treated as production security.
- The dashboard shows mock server chips for Lobby, Survival, BoxPvP, Lifesteal, and SkyBlock.
- Server chips are mock until plugin-linked servers exist in the backend.
- Tapping a server chip updates the selected server dashboard card and stats.
- Start, Stop, and Restart buttons are preview-only and do not control a real server.
- The Restart button is demo-only until the backend and EMPControlAgent plugin are connected; real restart/remote console actions are OWNER-only once auth is active.
- Activity and Security screens show mock logs/events.
- Real monitoring and control require the backend plus the Paper plugin agent to be running and linked with a real OWNER login.