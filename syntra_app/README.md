# syntra_app

Flutter intake studio for SYNTRA. Brief a lesson, stream it to the orchestrator, and reopen past lessons on this device.

Guest mode works with no Firebase setup. Sign-in is optional and skippable. The landing header always shows **Sign in** (top right, next to Past lessons), even when Firebase is unconfigured.

Auth is **not** on the research path. The pipeline (RAG_ONLY skip-web, Fact Checker off by default) does not wait on Firebase. This app does **not** include `cloud_firestore`. Flutter never reads or writes `syntra/**/research_cache` — that collection stays Admin SDK only (deny-all for clients).

## Run

From the repo root (starts local ADK and Chrome, and loads Auth defines when present):

```bash
./scripts/dev.sh
```

Or from this directory, with Firebase Auth:

```bash
flutter run -d chrome --dart-define-from-file=firebase.defines.json
```

Without the defines file, Sign in still appears. Tapping it opens the Sign in / Sign up page with a short **Add firebase.defines.json** note and the email fields.

## Sign-in (optional)

The landing and intake screens always show a skippable **Sign in** control. The Sign in / Sign up page has email + password, **Sign in**, **Sign up**, optional **Continue with Google**, and **Skip for now**.

Skip keeps the guest history bucket. Email/password uses Firebase `signInWithEmailAndPassword` and `createUserWithEmailAndPassword`. Google on web uses `signInWithPopup` / `GoogleAuthProvider`.

| State | History key | Cross-device |
| --- | --- | --- |
| Guest (signed out, or Auth not configured) | `guest/syntra.lesson_history.v1` | No — this device only |
| Anonymous | `{uid}/syntra.lesson_history.v1` | No — same device until linked |
| Google / email | `{uid}/syntra.lesson_history.v1` | Yes — same uid on another device |

`LessonStore` owns persistence. Auth only prefixes the existing SharedPreferences key via `HistoryKeys`.

## Local Firebase options (gitignored)

`firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`, `firebase.json`, and `.firebaserc` are gitignored. Do not force-add them. Do not commit secrets or service accounts.

### Option A — dart-define (no generated Dart in git)

1. Copy the example file:

```bash
cp firebase.defines.example.json firebase.defines.json
```

2. Fill in the values from the Firebase console (or `flutterfire configure` output). `firebase.defines.json` is gitignored.

3. Run (this is the command that talks to Firebase Auth):

```bash
flutter run -d chrome --dart-define-from-file=firebase.defines.json
```

`./scripts/dev.sh` passes the same `--dart-define-from-file=syntra_app/firebase.defines.json` flag when that file exists.

Required keys: `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`.

### Option B — gitignored `lib/firebase_options.dart`

1. Install the FlutterFire CLI and generate local files (they stay gitignored):

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

2. That writes `lib/firebase_options.dart`. Do not commit it.

3. Wire it locally in `lib/main.dart` (do not commit this hook):

```dart
import 'auth/firebase_config.dart';
import 'firebase_options.dart';

// inside main(), before bootstrapAuth():
FirebaseConfig.localOptions = DefaultFirebaseOptions.currentPlatform;
```

If `lib/firebase_options.dart` is missing after a fresh clone, the committed stub in `lib/auth/firebase_options_stub.dart` keeps the app running as a guest. Copy that stub if you need a placeholder file:

```bash
cp lib/auth/firebase_options_stub.dart lib/firebase_options.dart
```

Then replace it with the FlutterFire output when you are ready.

Enable **Anonymous**, **Google**, and/or **Email/Password** in the Firebase console. Add `localhost` to Authorized domains for Flutter web.

Google Sign-In is OAuth. SYNTRA never collects or stores a Google password. Email/password, if enabled, is `signInWithEmailAndPassword` against Firebase — create the user in the Firebase console or the in-app form. Do not put passwords in dart-defines, comments, or git.

## Admin (email allowlist)

Admin is **not** a password. A signed-in Firebase Auth email that matches `SYNTRA_ADMIN_EMAILS` (case-insensitive) is admin. Default includes `shouryakelkar@gmail.com`. Extra addresses can be added at run time without committing secrets:

```bash
flutter run --dart-define=SYNTRA_ADMIN_EMAILS=shouryakelkar@gmail.com,other@school.test
```

Or set `SYNTRA_ADMIN_EMAILS` in gitignored `firebase.defines.json`. The in-app **Admin** link is hidden unless `isAdmin` is true. It does not query Firestore. Cache hit counts stay on `python scripts/cache_hits.py`.

## Cache stays Admin-only

Do not add `cloud_firestore` to this app. If you edit Firestore rules, keep `syntra/{workspaceId}/research_cache` as deny-all for clients:

```
match /research_cache/{cacheId} {
  allow read, write: if false;
}
```

The Research Agent writes cache via the Admin SDK on Cloud Run.
