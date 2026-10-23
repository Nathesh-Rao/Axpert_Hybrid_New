# Offline notifications — saved discussion

Saved on 9 October 2026; implementation updated on 12 October 2026 (Asia/Calcutta).

## Status

The user approved implementation, and the notification feature is now implemented. Existing workspace changes remain saved and uncommitted; do not revert unrelated changes. No commit or deployment requested.

### 16 October: compact manual-send banner

- Implemented the approved lavender/green/amber banner at the top of Offline Forms, with a rotating sync icon, a brief completion icon animation, reduced-motion support, a continuous batch progress bar, and five-second completion auto-hide.
- Send Pending Records disables synchronously during its preflight/confirmation/operation and while an existing manual queue refresh or background sync is active. It re-enables after local work and lock cleanup; backend queued processing does not keep it disabled. The listing drawer closes when starting this action.
- Previous session-validation, previous-queue detail, upload-progress, and empty-after-refresh dialog-opening statements are preserved as comments in the manual-send action. Dialog widgets and the separate Check Submission Status action remain intact. The upload confirmation and invalid-session/login flow remain.
- The action directly reuses `validateSession`, `resolvePendingCachedSaveQueueBatches`, and `startCachedSave` under the original shared lock, in the original order. No DB batching/upload/queue-resolution or background-service function was changed for this UI update. Moved the old upload dialog's display-list reset into the controller so rendering cannot clear progress.
- New presentation files: `models/offline_send_banner_state.dart` and `widgets/offline_send_status_banner.dart`. The banner observes existing progress and accepted batch statuses; allocated `sentQueueIds` are not API-acceptance counts. Counts above 30 are covered. Completion says queued/processing, never successful processing. Existing batch notifications remain; unexpected run-level errors additionally get a scoped notification using the existing notification helper and file logging only.
- Verification: 75 tests passed across `offline_send_banner_test.dart`, `offline_notifications_test.dart`, `offline_refresh_test.dart`, and `project_edit_test.dart`. Includes actual temporary SQLite/manual action tests for success, a failed batch, resolving prior queues first, duplicate-tap protection, lock release, notification preservation, and auto-hide; widget tests cover compact narrow-screen layout and reduced motion. Logs: `offline-send-banner-regression.log`, `offline-send-banner-focused-analysis.log`. Analysis found no errors; existing warnings/info remain. No live records submitted or emulator restarted for this change.

### Implemented and verified

- Runtime note for the backend-result banner update: attach attempt 74982 was stopped after it remained waiting for a debug connection. Emulator/app were running, but no hot reload of this latest update was confirmed; the app was not restarted. Source implementation and all 90 regression tests are complete.

- 16 October backend-result banner: added a read-only `OfflineNotifications.batchBannerSnapshot` observer to the existing notification-count refresh (normally every 3 seconds). It reads scoped, already parsed batch result/issue notifications joined to form queues; no new API requests, queue writes, notification read changes or schema changes. `models/offline_batch_banner_updates.dart` correlates accepted batches from a known manual send and accumulates actual success/failure counts. Uncorrelated/background results report the individual batch; correlation is controller-session UI state, not a durable run identifier. Historical notifications are baselined on controller/scope initialization rather than replayed; new results reset the banner. Audit queues, record-level duplicate events, deleted messages and repeated polling do not raise duplicate alerts. Result alerts defer during active manual sending and display afterward without changing send-button/lock state. Unsent batches prevent misleading all-success summaries; malformed/unknown batch issues do not invent record counts. Processing result state is clickable/animated but not busy. Errors/partial failures use a 2-minute timer after each new update; success/non-error updates use 5 seconds. Expiration only hides the banner; read flags, messages, record correction, audits/retry/background logic stay unchanged. Full suite: 90 tests passed, including cumulative 36-batch results, real parsed partial API response, duplicate polling/timer checks and existing offline flows; analysis found no errors (legacy warnings/info remain). Logs: `offline-batch-result-banner-regression.log`, `offline-batch-result-banner-analysis.log`. Earlier attach 55837 had disconnected; new attach attempt 74982 is waiting for the app connection, not yet confirmed applied on emulator.

- 16 October form-only submission UI: inspected emulator metadata read-only and found batch size 30, two form batches (3 records, then 1 record in a later send) plus two audit batches (15 and 2 entries); no form record appeared in multiple pending batches. User approved hiding audits only. Added reusable controller `formSubmissionQueues` presentation filter for the Check Submission Status badge, confirmation count and initial/refreshed queue list. `CachedRefreshDialogWidget` defensively filters initial rows and displayed result/summary rows by the form queue IDs. Legacy rows without a source remain visible as form queues. Shared `getPendigQueuesToRefresh`, both resolvers, batch creation/upload, audit timing and background sync remain unchanged and continue including audit queues. Three new tests cover legacy/form visibility, audit-only zero badge with backend rows retained, and mixed four-queue resolution showing only two form rows while the mock API/shared resolver process all four. Full suite: 81 tests passed; no analysis errors (existing warnings/info remain). Hot reload confirmed on emulator-5554 via attach session 55837. Logs: `offline-submission-form-only-regression.log`, `offline-submission-form-only-analysis.log`.

