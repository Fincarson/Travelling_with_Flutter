<div align="center">

<h1 align="center">Travelling with Flutter</h1>

<img src=".github/social_preview.png" alt="Travelling with Flutter" width="820">

<p align="center"><b>A collaborative travel-planning app: build an itinerary, share it with friends, and keep every trip in sync across devices.</b></p>

![Built with Flutter](https://img.shields.io/badge/built%20with-Flutter-02569B?logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/backend-Firebase-FFCA28?logo=firebase&logoColor=black)
![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-555)

</div>

<br>

## What is Travelling with Flutter?

Travelling with Flutter is a cross-platform app for planning trips, alone or with a group.
You create a trip, fill in the itinerary, and invite friends as owners, editors, or viewers.
Everything lives in Firestore, so changes show up for everyone in real time, on phone,
tablet, desktop, or browser.

A trip can have its own chat, and standalone group chats are available for planning that
isn't tied to a trip yet. AI help and place search run server-side through Cloud Functions,
so no provider keys ever ship inside the client.

<br>

## Features

- **Trips & itineraries** - plan days and activities, with bookings, budget categories, and checklists.
- **Shared planning** - invite members with roles: `owner`, `editor`, or `viewer`.
- **Group chat** - realtime chat with multilingual text, emoji, and right-to-left scripts preserved.
- **Maps & places** - interactive map and location search through Geoapify.
- **AI assistance** - trip-edit AI requests, checked server-side against the caller's role.
- **Interactive globe** - a 3D globe with day and night imagery.
- **Push notifications** - Firebase Cloud Messaging plus local reminders.
- **Sign-in options** - Firebase Authentication, including Google Sign-In.
- **Performance settings** - `High`, `Balanced`, `Battery saver`, or custom controls for animations, image quality, and caching.
- **Responsive UI** - works from small phones to wide browser windows.

<br>

## Team

| Member | GitHub |
| --- | --- |
| Albert Jonathan | [@Cookie-1412](https://github.com/Cookie-1412) |
| Bradley Chandra | [@NicolasBradley](https://github.com/NicolasBradley) |
| Patrick Kosasih | [@patrickkosasih](https://github.com/patrickkosasih) |
| Vincent Jefferson | [@Fincarson](https://github.com/Fincarson) |

<br>

## Tech Stack

**App**

- **[Flutter](https://flutter.dev/)** & Dart - one codebase for Android, iOS, web, and desktop.
- **[go_router](https://pub.dev/packages/go_router)** - navigation.
- **[flutter_map](https://pub.dev/packages/flutter_map)** & **[latlong2](https://pub.dev/packages/latlong2)** - maps.
- **[flutter_earth_globe](https://pub.dev/packages/flutter_earth_globe)** - the interactive globe.
- **[geolocator](https://pub.dev/packages/geolocator)** - device location.
- **[shared_preferences](https://pub.dev/packages/shared_preferences)** - local-only settings such as performance mode.
- **[flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)** - local reminders.
- **[image_picker](https://pub.dev/packages/image_picker)**, **[file_picker](https://pub.dev/packages/file_picker)**, **[video_player](https://pub.dev/packages/video_player)** - media and attachments.

**Backend**

- **[Firebase](https://firebase.google.com/)** - Authentication, Cloud Firestore, Cloud Storage, Cloud Messaging.
- **Cloud Functions** (Node.js 22) - authenticated callable functions for AI and place search.
- **[OpenAI](https://platform.openai.com/)** - AI features, server-side only.
- **[Geoapify](https://www.geoapify.com/)** - geocoding and places, server-side only.

**Dev tools**

- [Flutter SDK](https://docs.flutter.dev/get-started/install) and the [Firebase CLI](https://firebase.google.com/docs/cli).
- Node.js 22 and npm for `functions/`.
- Git & GitHub for collaboration.

<br>

## Project Structure

```text
lib/
  app/        app shell and app-level composition
  core/       theme, performance, localization, config, utilities
  features/   auth, chat, home, itinerary, notifications, profile, search, settings
  shared/     shared widgets and navigation
functions/    Firebase Cloud Functions (Node.js)
firestore.rules, storage.rules, firestore.indexes.json
```

<br>

## Getting Started

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

<br>

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

<br>

## Verification

```sh
dart --disable-dart-dev format .
flutter analyze
flutter test
cd functions
npm.cmd run lint
```

<br>

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

<br>

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
