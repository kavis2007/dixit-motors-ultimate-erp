# Dixit Motors Management App

Fresh Flutter project for Windows + Android. Offline-first, multi-device cloud sync, vehicle 360, OCR number-plate lookup, job workflow, inventory, billing, payments, reports, audit log and backup/restore.

## Branding
- Owners: Dixit Sharma / Ashok Sharma
- Management App managed by: Kavi Sharma
- Workshop: Near Vardhman Hospital, Thikaria, Banswara, Rajasthan 327001
- Phones: 9549281415 / 9929125644 / 9462101890
- Tagline: DRIVE SAFE, WE CARE

## Build
```powershell
flutter pub get
flutter analyze
flutter build windows --release
flutter build apk --release
```

## Cloud sync
Set the API URL and sync key in Settings > Cloud Sync. Backend is in `backend/` and supports SQLite by default or PostgreSQL via `DIXIT_DATABASE_URL`.

Remote multi-device sync needs a network path. Offline work is local; sync resumes automatically when connectivity is available.

## Cross-network cloud sync
This build supports laptop + Android devices on different Wi-Fi/mobile-data networks. The API must be deployed to a public HTTPS host; a local LAN IP is not sufficient. See `CLOUD_SETUP.md` and `backend/render.yaml`.

## Android APK
On Windows with Flutter configured:
```powershell
.\build_android.ps1
```
The release APK is generated under `build\app\outputs\flutter-apk\`.
