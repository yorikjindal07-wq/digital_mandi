## Local secret setup

Do not commit API keys to this repository. Pass them at build time instead.
For production, keep third-party secrets on the backend and give the app only the backend URL.

Example with inline values:

```bash
flutter run \
  --dart-define=BACKEND_BASE_URL=https://your-backend.example.com
```

Optional debug-only example with a local file that stays out of Git:

```json
{
  "BACKEND_BASE_URL": "https://your-backend.example.com"
}
```

Save that as `secrets.json`, then run:

```bash
flutter run --dart-define-from-file=secrets.json
```

Notes:

- In release builds, direct client-side provider access should stay disabled.
- The app now signs in with backend-issued JWT tokens and stores them in secure storage.
- `BACKEND_API_TOKEN` is now only a legacy fallback. Prefer user sign-in instead of sharing one mobile token across all installs.
- Rotate any key that was ever committed, shared publicly, or pasted into logs/screenshots.
