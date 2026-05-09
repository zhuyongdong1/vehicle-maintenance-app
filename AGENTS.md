# AGENTS.md

## Project

Vehicle maintenance management app for `ulbooks.cn`.

- Backend: Dart Shelf API in `backend/`.
- Frontend: Flutter app in `frontend/`, built for Web and Android APK.
- Main business flow: customer/vehicle archive, maintenance order, fee items, ledger, reminders, inventory, and statistics.
- Production server path: `/var/www/vehicle-maintenance`.
- Public Web app: `https://ulbooks.cn/`.
- API base: `https://ulbooks.cn/api`.
- Remote APK update manifest: `https://ulbooks.cn/downloads/app-version.json`.
- Latest APK URL: `https://ulbooks.cn/downloads/vehicle-maintenance-latest.apk`.

## First Steps For Any Agent

Always start with orientation before editing:

```bash
git status -sb
rg --files -g 'AGENTS.md'
rg -n "TODO|待接入|未接入|FIXME" backend frontend scripts
```

Rules:

- Read this file before making repo changes.
- Treat uncommitted changes as user-owned unless you made them in the current turn.
- Do not stage or commit unrelated modified files.
- Do not include APKs, build outputs, screenshots, or temporary browser artifacts in commits.
- If the user reports missing data, stop feature work and investigate production state first.

## Data Safety Rules

The app is used by real customers. Treat production data as critical.

- Never run destructive database commands without a fresh backup.
- Before any production database restore, migration, or manual data repair, create a timestamped backup under `/var/www/vehicle-maintenance/backups/`.
- Prefer additive changes over destructive schema changes.
- Do not delete customer, vehicle, record, ledger, inventory, or reminder data as part of cleanup.
- If testing production flows, avoid creating fake customer data unless explicitly requested.
- If an API issue makes data appear missing, first check API errors, table counts, joins, and backups before assuming data is gone.
- For vehicle deletion, remember that vehicles with records must be protected. Do not reintroduce a delete path that can orphan records.

Minimum production data check:

```bash
pm2 list
df -h /
free -h
du -sh /var/www/vehicle-maintenance/backups /var/www/vehicle-maintenance/releases /var/www/vehicle-maintenance/downloads
```

Database checks should include table counts and orphan joins before any restore:

```sql
SELECT COUNT(*) FROM vehicles;
SELECT COUNT(*) FROM records;
SELECT COUNT(*) FROM ledger;
SELECT COUNT(*) AS orphan_count
FROM records r
LEFT JOIN vehicles v ON v.id = r.vehicle_id
WHERE v.id IS NULL;
```

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

Do not expose the production API key. Read it from the running PM2 process when needed, use it only in local environment variables, and do not paste it into final responses.

Use browser-level checks for user-visible Flutter Web changes. At minimum verify mobile width for changed screens and check that bottom navigation is still present where expected.

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

### Server Capacity Guidance

Current server class is enough for this app if kept tidy.

- API, Nginx, and MySQL are lightweight for the current customer load.
- 3 Mbps bandwidth is acceptable for normal app usage. APK downloads are slow but safe; a 55 MB APK may take a few minutes.
- Do not run repeated Flutter Android builds on the server. Build locally, then upload artifacts.
- Add swap before heavy server-side builds or large migrations if they become unavoidable.
- Watch disk growth. A practical retention target:
  - DB backups: keep recent daily backups and important pre-migration backups.
  - Web releases: keep the latest 5 to 10.
  - APK files: keep the latest 3 to 5 plus the `latest` APK.

Suggested read-only capacity check:

```bash
df -h /
free -h
uptime
du -sh /var/www/vehicle-maintenance
du -sh /var/www/vehicle-maintenance/backups /var/www/vehicle-maintenance/releases /var/www/vehicle-maintenance/downloads
pm2 list
```

Do not delete backups automatically unless the user explicitly asks for cleanup.

### Backend Deploy Checklist

1. Run backend tests locally.
2. Back up the current server binary and API source.
3. Upload source or compiled binary.
4. Restart `vehicle-api` with PM2.
5. Verify `/api/health`, protected routes, and PM2 logs.

### Web Deploy Checklist

1. Build Web locally with production dart-defines.
2. Upload `frontend/build/web` tarball.
3. Back up `/var/www/vehicle-maintenance/current`.
4. Replace current Web files.
5. Verify `https://ulbooks.cn/` and changed screens in a browser.

## Android Update Channel

For app updates outside an app store:

- Increment `frontend/pubspec.yaml` version code, for example `1.0.2+3`.
- Build the APK with production dart-defines.
- Upload the APK to `/var/www/vehicle-maintenance/downloads/vehicle-maintenance-latest.apk`.
- Update `/var/www/vehicle-maintenance/downloads/app-version.json`.
- Android will still require the customer to confirm installation. First-time installs may require allowing unknown-source installs.

Required manifest shape:

```json
{
  "version_name": "1.0.2",
  "version_code": 3,
  "apk_url": "https://ulbooks.cn/downloads/vehicle-maintenance-latest.apk",
  "release_notes": ["Short customer-facing note"],
  "required": false,
  "published_at": "2026-05-09T21:00:00+0800",
  "sha256": "..."
}
```

After publishing an APK, verify:

```bash
curl -s https://ulbooks.cn/downloads/app-version.json
curl -I https://ulbooks.cn/downloads/vehicle-maintenance-latest.apk
```

Customers with versions before the in-app update feature still need one manual APK install. After that, they can use Settings -> Check Update.

## Production Incident Runbook

If a customer says data is missing:

1. Do not deploy feature changes.
2. Check API health and recent PM2 logs.
3. Check table counts and orphan joins.
4. Check Nginx access logs for destructive calls such as `DELETE`.
5. Inspect the newest safe backup before any restore.
6. Create a fresh backup before any repair.
7. Prefer targeted restore or insert repair over full database restore.
8. Re-verify API output and the customer-facing screen.

Useful log locations:

- PM2 logs: `/home/ubuntu/.pm2/logs/vehicle-api-out.log` and `vehicle-api-error.log`.
- Nginx logs: `/var/log/nginx/access.log` and rotated logs.
- Production DB backups: `/var/www/vehicle-maintenance/backups`.
- Older app backups may exist under `/home/ubuntu/apps/backups`.

Known previous incident pattern:

- MySQL socket can close after idle time. Backend should reconnect automatically.
- Deleted vehicles can make records appear missing if vehicle joins fail or records become orphaned.
- Do not allow deleting vehicles that already have records.

## Git Hygiene

- Do not commit generated APKs from `dist/`.
- Do not commit secrets, server passwords, API keys, or local environment files.
- Keep changes scoped to the user request.
- Avoid changing lockfiles only because of a mirror URL rewrite.
- Check `git status -sb` before and after commits.
- If local user edits are present, mention them and leave them untouched unless the user explicitly asks to include them.

## Common Commands

Read-only production snapshot:

```bash
pm2 list
curl -s https://ulbooks.cn/api/health
df -h /
free -h
```

Local source-only commit pattern:

```bash
git status -sb
git diff --check
git add <specific-files>
git commit -m "<type>: <summary>"
git status -sb
```

Local cleanup candidates, only after user approval:

```bash
ls -lh dist/
du -sh /var/www/vehicle-maintenance/backups /var/www/vehicle-maintenance/releases /var/www/vehicle-maintenance/downloads
```
