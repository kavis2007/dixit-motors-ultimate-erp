# Dixit Motors Management App — Final Setup

## Included
- Windows + Android Flutter app
- Offline-first local JSON store
- FastAPI sync API with PostgreSQL/SQLite support
- Automatic periodic sync when configured
- Device heartbeat/status API
- Android number-plate OCR using camera/gallery + ML Kit
- Windows manual plate fallback
- Global search
- Staff attendance
- Job → customer → vehicle → invoice auto-fill
- Invoice item quick-search and automatic amount/total calculation
- A4 invoice PDF/print/share with Dixit Motors branding and authorized signature
- Backup/restore

## Cloud sync
The app intentionally does **not** contain a hard-coded secret or somebody else's cloud account. To activate multi-device cloud sync, deploy `backend/` to your server/Render/VPS and set:

- `DIXIT_DATABASE_URL` = your PostgreSQL connection string
- `DIXIT_SYNC_KEY` = a long private random key

Then enter the server URL and the same sync key in **Cloud Sync** on the laptop and each Android phone. Automatic sync runs every 20 seconds when configured and online.

## Plate reader
On Android, use **Plate Scanner → SCAN PLATE**. The app sends the captured image to on-device ML Kit OCR and searches the normalized plate against stored vehicle/job/invoice records. Windows provides photo/manual fallback because camera/OCR support differs by desktop plugin platform.

## Build
Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup_platforms.ps1
flutter build apk --release
flutter build windows --release
```

## Important
A real public cloud endpoint cannot be created from this package without access to the workshop's chosen cloud account. The backend is deployment-ready; the actual URL/key are intentionally left for the owner to configure.
