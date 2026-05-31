# Agent Instructions

These instructions are for AI coding agents working on this Flutter project. Read this file before planning or changing code.

## Clarify First

Before making broad changes, ask the user short, concrete questions. Do this especially when the request involves:

- Moving files, deleting folders, replacing architecture, or reorganizing features.
- Adding animations, heavy visuals, live effects, image-heavy UI, or custom transitions.
- Changing navigation, app state, data storage, Firebase behavior, authentication, settings, or performance behavior.
- Adding pages/widgets that must work across phone, tablet, desktop, and browser window resizing.

Do not assume intent when a change could affect project structure, responsiveness, performance, persistence, or user data.

## Project Organization

Use the existing project structure first:

- App shell and app-level composition: `lib/app/`
- Shared widgets/navigation/utilities: `lib/shared/`
- Cross-cutting systems: `lib/core/`
- Feature-specific UI/data/domain code: `lib/features/<feature>/`

Do not create clone/demo folders for integrated app code. Do not dump unrelated code into one large file. Create a new file only when no existing prepared file or folder fits.

## Responsive UI Rule

Every new UI must handle resizing. The app must work on phone, tablet, desktop, and web window sizes.

When adding or changing UI:

- Avoid fixed phone-width shells unless the user explicitly asks for one.
- Prefer `LayoutBuilder`, `MediaQuery`, `Wrap`, `Expanded`, `Flexible`, scroll views, and responsive padding.
- Text inside cards, buttons, tiles, and nav items must wrap or ellipsize safely.
- Horizontal rows must stack, wrap, scroll, or otherwise avoid overflow on narrow screens.
- Test mentally and, when possible, visually at small phone width, tablet width, and full desktop/browser width.

## Performance Settings Rule

This app has a local performance settings system. Before adding animation, expensive repainting, heavy images, visual effects, page transitions, auto-refreshing widgets, or state-heavy UI, tell the user that the app has Performance settings and ask how the new feature should behave under:

- `High`
- `Balanced`
- `Battery saver`
- Custom advanced controls

Use the existing performance system instead of inventing another one:

- Settings model/controller: `lib/core/performance/app_performance.dart`
- Access current settings with `PerformanceScope.settingsOf(context)` or `PerformanceScope.maybeSettingsOf(context)`.
- Performance page: `lib/features/settings/presentation/pages/performance_settings_page.dart`
- Existing controls include animations, frame pacing, image quality, page caching, repaint isolation, and heavy visual effects.

New animation/effects should respect:

- `settings.animationsEnabled`
- `settings.transitionDuration`
- `settings.heavyVisualEffects`
- `settings.globeAnimationDuration` or an equivalent setting-aware duration
- `settings.filterQuality` for images
- `settings.cachePages` when caching page/tab state is relevant
- `settings.isolateRepaints` for major repaint-heavy areas

If Battery saver is selected, prefer static UI, no decorative animation, lower image filter quality, and minimal unnecessary rebuild/repaint work.

## Page Caching And State

The app already uses caching ideas for performance:

- Main tab caching in `lib/app/travel_agent_shell.dart`
- `IndexedStack` for cached tab pages
- `KeepAlivePage` in `lib/shared/widgets/travel_common_widgets.dart`
- Itinerary tab keep-alive behavior
- `RepaintBoundary` where performance settings request repaint isolation

When adding deeper pages or tabbed sections, consider whether caching helps. If caching can make stale data or stale UI likely, ask the user before enabling it.

## Terminal Debugging Rule

Terminal debugging is disabled by default because noisy rebuild logs and frame diagnostics can make the Flutter app feel slow, especially on web/debug builds.

Do not add always-on `print`, `debugPrint`, rebuild diagnostics, frame timing callbacks, or state-change logs without asking the user first. If temporary debugging is needed, make it clearly removable or gated behind an explicit local flag.

## Data Persistence

Ask before choosing where new settings or user data are stored.

Current guidance:

- Performance settings are local only through `shared_preferences`.
- User/trip data is Firebase-backed and must stay in sync with the shared trip schema below.
- Do not sync new local-only settings to Firebase unless the user explicitly approves it.

## Firebase Data Organization

Firestore is the source of truth for account, trip, collaboration, and chat-ready data. Do not add new trip features that only mutate local app state. Whenever trips, plans, itinerary items, bookings, budgets, checklist data, members, invites, chat, or AI results change, update the backend repository/rules so Firestore remains authoritative.

Use this shared trip structure unless the user explicitly approves a schema change:

- User profile: `travel_users/{userId}`
- User trip index: `travel_users/{userId}/tripMemberships/{tripId}`
- Shared trip document: `trips/{tripId}`
- Trip members: `trips/{tripId}/members/{userId}`
- Itinerary items: `trips/{tripId}/itineraryItems/{itemId}`
- Bookings: `trips/{tripId}/bookings/{bookingId}`
- Budget categories: `trips/{tripId}/budgetCategories/{categoryId}`
- Chat channels: `trips/{tripId}/channels/{channelId}`
- Chat messages: `trips/{tripId}/channels/{channelId}/messages/{messageId}`
- AI runs: `trips/{tripId}/aiRuns/{runId}`
- Invites: `trips/{tripId}/invites/{inviteId}`

Keep denormalized data in sync:

- `trips/{tripId}.memberIds` and `trips/{tripId}.roles`
- `trips/{tripId}/members/{userId}`
- `travel_users/{userId}/tripMemberships/{tripId}` snapshots such as title, destination, cover image, role, status, last message time, and unread count.

Role expectations:

- `owner`: can edit the trip, invite/remove users, delete the trip, and manage roles.
- `editor`: can edit itinerary, budget, bookings, checklist, chat, and request AI updates.
- `viewer`: can read the trip and chat when allowed, but cannot edit trip data.

If legacy data under `travel_users/{userId}/trips/{tripId}` appears, migrate it into the shared `trips/{tripId}` structure and delete the old document only after the transfer succeeds.

## Platform Compatibility

Changes must remain compatible with Android, iOS, web, and the supported desktop targets unless the user narrows the platform scope.

When changing Firebase, authentication, routing, plugins, generated options, platform config, or UI behavior:

- Check that the change works with FlutterFire-supported Android, iOS, and web flows.
- Avoid platform-only APIs unless guarded by platform checks and a fallback.
- Keep web behavior in mind for browser resizing, Firebase Auth, callable Functions, and Firestore listeners.
- Run available checks for the affected platforms when feasible, and clearly report anything skipped.

## Theme And Design

Use existing theme, colors, and shared widgets first:

- Theme: `lib/core/theme/app_theme.dart`
- Shared travel widgets: `lib/shared/widgets/travel_common_widgets.dart`
- Shared scaffold/navigation widgets: `lib/shared/widgets/` and `lib/shared/navigation/`

Do not create a separate design system unless the user asks.

## Verification

After code changes:

- Run `dart --disable-dart-dev format` on changed Dart files.
- Run available static checks/tests/builds when feasible.
- If `flutter analyze`, `flutter test`, or build commands time out because Flutter tooling is already running, report that clearly.
- Do not hide failed or skipped verification.

## Safety

- Never delete or revert user changes unless the user explicitly asks.
- Keep changes scoped to the request.
- If the task affects architecture, performance, responsiveness, storage, or navigation, clarify before coding.
