# Dixit Motors Management App — Internet Cloud Sync Setup

The Dixit Motors Management App is offline-first. Every laptop/mobile saves locally first, then synchronizes to the central FastAPI database when internet is available.

## Important
For devices on **different Wi-Fi/mobile networks**, the API must be hosted on a public **HTTPS** address. A laptop `localhost` or `192.168.x.x` address only works on the same LAN.

## Render deployment
1. Create a Render account and connect this project repository.
2. Create a Blueprint from `backend/render.yaml`.
3. Set `DIXIT_SYNC_KEY` to one long private random key. Use the **same key on every device**.
4. Wait for the web service and PostgreSQL database to become healthy.
5. Open the generated HTTPS service URL and confirm `/health` returns `ok: true`.
6. In the Dixit Motors Management App open **Cloud Sync** and enter:
   - API URL: the public HTTPS service URL, without a trailing `/`
   - Sync Key: the same private key
   - Device Name: e.g. `Admin Laptop`, `Mobile 01`, `Mobile 02`
7. Press **Save & Sync** once on every device.

After configuration, the app automatically retries sync every 20 seconds and also syncs after record changes. Devices can use different Wi-Fi networks or mobile data because they all connect to the same public HTTPS API.

## Security
- Keep `DIXIT_SYNC_KEY` private.
- Do not commit the real sync key to Git.
- Use HTTPS only.
- The included PostgreSQL service is the central source of truth for cloud data.
