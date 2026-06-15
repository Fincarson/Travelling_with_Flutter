# Travelling with Flutter

Flutter travel-planning app backed by Firebase Auth, Firestore, Cloud Storage,
Cloud Functions, and Firebase Cloud Messaging.

## Local Setup

1. Install Flutter and Firebase CLI.
2. Run `flutter pub get`.
3. Confirm the Firebase app registrations in `firebase.json` and
   `lib/firebase_options.dart`.
4. Enable the required sign-in providers in Firebase Authentication.
5. Set the Functions secrets:

```sh
firebase functions:secrets:set GEOAPIFY_API_KEY
firebase functions:secrets:set OPENAI_API_KEY
```

Provider keys must never be passed to Flutter with `--dart-define`. The client
calls authenticated Firebase callable Functions instead.

Web push additionally requires the public Firebase Web Push certificate:

```sh
flutter run -d chrome --dart-define=FIREBASE_WEB_VAPID_KEY=your_public_vapid_key
```

The VAPID public key is safe to include in a client build. OpenAI and Geoapify
keys are not.

## Firebase Deploys

Deploy Firestore rules and indexes:

```sh
firebase deploy --only firestore
```

Deploy Storage rules:

```sh
firebase deploy --only storage
```

Deploy Cloud Functions:

```sh
firebase deploy --only functions
```

The current queries use single-field indexes created automatically by
Firestore. Add composite indexes to `firestore.indexes.json` when Firebase
returns a link for a newly introduced compound query.

## Verification

```sh
dart --disable-dart-dev format .
flutter analyze
flutter test
cd functions
npm.cmd run lint
```

## Architecture Notes

- Auth initialization is handled by `AccountGate`, which keeps the existing
  onboarding-first flow and shows a loading state while the remembered Firebase
  session is checked.
- Shared trip data remains under `trips/{tripId}` with per-user membership
  snapshots under `travel_users/{uid}/tripMemberships/{tripId}`.
- Standalone group chat remains independent under `chat_groups/{chatId}`.
- Chat messages and active collaboration use realtime listeners. Visible trip,
  memory, chat, and shared-content lists are bounded to prevent unlimited reads.
- AI and Geoapify requests are server-only. Trip-edit AI Functions verify that
  the authenticated caller is an owner or editor.

## Known TODOs

- The larger AI agent/memory design is intentionally deferred.
- Add cursor pagination UI beyond the first 100 visible trips, memories, and
  chats.
- Add Firebase Emulator Suite tests for Firestore and Storage rules before
  making broader rule changes.
- Review and deploy any future FCM/APNs platform credentials in the Firebase
  console.
- Storage attachment rules and paths are intentionally unchanged in this
  hardening pass.
