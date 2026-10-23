# Offline module review — 12 October 2026

Read-only review of the current workspace. No application source was changed during this review.

## Verification and limits

- 65 focused tests passed: notification persistence/deletion/Undo, queue responses and correction guards, same-record correction, refresh All/selected form, dynamic API counters, unequal lookup totals, empty lookups, integrated error details, narrow-screen cards/dialogs, export notifications and project editing.
- Static analysis of the offline module: no errors; 129 warnings/information items, mostly unused code/imports and style diagnostics. These are not all functional bugs.
- Review traced the active form, queue, background task, backup/restore, audit and notification paths. Live backend submission, destructive clearing/restoration, crash/power-loss recovery and device-scale performance were not executed.
- Passing current tests does not establish full enterprise readiness. The failures below largely concern paths absent from current regression coverage.

## Findings in priority order

### 1. P1 — Refresh All bypasses the shared queued sync path and lock

`controller/offline_form_controller.dart:1703` acquires the shared lock only for selected-form refresh. At line 1769, Refresh All calls `processPendingQueue`. `db/offline_db_module.dart:1531` sends individual records directly to the published API, rather than the queued batch flow used by manual/background cached save. Its final status update at line 2222 checks IDs only, without record version/current-queue guards.

If background batch building/upload or a correction save overlaps Refresh All, both can read the same pending record. The direct path can then overwrite a newly queued/corrected record's status, and the record can be submitted more than once. Direct upload also bypasses queue acceptance/result notifications. Route all submission entry points through the existing shared queue core and lock; retain the existing refresh API-operation counter semantics.

### 2. P1 — Restore overwrites a live database without safe replacement

`db/offline_bundle_service.dart:674` / line 794 copies a temporary DB over the active DB path and calls `OfflineDbModule.init()`. It does not close the existing main-isolate DB handle, coordinate the background isolate, acquire the shared sync lock or perform an atomic swap/automatic rollback. `controller/offline_form_controller.dart:2771` imports while the normal app services remain active.

An import during synchronization or a failed copy can leave a stale connection, lose concurrent writes or damage the active DB. A ZIP without `offline_forms.db` can finish without throwing, allowing the UI to report success. Validate the entire bundle/schema first; coordinate both isolates; take a consistent backup; close handles; stage and atomically replace; reopen/migrate; roll back on failure.

### 3. P1 — Exported backups contain unprotected credentials and all stored profiles

`db/offline_db_module.dart:9440` explicitly reads plaintext credentials from the column named password_hash; raw login/session JSON is also stored at line 3236. `db/offline_bundle_service.dart:163` exports the entire DB using ordinary ZIP encoding at line 184, and the Download action places it in public Downloads. `getRawPendingRequests` is also unscoped and enumerates all stored records for attachments.

This exposes stored credentials and business data from other saved users/projects when a backup is shared or copied. Remove credentials/session tokens from export, protect reusable credentials in secure storage, define and enforce export scope/authorization, and encrypt protected backup data. The current “secure bundle” wording does not match the implementation.

### 4. P1 — Delete Pending Submissions can race with synchronization

`db/offline_db_module.dart:2979` deletes all scoped pending-request rows regardless of status, including records already accepted into a backend queue. It then deletes queue tracking in a second independent operation. `actionClearPending`/`actionClearAll` do not acquire the shared sync lock.

If an upload is in flight, the server may process records after their local tracking has disappeared. Failure between the two deletes also leaves inconsistent tracking. Use the common lock and one DB transaction; distinguish unsent records from queued submissions; make the confirmation accurately describe what is deleted and what cannot be cancelled on the server.

### 5. P2 — Attachment backups can lose or substitute files

`db/offline_bundle_service.dart:173` archives attachments by basename only. Two different paths containing the same filename map to one archive destination. Import at line 715 extracts to that same basename. Missing attachments at line 180 are only logged, while export still reports success.

Use unique asset identifiers plus a manifest mapping original paths to archive paths. Validate required attachment completeness and warn/block incomplete backups instead of reporting a fully successful export.

### 6. P2 — Read-only dropdown and date metadata is not enforced

`pages/offline_form_page.dart:221` / line 231 do not pass `f.readOnly` into dropdown/date builders. Dropdown `onChanged` at line 440 depends only on dependency readiness, and the date picker at line 485 opens unconditionally.

A field marked read-only by the server can still be changed from this UI. Pass and enforce read-only metadata for every field type, including disabling picker/dropdown actions. Server authorization remains essential; this UI restriction alone is not security enforcement.

