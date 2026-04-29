## Local secret setup

Do not commit API keys to this repository. Pass them at build time instead.

Example with inline values:

```bash
flutter run \
  --dart-define=HUGGING_FACE_API_KEY=your_hugging_face_key \
  --dart-define=OPENWEATHER_API_KEY=your_openweather_key \
  --dart-define=BACKEND_BASE_URL=https://your-backend.example.com
```

Example with a local file that stays out of Git:

```json
{
  "HUGGING_FACE_API_KEY": "your_hugging_face_key",
  "OPENWEATHER_API_KEY": "your_openweather_key",
  "BACKEND_BASE_URL": "https://your-backend.example.com"
}
```

Save that as `secrets.json`, then run:

```bash
flutter run --dart-define-from-file=secrets.json
```
