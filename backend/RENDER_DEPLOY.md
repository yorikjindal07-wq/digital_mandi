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

### Database

The blueprint now defines a managed Render Postgres database and wires its
connection string into the web service as `DATABASE_URL`.

- Database service name: `digital-mandi-postgres`
- App env var: `DATABASE_URL`
- SQLite should now be treated as local-development fallback only

### Environment variables

- `HUGGING_FACE_API_KEY`
- `HUGGING_FACE_MODEL`
- `HUGGING_FACE_API_URL`
- `OPENWEATHER_API_KEY`
- `CORS_ALLOW_ORIGINS`
- `JWT_SECRET_KEY`
- `JWT_REFRESH_SECRET_KEY`
- `ACCESS_TOKEN_EXPIRE_MINUTES`
- `REFRESH_TOKEN_EXPIRE_DAYS`
- `PASSWORD_MIN_LENGTH`
- `ADMIN_API_TOKEN`
- `RATE_LIMIT_GENERAL_PER_MINUTE`
- `RATE_LIMIT_AUTH_PER_MINUTE`
- `RATE_LIMIT_CHAT_PER_MINUTE`
- `RATE_LIMIT_WRITE_PER_MINUTE`
- `DATABASE_URL` from the managed Render Postgres database
- `SQLITE_PATH` if you use SQLite

### Recommended Render values

- `CORS_ALLOW_ORIGINS`: leave empty for mobile-only usage, or set it to your exact web domain like `https://yourdomain.com`
- `ACCESS_TOKEN_EXPIRE_MINUTES`: `60`
- `REFRESH_TOKEN_EXPIRE_DAYS`: `14`
- `PASSWORD_MIN_LENGTH`: `8`
- `RATE_LIMIT_GENERAL_PER_MINUTE`: `120`
- `RATE_LIMIT_AUTH_PER_MINUTE`: `10`
- `RATE_LIMIT_CHAT_PER_MINUTE`: `20`
- `RATE_LIMIT_WRITE_PER_MINUTE`: `30`

### Before you deploy

1. Rotate any key or token that was pasted into chat, screenshots, or logs.
2. Put the fresh values into the Render dashboard, not only into local `backend/.env`.
3. Restrict `CORS_ALLOW_ORIGINS` if you add any web frontend.
4. Confirm the web service has `DATABASE_URL` linked from `digital-mandi-postgres`.
5. Treat SQLite as local-only fallback, not production storage.

### Important

This project is currently configured for the Render free plan.
Free services can sleep when idle. The blueprint now uses Render Postgres for
production data, which is much safer than keeping production records in local
SQLite storage.

### Flutter app

Run the app with:

```bash
flutter run --dart-define=BACKEND_BASE_URL=https://your-render-service.onrender.com
```

Or add that URL to `secrets.json`.
