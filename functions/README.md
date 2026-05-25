# Firebase Function Secrets

Do not put API keys in Flutter code or committed env files. Flutter apps can be inspected by customers, so secrets must stay on the server.

This project keeps external API keys in Firebase Secret Manager and exposes only callable Firebase Functions to the app:

- `searchPlaces` uses `GEOAPIFY_API_KEY`.
- `chatWithAssistant` uses `OPENAI_API_KEY`.

Set or rotate the secrets with:

```sh
firebase functions:secrets:set GEOAPIFY_API_KEY
firebase functions:secrets:set OPENAI_API_KEY
firebase deploy --only functions
```

After a key has been committed, rotate it in the provider dashboard. Deleting the file from the repo does not invalidate a key that was already exposed.
