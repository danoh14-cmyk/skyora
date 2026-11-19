# SKYORA — Flutter source starter

This is a **working-source prototype**, NOT a tested production APK. Flutter SDK was not available in the authoring environment, so compilation and device tests have **not** been performed. Nationwide DB is **not** bundled: 7 illustrative locations only. The example codes/coordinates must be validated against official data before publication.

## Setup

1. Install Flutter SDK (compatible with Dart >=3.3), Android SDK and emulator.
2. In this directory run `flutter create . --platforms=android` to generate platform files, then `flutter pub get`.
3. Run `flutter run` for UI-only mode. It clearly reports a missing weather API connection.
4. For **development only**, run `flutter run --dart-define=KMA_SERVICE_KEY=YOUR_ISSUED_KEY`. The KMA public API's short-term forecast endpoint is `getVilageFcst` and uses DFS `nx`, `ny` grid coordinates.
5. For **production**, deploy your own HTTPS proxy, configure `--dart-define=SKYORA_PROXY_URL=https://your-backend.example/api/forecast`, and keep KMA keys on the server. **dart-define is not secret storage**: compiled APKs can reveal client-side keys. Rate-limit, cache, authenticate and monitor the proxy. Ensure your proxy forwards the KMA `response` JSON schema expected by `KmaService`.
6. Generate launcher icons with `dart run flutter_launcher_icons` and release with `flutter build appbundle --release --dart-define=SKYORA_PROXY_URL=https://...` after signing configuration and testing.

## Nationwide location database

The bundled `assets/data/regions.json` has **7 illustrative records**, not all Korea. Obtain current official legal/administrative area codes from government sources and **licensed, verified WGS84 coordinates** for the same code system. Prepare two UTF-8 CSVs:

`official.csv`: `code,province,district,town`

`coordinates.csv`: `code,lat,lon`

Then:

`python tools/import_regions.py --codes official.csv --coords coordinates.csv`

The importer outputs `assets/data/regions.json`, skips unlocated entries and prints missing-code counts. Validate province renames, retired codes, same-name villages, and administrative-vs-legal dong discrepancies. Use official coordinates for the desired forecast representative point (not arbitrary geocodes). `lib/region.dart` converts WGS84 to KMA DFS Lambert 5-km grid.

## Included

- Aurora-night premium theme, light/dark switch, 4-tab navigation
- Region search (local bundled DB), saved favorites and last region
- KMA short-term forecast parsing and hourly chart, loading/error/retry
- OpenStreetMap background and selected-place marker (**not a weather radar**)
- Selected **design #1 Aurora Cloud** launcher icon (1024px), Google Play 512px icon, adaptive foreground, and generation config

## Important gaps before release

- Import and audit the **complete** official nationwide administrative DB and matching coordinates; refresh periodically.
- Verify KMA issuance times/timezones, retries and fallback base times, cached stale data and forecast category semantics (e.g., PCP can be textual), service availability and attribution.
- Production backend proxy, abuse controls, telemetry, caching, HTTPS and privacy policy.
- Air Korea data, real licensed weather radar/wind tiles, official alerts, push notifications and widgets are **not implemented**.
- Unit/widget/integration tests, accessibility, Play signing, licensing and privacy disclosures.

Source uses OpenStreetMap standard tiles for development. Follow OSM tile usage policy; production high-volume use requires a suitable tile provider.

## Selected app icon — design #1 (Aurora Cloud)

- `assets/icon/app_icon.png`: selected #1 concept, 1024 × 1024, including SKYORA wordmark.
- `assets/icon/play_store_512.png`: 512 × 512 store artwork candidate. Review Google Play current artwork requirements before uploading.
- `assets/icon/adaptive_foreground.png`: 1024 × 1024 transparent foreground, artwork inset to protect adaptive icon cropping.
- `pubspec.yaml`: configured `flutter_launcher_icons` to generate Android launcher assets from these files.

After generating the Android scaffold with `flutter create . --platforms=android`, run:

```bash
flutter pub get
dart run flutter_launcher_icons
flutter run
```

The generated Android `mipmap-*` files are **not** included because Flutter/Android build tools are unavailable in this environment. The launcher generation step above is required.

The chosen concept was extracted from the user's 10-concept design board. It contains lettering, which may appear small on device launchers; consider a text-free adaptive symbol in a future refinement.
