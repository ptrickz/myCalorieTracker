// Compile-time override: flutter run/build --dart-define=API_BASE_URL=https://...
// Falls back to the Android emulator's host alias for local dev when not set.
// - Android emulator: http://10.0.2.2:3000
// - Windows desktop / Chrome / Edge on the same machine as the backend: http://localhost:3000
// - Physical device on same Wi-Fi: http://<your-machine-LAN-IP>:3000
// - Production (Vercel build): https://mct.up.railway.app
const String apiBaseUrl = String.fromEnvironment(
  "API_BASE_URL",
  defaultValue: "http://10.0.2.2:3000",
);
