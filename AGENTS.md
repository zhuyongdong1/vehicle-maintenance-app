# AGENTS.md

## Project

Vehicle maintenance management app for `ulbooks.cn`.

- Backend: Dart Shelf API in `backend/`.
- Frontend: Flutter app in `frontend/`, built for Web and Android APK.
- Production server path: `/var/www/vehicle-maintenance`.
- Public Web app: `https://ulbooks.cn/`.
- API base: `https://ulbooks.cn/api`.
- Remote APK update manifest: `https://ulbooks.cn/downloads/app-version.json`.
- Latest APK URL: `https://ulbooks.cn/downloads/vehicle-maintenance-latest.apk`.

## Data Safety Rules

The app is used by real customers. Treat production data as critical.

- Never run destructive database commands without a fresh backup.
- Before any production database restore, migration, or manual data repair, create a timestamped backup under `/var/www/vehicle-maintenance/backups/`.
- Prefer additive changes over destructive schema changes.
- Do not delete customer, vehicle, record, ledger, inventory, or reminder data as part of cleanup.
- If testing production flows, avoid creating fake customer data unless explicitly requested.
- If an API issue makes data appear missing, first check API errors, table counts, joins, and backups before assuming data is gone.

## Build And Verify

Run from the repository root unless noted.

Backend:

```bash
cd backend
dart pub get
dart analyze
dart test
```

Frontend:

```bash
cd frontend
flutter pub get
flutter analyze
flutter test
```

Production builds must include the real API key from the running backend environment. Do not print the key in logs or responses.

```bash
API_KEY=... API_BASE_URL=https://ulbooks.cn/api APP_DOMAIN=ulbooks.cn scripts/build_frontend.sh web
API_KEY=... API_BASE_URL=https://ulbooks.cn/api APP_DOMAIN=ulbooks.cn scripts/build_frontend.sh apk
```

## Deployment Notes

- Production backend runs as PM2 process `vehicle-api`.
- The server is small: 2 CPU cores, 2 GB RAM, 40 GB SSD disk, 3 Mbps bandwidth.
- Keep deployment lightweight. Do not compile many large artifacts on the server if local build is practical.
- Keep only necessary release, backup, and APK artifacts. Large directories to watch:
  - `/var/www/vehicle-maintenance/backups`
  - `/var/www/vehicle-maintenance/releases`
  - `/var/www/vehicle-maintenance/downloads`
  - local `dist/`
- After deploying, verify:
  - `https://ulbooks.cn/`
  - `https://ulbooks.cn/api/health`
  - a protected API route with `X-API-Key`
  - the customer-facing flow affected by the change

## Android Update Channel

For app updates outside an app store:

- Increment `frontend/pubspec.yaml` version code, for example `1.0.2+3`.
- Build the APK with production dart-defines.
- Upload the APK to `/var/www/vehicle-maintenance/downloads/vehicle-maintenance-latest.apk`.
- Update `/var/www/vehicle-maintenance/downloads/app-version.json`.
- Android will still require the customer to confirm installation. First-time installs may require allowing unknown-source installs.

## Git Hygiene

- Do not commit generated APKs from `dist/`.
- Do not commit secrets, server passwords, API keys, or local environment files.
- Keep changes scoped to the user request.
- Avoid changing lockfiles only because of a mirror URL rewrite.