- 16 October reset lifecycle correction: the emulator showed `_dependents.isEmpty`; attaching exposed the first error, `A TextEditingController was used after being disposed`. Reproduced in a new focused-field widget test that pumps frames while lookup I/O/reset is in progress. `prepareForm` and the existing schema controller builder now accept optional `reuseControllers` (default false). Only same-form `startNewTransaction` passes true: restore defaults on the existing text/Rx dropdown objects, keep current lookup data and business subscriptions, and avoid disposing mounted controllers or clearing lookups mid-reset. Opening another form and notification corrections retain their normal setup. The regression verifies text/dropdown identity, defaults, lookup preservation and one persisted record; 78 full regression tests passed. Analysis has no errors (existing warnings/info remain). Applied to emulator-5554 via Flutter attach/hot restart, confirmed recovery to Offline Forms without submitting a live record. Logs: `offline-form-mounted-reset-regression.log`, `offline-form-mounted-reset-analysis.log`, `app-form-reset-recovery.log`. Attach session 55837 may be reusable. Emulator currently embedded in Android Studio's Running Devices window. This supersedes the earlier follow-up's reset-by-controller-replacement detail below.

- 16 October follow-up: normal new-record saves now keep `OfflineFormPage` open and call the existing `startNewTransaction`/`prepareForm` setup after successful persistence. Removed the duplicate controller-disposal/reset work inside `startNewTransaction`, clear entry attachments/focus, restore schema defaults and cached lookups, and attach the normal form list to `scrollCtrl` so it returns to the first field. A brief saved confirmation appears on the form. Notification correction saves retain their existing return-to-results behavior. Failed validation/save does not reset entered data. 77 regression tests passed, including two consecutive persisted new records on the same route, restored defaults, scroll reset, validation preservation, and existing correction/audit checks. No analysis errors; existing warnings/info remain. Logs: `offline-form-next-record-regression.log`, `offline-form-next-record-analysis.log`.

