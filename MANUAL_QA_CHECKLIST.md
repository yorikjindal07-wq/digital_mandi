# Manual QA Checklist

Use this checklist after a backend deploy and before calling the app "ready".

## 1. Backend Prep

- Confirm [render.yaml](D:/digital_mandi/render.yaml) still has secrets set to `sync: false`.
- In Render, verify these env vars are present:
  - `OPENWEATHER_API_KEY`
  - `HUGGING_FACE_API_KEY`
  - `HUGGING_FACE_MODEL`
  - `HUGGING_FACE_API_URL`
  - `JWT_SECRET_KEY`
  - `JWT_REFRESH_SECRET_KEY`
  - `ADMIN_API_TOKEN`
  - `DATABASE_URL`
- Open the deployed backend health URL:
  - `GET /health` should return `200`

## 2. Local Verification

- Rebuild the backend venv with:

```powershell
cd D:\digital_mandi\backend
.\setup_local_backend.ps1 -RecreateVenv
```

- Run Flutter checks:

```powershell
cd D:\digital_mandi\plant_disease_app
flutter analyze
flutter test
```

Expected result:
- backend tests pass
- `flutter analyze` passes
- `flutter test` passes

## 3. Auth Flow

On the phone:

1. Register a brand-new account.
2. Close and reopen the app.
3. Confirm the user stays signed in.
4. Log out.
5. Log back in with the same account.

Expected result:
- registration succeeds
- login succeeds
- session persists across app restart
- logout returns to guest/auth screen

If this fails:
- check Render logs for `/api/v1/auth/register`, `/api/v1/auth/login`, or `/api/v1/auth/refresh`
- verify JWT secrets are set in Render

## 4. Weather Flow

1. Open the weather screen on a stable network.
2. Wait through the first request after the backend wakes up.
3. Reopen the weather screen once more.

Expected result:
- current weather loads
- 3-day forecast loads
- second open is faster because of backend/app caching

If this fails:
- check Render logs for `/api/v1/weather/summary`
- verify `OPENWEATHER_API_KEY`
- if the first open is only slow but later loads succeed, that is likely Render cold start rather than a code failure

## 5. Chat Flow

1. Ask a simple question like "How often should I water tomatoes in heat?"
2. Ask a second follow-up question.

Expected result:
- both requests return replies
- no `502` or empty response

If this fails:
- check Render logs for `/api/v1/chat` or `/api/v1/quick-ask`
- verify Hugging Face env vars and model access

## 6. Disease Detection Flow

1. Open the camera/detect disease flow.
2. Grant camera permission if asked.
3. Capture one plant image or choose one from gallery.
4. Wait for the ML result screen.

Expected result:
- permission prompt appears if needed
- camera or gallery opens
- result screen shows crop/disease/confidence

If this fails:
- confirm camera permission is granted in Android settings
- confirm the bundled ML assets are present in the app build
- test both camera and gallery paths, since they use slightly different device flows

## 7. TTS / Voice Flow

1. Trigger a screen or action that speaks text aloud.
2. If voice input exists in that flow, grant microphone permission and try one short phrase.

Expected result:
- spoken audio is audible
- app does not freeze
- speech input starts and stops cleanly

If this fails:
- confirm device TTS engine is installed and enabled
- confirm microphone permission is granted

## 8. Offline / Sync Flow

1. Sign in.
2. Turn on airplane mode.
3. Create a disease report while offline.
4. Turn network back on.
5. Wait for auto-sync or trigger sync manually.

Expected result:
- report saves locally while offline
- report syncs once connectivity returns
- sync status becomes success or partial success, not permanently stuck

If this fails:
- inspect the local sync UI/status
- check Render logs for `/reports` and `/sync/bulk`
- verify the user session is still valid

## 9. Final Release Gate

Only treat the app as fully cleared when all of these are true:

- local backend tests pass
- `flutter analyze` passes
- `flutter test` passes
- auth flow passes on device
- weather flow passes on device
- chat flow passes on device
- disease detection flow passes on device
- TTS/voice flow passes on device
- offline/save/sync flow passes on device
