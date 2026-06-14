# Firebase Function API Keys

Do not put API keys in Flutter code or committed env files. Flutter apps can be inspected by customers, so secrets must stay on the server.

This project keeps external API keys in a local `functions/.env` file and exposes only callable Firebase Functions to the app:

- `searchPlaces` uses `GEOAPIFY_API_KEY`.
- `chatWithAssistant`, `generateTripPlan`, and `createTripReply` use `OPENAI_API_KEY`.
- Itinerary place resolution and Routes use
  `GOOGLE_MAPS_PLATFORM_API_KEY`.

Set or rotate the function environment keys with:

```sh
../scripts/configure_firebase_ai.ps1
```

For local Flutter debugging without deployed Functions, pass temporary keys at
launch time instead of committing them:

```sh
flutter run --dart-define=OPENAI_API_KEY=your_openai_key --dart-define=GEOAPIFY_API_KEY=your_geoapify_key
```

## Google Maps client keys

Use restricted client keys for the map renderer:

- Android: set `MAPS_API_KEY` in `android/local.properties`.
- iOS: copy `ios/Flutter/GoogleMaps.xcconfig.example` to
  `ios/Flutter/GoogleMaps.xcconfig`.
- Web: copy `web/maps_config.js.example` to `web/maps_config.js`, then run
  with `--dart-define=GOOGLE_MAPS_WEB_ENABLED=true`. Without that define, web
  safely uses the OpenStreetMap desktop fallback.

The server key belongs only in `functions/.env` as
`GOOGLE_MAPS_PLATFORM_API_KEY`. Enable Maps SDK for Android/iOS, Maps
JavaScript API, Routes API, and Places API (New) in the Google Cloud project.

After a key has been committed, rotate it in the provider dashboard. Deleting the file from the repo does not invalidate a key that was already exposed.