### 7. P2 — Schema rendering and validation are incomplete for a general form engine

The active renderer at `pages/offline_form_page.dart:178` supports c, n, dd, date, year, time and datetime; other types silently return an empty widget at line 273. The separate helper supporting memo/checkbox/radio/image is unused by this page. `controller/offline_form_controller.dart:792` validates only empty required values, including hidden fields, without checking numeric/date/type/length constraints.

For forms with unsupported types, fields can disappear or mandatory data can become impossible to enter. Hidden required fields without defaults also block saving with only a generic Missing Fields message. Define the supported offline schema contract, fail clearly for unsupported schemas, use consistent metadata normalization across controllers/renderers/payload generation, and add type-aware validation. Do not reject legitimate backend/default-filled hidden fields blindly.

### 8. P2 — DB audit logs discard the supplied response

`db/offline_db_module.dart:3362` writes an empty response string even when `logAudit(response: ...)` receives API/error details. The action, error flag and remarks survive, but the supplied response never reaches the audit table.

Persist a bounded, redacted response or structured diagnostic reference so failed operations can be investigated. Preserve the approved distinction: notification actions use file logs; record resaves use file and DB audit logs.

### 9. P2 — Background UI equates queue acceptance with processing completion

`auto_sync/offline_background_sync_service.dart:313` shows “All synced” whenever pendingCount is zero. `db/offline_db_module.dart:3045` counts only PENDING/ERROR records, excluding QUEUED records awaiting backend processing.

After a successful queue upload, pendingCount can be zero while backend processing is incomplete or may later fail. Show separate unsent, queued/processing, successful and failed states; reserve “All synced” for resolved submissions. Keep the existing acceptance/result notification distinction.

### 10. P2 — Backup work can block the UI and use excessive memory

`db/offline_bundle_service.dart:132` builds the whole archive in memory, reads each asset into memory, then synchronously ZIP-encodes it at line 184. It also copies the live DB file without a consistent SQLite snapshot or coordination with writers.

Large enterprise datasets/attachments can cause UI stalls or memory pressure, and the DB/attachment snapshot can be inconsistent during sync. Create a consistent snapshot, stream large files/archive output, move CPU-heavy encoding off the UI isolate, and expose progress/cancellation without aborting a committed restore.

### 11. P2 — Form preparation/save UI does not reliably represent loading/failure

`controller/offline_form_controller.dart:244` sets isFormPreparing but has no try/finally around schema/controller/datasource preparation. An exception can leave partial controllers and preparation state stuck. `pages/offline_form_page.dart:46` hardcodes the Submit button's loading flag to false.

The controller prevents duplicate saves, but the button does not show that a save is running. Add a guaranteed preparation cleanup/error state and bind the button's progress/disabled appearance to the actual save state. Keep editing/background sync responsive.

### 12. P2 — Shared sync lock lease is not renewed for long operations

`db/offline_db_module.dart:333` grants a fixed 30-minute lease and reclaims it after expiry. There is no renewal/heartbeat for ongoing batches. Large uploads or slow servers can outlive that lease.

Another synchronization/correction operation can acquire the lock while the original owner still works. Renew the lease while active and verify ownership before state changes; preserve the owner-specific release. Recovery must still reclaim abandoned leases after a crashed process.

## Additional maintenance/UI notes

- `OfflineFormController.onClose` only cancels the notification timer. It does not dispose its text/scroll controllers, and the `ever` connectivity worker created at line 668 is not retained/disposed. This needs lifecycle cleanup when controllers are recreated.
- DB-only upload remains deliberately unavailable; it must be hidden/disabled or explained clearly rather than offered as a working export choice.
- Several form/confirmation screens hardcode white/black colours and small text; accessibility, text scaling, dark appearance and long labels require broader device testing.
- Existing ERROR auto-retry behavior is unchanged. Distinguishing permanent validation failures from retryable transport failures remains an explicit product policy decision.

## Recommended sequence

1. Unify submission/lock entry points and make destructive operations safe.
2. Secure and validate backup/restore, including attachments and scope.
3. Enforce schema/read-only rules and restore useful audit diagnostics.
4. Correct processing-state labels, loading/lifecycle behavior and large-data performance.
5. Expand tests to cover concurrent refresh/background/correction, interrupted restore, malicious/incomplete bundles, duplicate attachment basenames and long-running sync leases before enterprise rollout.
