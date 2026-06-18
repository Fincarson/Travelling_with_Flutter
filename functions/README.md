# Firebase Function Secrets

Provider credentials must stay in Firebase Secret Manager. The Flutter app only
calls authenticated callable Functions and contains no OpenAI or Geoapify
credential fallback.

- `GEOAPIFY_API_KEY` is bound to the place-search Functions.
- `OPENAI_API_KEY` is bound to the itinerary and assistant Functions.

Set or rotate both secrets and deploy:

```powershell
..\scripts\configure_firebase_ai.ps1
```

Or run the commands separately:

```sh
firebase functions:secrets:set GEOAPIFY_API_KEY
firebase functions:secrets:set OPENAI_API_KEY
firebase deploy --only functions
```

Never pass these provider keys with Flutter `--dart-define` values. Firebase web
configuration values in `firebase_options.dart` identify the Firebase app and
are not provider secrets; Firebase Rules and Auth protect backend data.
