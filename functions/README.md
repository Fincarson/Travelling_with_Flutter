# Firebase Function API Keys

Do not put API keys in Flutter code or committed env files. Flutter apps can be inspected by customers, so secrets must stay on the server.

This project keeps external API keys in a local `functions/.env` file and exposes only callable Firebase Functions to the app:

- `searchPlaces` uses `GEOAPIFY_API_KEY`.
- `chatWithAssistant`, `generateTripPlan`, and `createTripReply` use `OPENAI_API_KEY`.

Set or rotate the function environment keys with:

```sh
../scripts/configure_firebase_ai.ps1
```

For local Flutter debugging without deployed Functions, pass temporary keys at
launch time instead of committing them:

```sh
flutter run --dart-define=OPENAI_API_KEY=your_openai_key --dart-define=GEOAPIFY_API_KEY=your_geoapify_key
```

After a key has been committed, rotate it in the provider dashboard. Deleting the file from the repo does not invalidate a key that was already exposed.
