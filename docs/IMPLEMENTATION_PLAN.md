# Fin Alert — Implementation Plan (MVP)

**Saved:** 2026-04-12  
**Workspace:** `d:\Anudeep`  
**App package:** `fin_alert/`  

**Product defaults:** **India-first** (INR, UPI/NEFT/IMPS, Indian bank `from:` Gmail filters, DD/MM/YYYY preference) and **Android-first** (OAuth + SHA-1, notification permission, README runbook). iOS and other regions are out of scope until explicitly added.

## Context Hub note

`chub` was queried for Flutter, Riverpod, sqflite, and Gmail API topics; **no Flutter/Dart-specific doc IDs** were returned. Library usage follows **pub.dev** and current Google Sign-In + `googleapis` patterns. Re-run `chub search` as the catalog grows; annotate when you pin versions or OAuth quirks.

## Product summary

Mobile-first app: Gmail OAuth (readonly) → ingest likely transaction emails → rule-based (+ optional backend/HF) parsing → **SQLite** source of truth → **atomic CSV export** → icon-first tagging with optimistic UI and undo → hooks for analytics orchestration.

## Stack

| Layer | Choice |
|-------|--------|
| Client | Flutter 3.x, Dart 3.x |
| State | flutter_riverpod |
| Local DB | sqflite |
| Secure storage | Google Sign-In session + OS keystore (MVP); `flutter_secure_storage` can be added for extra local secrets |
| Gmail | google_sign_in + googleapis (Gmail v1) + extension_google_sign_in_as_googleapis_auth |
| CSV | csv package; atomic write via temp file + rename |
| Notifications | flutter_local_notifications |
| Prefs | shared_preferences |
| Optional backend | Node.js Express: `POST /parse/batch` (stub; HF token server-side only) |

## CSV schema (single header line)

`transaction_id;date_time;merchant;amount;currency;type;payment_mode;inferred_category;user_category;icon_id;source;raw_text;parsed_at;confidence_score`

## SQLite

- **transactions** — mirrors CSV + `synced`, `gmail_message_id`, `gmail_history_id`, `dedup_key` (unique), `needs_review`, `created_at`, `updated_at`
- **sync_state** — `last_history_id`, `last_sync_at`, `sync_window_months`
- **pending_tag_actions** — offline/queued tag updates (MVP: same-process flush)

## High-level flows

1. **Onboarding:** OAuth → store session via GoogleSignIn → persist `sync_window` → initial sync
2. **Initial sync:** `users.messages.list` with query (`newer_than`, transaction heuristics) → `messages.get` (metadata + snippet) → parse → upsert DB → export CSV
3. **Incremental:** `users.history.list(startHistoryId)` → fetch added messages → same pipeline; update `last_history_id`
4. **Tagging:** user picks icon → update `user_category`, `icon_id` → DB → atomic CSV rewrite
5. **Analytics (stub):** aggregated payloads → future `POST /analytics/query`

## Module layout (`lib/`)

- `bootstrap/` — composition root (overrides: prefs, DB, `GoogleSignIn`, CSV exporter)
- `application/` — Riverpod graph + `http.Client` lifecycle
- `app/` — `MaterialApp` / theme / home gate
- `core/domain/` — ports (`TransactionRepository`, `TransactionCsvExporter`, `TransactionParsePipeline`, `MailSyncService`)
- `core/db/` — schema + `SqfliteTransactionRepository`
- `core/export/` — `AtomicCsvExportService`
- `core/sync/` — `GmailMailSyncService`
- `core/parse/` — rules, orchestrator, backend client, `models/`
- `core/models/`, `core/config/`, `core/icons/`
- `features/*/` — UI + per-feature barrels (`home.dart`, …)
- `services/` — notifications

## Security (MVP)

- OAuth tokens: managed by **Google Sign-In** / platform secure storage where applicable
- **No HF API keys in the app**; parsing extension via backend only
- Snippet-only ingestion; consent copy on onboarding; settings: “Allow cloud parsing” toggle

## Milestones (engineering mapping)

| Phase | Deliverable |
|-------|-------------|
| M0 | This document + API stub in `server/` |
| M1 | OAuth, sync window, list messages → DB + CSV |
| M2 | Rules, dedup, confidence, atomic CSV |
| M3 | Notifications, tagging UI, undo |
| M4+ | Background sync, encryption hardening, GLM analytics |

## Backend API (optional)

- **`POST /parse/batch`** — body: `{ items: [{ id, snippet, subject, from, date_header }] }` → returns structured fields + confidence
- **`POST /analytics/query`** — deferred stub

## Acceptance tests (manual MVP)

- Complete OAuth and sync; CSV has required columns
- Tag a row; CSV updates after save
- Revoke / clear data from settings clears DB and export path

## Local development

1. Install [Flutter](https://docs.flutter.dev/get-started/install) (Dart is bundled).
2. `cd fin_alert && flutter create .` — generates `android/`, `ios/`, etc., without overwriting `lib/`.
3. Configure Google Cloud OAuth (Android SHA-1, iOS URL scheme) per [Google Sign-In Flutter](https://pub.dev/packages/google_sign_in).
4. `flutter pub get && flutter run`

## Risks

- **Gmail quotas:** batching, backoff, smaller sync windows
- **iOS background:** true &lt;5s push requires Pub/Sub + backend; MVP uses sync + local notifications
- **Parsing accuracy:** confidence + `needs_review` + user tagging
