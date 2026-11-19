# SKYORA v2.1 — Flutter / Cloudflare Weather App

## Included
- Redesigned dark/light weather UI, dynamic KMA SKY/PTY icons, hourly cards and graph, partial-day summary, details, map, favorites and region search.
- KMA short-term forecast through an existing Cloudflare Worker (`/forecast`); no KMA key in APK.
- App icon assets from the original SKYORA icon #1.
- GitHub Actions workflow for debug APK.

## GitHub deployment
1. Copy the **contents of this ZIP's `skyora-main/` folder** into the root of your existing `skyora` repository, retaining `.github/workflows/main.yml` and `skyora_flutter/` paths.
2. In GitHub Settings > Secrets and variables > Actions > **Variables**, create repository variable `SKYORA_PROXY_URL` with `https://skyora-weather-api.danoh14.workers.dev/forecast`.
3. In Cloudflare Worker Settings > Variables and Secrets, keep `KMA_SERVICE_KEY` as **Secret**, not plain text. Keep the existing Worker deployment.
4. Commit to `main`, open Actions, wait for `SKYORA APK Build`, download `SKYORA-v2.1-APK` artifact, unzip and install `app-debug.apk`.
5. If the build fails, inspect the **first** Dart/Gradle error in the job log.

## Important limitations
- The bundled `assets/data/regions.json` has **7 sample regions**, not all nationwide 읍·면·동. The loader supports a larger JSON dataset with code/province/district/town/lat/lon fields. Import verified administrative coordinates before nationwide launch.
- Date summaries are min/max over **available forecast hours**, NOT official KMA daily TMN/TMX.
- The displayed 'current' number is the **nearest short-term forecast**, NOT observed current temperature.
- Weather radar, wind layers, AQI, GPS, push notifications, real-time observation, and production app signing are **not implemented**.
- This archive has not been built in a local Flutter SDK. GitHub Actions runs analysis, tests and a build to verify compatibility.
- OSM map tiles are third-party; review tile usage policy before public high-volume launch.
- Do not commit KMA keys or secrets to this repository.