- Separate `pages/offline_notifications_page.dart`, `widgets/offline_notification_card.dart`, notification model, SQLite store and DB integration in the existing offline module.
- Bell beside Settings, scoped persistent unread badge/history, clear-on-view, swipe either direction with Undo, and confirmed Clear All. Deleted events keep a hidden tombstone to prevent repeated results resurrecting deleted messages.
- SQLite schema version 13 migrates existing data without replacing it. Adds `offline_notifications`, plus `current_queue_id` and `record_version` on pending records.
- Acceptance notifications generated by the existing shared queue persistence function for both manual and background batches. Audit-log batches are excluded.
- Queue-ID triggers fetch detailed results on foreground/background paths. Pending triggers are persisted if synchronization owns the lock, and retried from the foreground with per-queue backoff. Missing/malformed/conflicting details leave records untouched and generate an explanatory notification.
- Existing queue parser is reused by FCM triggers and manual/background polling. Detailed arrays drive counts. Record membership and active queue bindings protect against conflicting IDs and stale responses.
- Card taps load the existing form and saved record. Free-prose field-name/caption matching uses whole phrases, case/spacing normalization, and ambiguity fallback to form-level errors.
- `savePayloadForQueue` accepts optional correction context. Normal inserts retain the existing path. Corrections update the same row, increment its version, clear the previous error/queue binding, and mark it PENDING. Extra DCs/rows/unknown fields/attachment objects are preserved. A short shared sync lock and version/status checks prevent concurrent overwrites.
- Notification actions use `LogService.writeLog` only. Correction saves use that service and `OfflineDbModule.logAudit`.
- Existing ERROR retry policy remains unchanged. Editing does not pause background sync; saving asks the user to retry if synchronization currently owns the lock or that record is already queued.
- Added test-only `sqflite_common_ffi` and `path_provider_platform_interface` dependencies. 64 focused tests passed: 39 notification/SQLite/UI/update tests, 21 existing refresh tests, 4 existing project-edit tests.
- Static analysis has no errors; legacy warnings/info remain. Debug APK built/installed on Pixel 9 Pro; version-13 migration completed. Flutter run session at implementation time: 45962 (may not survive closing/reopening the desktop app).
- API tests used mocked HTTP responses and real SQLite. No manual submission of live user records was performed to test the backend.
- Refresh reporting design revised with user approval: one refresh notification per operation (All or selected form), with dynamic updated/total form counts and lookup counts grouped by form. Lookup errors are now embedded inside the refresh report rather than emitted as separate notifications. Form-download errors are inside Offline forms; lookup errors are expandable under the appropriate form in Lookup data. Light dividers separate forms only in the details dialog. Old standalone lookup notifications stay in history. Optional observer parameters reuse existing fetch functions; API progress counters and normal callers remain unchanged. Valid empty lookup rows remain successful.
- Lookup descriptions retain readable server explanations. Technical SQL/transport/storage diagnostics are logged and replaced with clear guidance. Update cards open a details dialog; record-error navigation/correction remains unchanged.
- Full-backup download/share generates notifications only after completion; cancelled sharing produces none and an unavailable share acknowledgement gets a warning. DB-only upload was entirely commented out, so it now throws an explicit unavailable error instead of falsely claiming a successful upload. Full Backup download/share remain available.
- Notification history uses the existing version-13 table and captured user/project scope. Structured refresh snapshots are stored in a versioned JSON envelope in the existing message column, with a readable summary and backward-compatible model parsing. No schema migration is needed. Existing update events use the unread badge, clear/swipe/undo flow and `LogService.writeLog` only; no additional notification audit rows. Existing export audits remain in place.
- Refresh All downloads a shared authoritative form-list response. Do not infer individual download failures from forms omitted by that list (they could be removed on the server). A shared download failure reports the known cached form names; successful form counts exclude menu pages. Refresh lookup progress observes each actual form's existing success/failure deltas, including unequal lookup totals and no-lookup forms.
- Regression tests passed and the running Pixel 9 Pro app was hot-reloaded successfully after these changes.
- Delete/Undo snackbar fix: installed Flutter defaults action snackbars to persistent. Explicit `persist: false` and a four-second duration now dismiss the bar automatically. Two focused widget tests verified Undo restoration and automatic dismissal without restoring a deleted message. Test connectivity double now suppresses its inherited platform stream. App hot-restarted to clear the old already-displayed snackbar.
- Card-only refinement approved: refresh cards use the Compact clarity design (lavender inline Offline forms summary; white Lookup data section with teal icon/heading; updated/total and failure badge aligned against each form; no repeated updated counts; plain View details footer). Existing orange title status icon is unchanged. `_CardRefreshBreakdown` is presentation-only; detailed dialog/shared detail widgets, stored reports and all sync/API logic stay unchanged. Four focused UI tests passed and card-file static analysis reported no issues.
- On 14 October the user requested exact lookup API errors instead of polished messages. Refresh now passes `preserveOriginal: true` to the existing formatter, preserving SQL codes/quotes/CRLF/position text. Datasource diagnostics extract `error`, `message` and nested `result` values without rewriting strings. Existing friendly-format callers retain their default behavior. Older stored notifications remain unchanged; refresh again to obtain exact errors. 67 focused regression tests passed, including verbatim `42601: syntax error at or near ";"` with `POSITION: 127` on All and selected refresh. No server refresh/submission was initiated for this verification.
- Exact-error spacing refinement: API `\r\n\r\n` created the visible blank line. The details UI now removes empty lines and normalizes CRLF for display only, retaining one normal line break before POSITION. Raw stored errors and refresh logic stay unchanged. Focused tests verify raw syntax-error persistence and the compact displayed error in the expanded narrow-screen dialog.

Prototype:
`C:/Users/naras/.codex/visualizations/2026/10/09/01a11eed-7cc4-76f2-bf71-fb01f0985076/offline-notification-flow.html`

Reference response:
`C:/Users/naras/.codex/attachments/d16eec91-2774-47bf-9da2-b901e7155392/Pasted text.txt`

Reload the full visualize skill before creating or updating a visualization.

## Agreed behavior

1. Send Offline Records bundles pending records according to configured batch size and sends each batch to the queue API.
2. After the queue API accepts a batch, generate a durable in-app notification saying the batch was sent for processing. Acceptance is separate from processing success.
3. Backend processing sends a notification with the queue ID. This triggers an API call to retrieve detailed batch results. Use the detailed API response for success/failure handling and in-app notification generation, rather than assuming the trigger includes all details.
4. Generate notifications for batch results/issues and individual record errors.
5. Add the notification bell beside Settings on Offline Forms. New notifications increase the unread badge; opening the panel clears unread state while retaining history.
6. Tapping the entire record-error card opens the corresponding form with that existing offline record's saved data. No separate "Open record & correct" button.
7. Search the entire error message for the current form's field names AND captions. Do not require a prefix such as "Field", quotes, or a fixed sentence format. Match ignoring case and normalizing spacing, using complete words/phrases. Highlight only an unambiguous match. If no field is identified, show the error at form level without highlighting. Do not guess from SQL error codes or index values.
8. Saving corrections updates the SAME local DB row and record ID, not a new submission. It becomes eligible for manual/background sync. Preserve background form access.
9. Persist notification history/read state across restarts, scoped by project/user. Deduplicate repeated responses. Guard against old queue results overwriting a corrected/resubmitted record.

