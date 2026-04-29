## Render deployment

This repo now includes a Render blueprint at the repo root:

```yaml
render.yaml
```

### Service settings

- Type: Web Service
- Root directory: `backend`
- Build command: `pip install -r requirements.txt`
- Start command:

```bash
gunicorn -k uvicorn.workers.UvicornWorker app.main:app --bind 0.0.0.0:$PORT
```

### Environment variables

- `ANTHROPIC_API_KEY`
- `CORS_ALLOW_ORIGINS`
- `DATABASE_URL` if you attach Render Postgres
- `SQLITE_PATH` if you use SQLite

### Important

This project is currently configured for the Render free plan.
Free services can sleep when idle, and SQLite data stored locally is temporary because free services do not support persistent disks.

If you need the backend truly live 24/7 with persistent local storage, switch to a paid Render instance or attach Render Postgres.

### Flutter app

Run the app with:

```bash
flutter run --dart-define=BACKEND_BASE_URL=https://your-render-service.onrender.com
```

Or add that URL to `secrets.json`.
