# Fin Alert (MVP)

Gmail transaction ingestion for **India (Android-first)**: OAuth → SQLite → atomic CSV export → icon-first tagging. Defaults to **INR**, **UPI / NEFT / IMPS** heuristics, and Indian bank sender filters in Gmail search.

iOS can be added later; this README focuses on Android until you widen scope.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (includes Dart).
- Google Cloud project with **Gmail API** enabled and an **Android OAuth 2.0 client** (see below).

## First-time setup

```bash
cd fin_alert
flutter create .
flutter pub get
flutter run
```

`flutter create .` generates `android/`, `ios/`, etc., without replacing `lib/`.

## Project layout (modular)

| Area | Role |
|------|------|
| `lib/bootstrap/` | Wires concrete implementations into Riverpod overrides (composition root). |
| `lib/application/providers.dart` | Dependency graph: domain interfaces, owned `http.Client`, `MailSyncService`, UI `FutureProvider`s. |
| `lib/core/domain/` | **Ports** (abstract APIs) — swap SQLite / Gmail / CSV in tests or future platforms. |
| `lib/core/db/`, `export/`, `sync/`, `parse/` | **Adapters** implementing those ports. |
| `lib/features/*/` | Feature UI; each folder has a small barrel (`home.dart`, …) exporting screens. |

## Android-first checklist

1. **Package name**  
   After `flutter create`, set `applicationId` in `android/app/build.gradle.kts` (or `build.gradle`) to your final ID (e.g. `com.yourorg.finalert`). Use the **same** package name when creating the OAuth client.

2. **Release & debug SHA-1**  
   Register both with Google Cloud (needed for Google Sign-In):
   - Debug:  
     `cd android && .\gradlew signingReport` (Windows) or `./gradlew signingReport`  
     Copy **SHA1** under `Variant: debug`.
   - Release: use your upload keystore’s SHA-1 when you ship to Play.

3. **OAuth client (Android)**  
   In [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials → Create **OAuth client ID** → Application type **Android**.  
   Enter package name + SHA-1.  
   Enable **Gmail API** for the project.

4. **Manifest permissions** (usually already present after `flutter create`; verify):

   - `INTERNET`
   - For Android 13+ (API 33): `POST_NOTIFICATIONS` — the app requests this at runtime via `flutter_local_notifications`.

   Inside `<manifest>` (if missing):

   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
   ```

5. **minSdk**  
   Prefer **minSdk 24+** (align with `flutter_local_notifications` / Play requirements). Set in `android/app/build.gradle.kts` under `defaultConfig { minSdk = 24 }` (or equivalent).

6. **Physical device**  
   Gmail + Google account must be present; emulators work with a test Google account.

## Gmail API credentials (you add later)

- You do **not** embed client secrets in the app for the standard **Google Sign-In for Android** flow; the **Android OAuth client** + SHA-1 is enough.
- Restrict the OAuth consent screen to your test users until the app is verified.
- Scope in code: `https://www.googleapis.com/auth/gmail.readonly`.

## Hugging Face / cloud parsing (later)

- Keep **HF tokens only on your backend** (`server/` stub or production service).  
- In the app, enable **Allow cloud parsing** and set the backend base URL (e.g. `http://10.0.2.2:8787` from emulator to host).

## Optional parse backend (stub)

```bash
cd ../server
npm install
npm start
```

## CSV export

Writes `exports/transactions.csv` under app documents (semicolon-separated). Path is shown in **Settings**.

## Context Hub (`chub`)

Workspace rules recommend `chub` for library docs; Flutter entries were not available in the catalog at setup—use [pub.dev](https://pub.dev) for package APIs.
