DIXIT MOTORS MANAGEMENT APP — LAUNCH BUILD

IMPORTANT CLOUD PRESERVATION
- Existing Render API URL is preserved: https://dixit-motors-erp-api.onrender.com
- Existing DIXIT_SYNC_KEY environment variable is NOT changed or included in this package.
- Existing PostgreSQL sync_records are preserved.
- Existing local Sync Key stored in Windows/Android app preferences is preserved.
- Automatic sync remains every 20 seconds and after record changes.
- Device registration/blocking is added without changing the API URL or Sync Key.
- Existing devices table is safely migrated at backend startup by adding only missing security columns.

ADDED IN THIS BUILD
- Device Management with Active/Blocked status
- Device registration + blocked-device sync denial
- Cloud backup export and restore
- Configurable API URL (existing stored URL wins; default is the existing Render URL only when blank)
- User/device identity fields
- Live Android number plate OCR camera
- Capture photo OCR + gallery fallback
- Windows manual/photo plate fallback
- Date-wise staff attendance: Present, Absent, Half Day, Leave
- Attendance history and monthly percentage
- Corrected quick-action/mobile navigation indexes after Device Management insertion
- Vehicle Next Service KM field
- Invoice job-number auto-fill and item search/table retained
- Invoice PDF/print/share retained
- Global search and existing management modules retained

LAUNCH CHECK
1. Extract/open the project.
2. Run: flutter clean
3. Run: flutter pub get
4. Run: flutter analyze
5. Run Windows: flutter run -d windows
6. Run Android: flutter run -d <android-device>
7. Open Cloud Sync. If URL/key are already stored, do NOT replace them.
8. Test Save & Sync once.
9. Open Device Management and confirm the device appears.
10. Test Live Scan on Android.

NOTE
Live OCR depends on the Android camera/image format supported by the target device. If a particular phone's camera stream does not expose NV21 as expected, use Capture Photo or Gallery as the immediate fallback.