## Approved prototype

Consistent rounded purple styling across Offline Forms, Notifications, and Inward Entry correction screen. Prototype includes sending a batch, simulated backend results, badge clearing, individual record-error cards, field-specific and general-error examples, and correction/save-ready state. "Single record error" is a preview control outside the depicted app. The record card itself navigates to the form.

## Code locations verified

- `lib/app/modules/offline_form_pages/db/offline_db_module.dart`
  - `startCachedSave` around line 4340: manual batch push flow.
  - `_buildBatchMap` around 4851: batch-size grouping; currently selects PENDING and ERROR records.
  - `_pushPayloadToServer` around 4525: manual API acceptance, durable queue row, record QUEUED status.
  - `runCachedSave` around 9165 and `_pushPayloadBackgroundSafe` around 9440: background flow.
  - `processCachedSaveQueueFCM` line 7839, `handleCachedSaveQueueFcmUpdate` line 7907: notification response entry/routing.
  - `_handleQueuePartialOrError` line 8266: parses per-record success/failure lists.
  - `_resolveSingleQueueFromRow` line 5789: detailed API status result parsing; extracts nested `message.data` and updates per-record rows.
  - `_parseTransactionList` line 7832: handles arrays or JSON-encoded arrays.
  - `_updateStatusAndResponse` around 8732: currently stores status and flat message by ID.
  - `savePayloadForQueue` around 6540: currently inserts new records; correction mode needs an update path.
- `lib/app/data/services/notification/firebase_notificastion.dart` line 104 calls `processCachedSaveQueueFCM(message.data)` in foreground path. Verify the queue-trigger-to-detail-fetch sequence before implementation; current parser treats the notification data as results.
- `lib/app/modules/offline_form_pages/controller/offline_form_controller.dart`: `prepareForm` initializes default controllers; needs existing-record hydration. `onFormSubmit` currently inserts; needs correction context. `errors` map can display matched field errors.
- `lib/app/modules/offline_form_pages/pages/offline_listing_page.dart`: bell belongs beside Settings.
- `lib/app/modules/offline_form_pages/pages/offline_form_page.dart`: existing field error rendering can be reused.
- `lib/app/modules/offline_form_pages/auto_sync/offline_sync_task_handler.dart`: inspect shared background queue resolution/sending hooks.

## Findings / unresolved points

- Sample is an outer `message.token` / `message.data` envelope, with queue ID, `partial_success`, 11 success entries and 3 failed entries. Every entry repeats local `axm_recid` 1122333 (including success and failure), so it cannot safely represent 14 distinct local records. Confirm whether this is anonymized sample data. Real IDs must map unambiguously to local records.
- Sample failures contain `error_message.result.message`: `22001: value too long for type character varying(5)`. No field name/caption is present. User explicitly accepted form-level error fallback; backend may include captions in other message texts.
- Success `recordid` is the server record ID, not local `axm_recid`. Use local stored payload to identify the original form rather than assuming response `transid: cache` represents the original form.
- `processCachedSaveQueueFCM` currently uses `int.tryParse` on transaction arrays, initially producing zero counts; subsequent handlers parse arrays correctly. Fix when implementing the verified detail-fetch flow.
- Existing record handlers process success entries then failures; repeated IDs can overwrite success with failure.
- Decide validation-failure retry behavior: recommendation is hold validation failures for correction, allow transient failures to retry. User has not explicitly answered this policy yet. Current ERROR records are automatically selected again.

## Earlier completed work to preserve

Refresh dialog and drawer renames are implemented. Refresh All retains existing behavior; individual form refresh reuses existing functions with optional parameters and refreshes that form plus associated lookup data. Counters dynamically count refresh data operations, excluding session validation/renewal. `test/offline_refresh_test.dart` had 21 passing tests. Other project/auth UI and project edit/caption changes are present in the workspace; do not treat them as notification changes or undo them.

## Resume

Read the implementation status above and inspect current code before continuing. The user explicitly authorized implementation on 12 October 2026. The older discussion below records the design decisions; line numbers may have shifted. Next useful verification is a real backend batch result during the user's normal sync workflow, particularly the actual field-message wording and notification delivery.
