# M6 verification log — per-AC status (2026-07-21)

Status of each PRD acceptance criterion. "Simulator/static" = verified in this
environment (Apple Watch Series 11 46mm simulator, watchOS 26.5, or static
code audit). **No physical Apple Watch is available to this environment**, so
every on-device row is BLOCKED — tasks.md M6 checkboxes stay unchecked until a
human runs the hardware steps below.

Durable evidence in this repo:
- `store/screenshots/` — 5 simulator captures (416×496): `m6-home.png`, `m6-adhkar.png`, `m6-adhkar-long.png`, `m6-quiet.png`, `check-longlook.png`. Retaken 2026-07-21 with the simulator system language/region set to Arabic (`ar-SA` / `ar_SA`) so system chrome is Arabic too (status clock in Arabic-Indic digits, long-look timestamp الآن).
- `scripts/engine_check.swift` — deterministic engine self-checks; run command is on line 1 of the file. Re-run 2026-07-21: `ENGINE_CHECK_PASS`.
- Code audit greps re-run 2026-07-21 (results below).

Other QA screenshots referenced by earlier milestones were session-scoped
simulator captures and were not retained.

| AC | Requirement (short) | Simulator / static verification | On-device |
|----|---------------------|--------------------------------|-----------|
| 1 | Reminder ≤ ~1h, body = one of 12 texts, wrist tap, no sound | Code: body-only content, `sound = nil`, `.active` (`Scheduler.swift`). Delivered notification observed on simulator with dhikr body — `store/screenshots/check-longlook.png`. Note: the permission sheet cannot be auto-accepted via `simctl privacy`; for the original session it was accepted by tapping in-session, and for the 2026-07-21 Arabic-locale retake authorization was seeded in the simulator's notification-permission store (BulletinBoard `VersionedSectionInfo.plist`), after which `-dumpQueue` reported `AUTH|2` and a full 64-slot queue. | **BLOCKED** — needs hardware (haptic feel + real fire timing). See H1. |
| 2 | No consecutive repeat (≥2 enabled) | `engine_check.swift`: `picks-no-consecutive-*`, `picks-two-alternate-*`, uniform coverage — PASS. | **BLOCKED** — observe ≥3 consecutive deliveries on watch. See H1. |
| 3 | Nothing fires in quiet hours; next after quiet end | `engine_check.swift`: quiet wrap/jump/re-anchor, boundary, start==end disabled, DST wall-clock suite — PASS. Session queue dumps matched. | **BLOCKED** — see H1. |
| 4 | Single group; open clears; refresh clears ~hourly | Code: shared `threadIdentifier = "dhikr"`, rebuild removes pending+delivered on activation, `WKApplicationRefreshBackgroundTask` chain @60min. Grouping/clearing observed in-session on simulator. | **BLOCKED** — background-refresh cadence is not representative on simulator. See H1. |
| 5 | Pause → 0 pending + delivered cleared; unpause rebuilds | Code path + in-session `-dumpQueue` showed `PENDING\|0` after pause, full queue after unpause. | **BLOCKED** — see H1. |
| 6 | Any settings change updates queue immediately | Every settings mutation calls rebuild (`ContentView.swift` → `Scheduler`). In-session dumps showed queue re-planned after interval change. | **BLOCKED** — see H1. |
| 7 | Reminders continue after reboot without opening app | Not verifiable on simulator (pending-notification persistence across a simulated reboot is not representative). | **BLOCKED** — hardware only. See H2. |
| 8 | Last enabled dhikr cannot be toggled off | Code: enabled set guarded non-empty (`Model.swift`); UI reverts toggle + hint. Observed in-session (`check-ac8-live.png`, not retained). | **BLOCKED** — see H1. |
| 9 | No networking / `WKExtendedRuntimeSession` / extra frameworks | **PASS (static, re-run 2026-07-21).** Imports: Foundation, SwiftUI, UserNotifications, WatchKit only. Grep for `URLSession\|WKExtendedRuntimeSession\|HealthKit\|CoreLocation` → 0 hits. | n/a (static criterion) |
| 10 | All UI RTL Arabic, no English visible | **PASS (re-run 2026-07-21).** String Catalog `sourceLanguage = ar`; all user-visible literals Arabic (remaining Latin literals are UserDefaults keys, debug launch args, an SF Symbol name, debug print tags). Both targets' `INFOPLIST_KEY_CFBundleDisplayName` = أذكار (container-target value fixed 2026-07-21 — was English `azkari`, which would have surfaced in the App Store / iPhone Watch-app listing). Screenshots in `store/screenshots/` retaken 2026-07-21 with simulator system language/region `ar-SA`/`ar_SA` and verified visually: no English anywhere — status clock in Arabic-Indic digits (٨:٠٤/٨:١٨), long-look chrome Arabic (الآن). Caveat: the long-look system dismiss button falls back to English on the simulator because the watchOS 26.5 *simulator runtime* ships `CarouselUIServices.framework` without `ar.lproj` (the OS's Arabic tables translate the key as استبعاد); `check-longlook.png` therefore captures the long look with the longest dhikr, whose height keeps that button below the fold — an authentic, unedited frame. | Visual pass rides along with H1. |

## Blocked hardware steps (concrete)

**H1 — On-device pass of AC-1…AC-8** (tasks.md M6, unchecked):
1. Open `azkari.xcodeproj` in Xcode, select scheme "azkari Watch App", destination = paired physical watch, Run (Debug is fine).
2. On the watch: allow notifications when prompted; set التكرار = ١٥ دقيقة; set ساعات الهدوء so "now" is outside the window.
3. Lower wrist, wait ≤15 min → expect a haptic-only notification (no sound) whose body is one of the 12 texts (AC-1).
4. Keep observing 3 consecutive deliveries → no two identical in a row (AC-2). All collapse into one group in Notification Center (AC-4); opening the app clears them (AC-4).
5. Set ساعات الهدوء to cover "now" → no reminder fires until quiet end; first one after quiet end (AC-3).
6. Toggle التذكيرات off → Notification Center empty; back on → reminders resume (AC-5). Change التكرار → next fire time follows the new interval without relaunch (AC-6).
7. In الأذكار, disable 11 items; the 12th toggle must revert with a hint (AC-8).

**H2 — Reboot test, AC-7** (tasks.md M6, unchecked):
1. With reminders enabled and a queue built (step H1.2), hold the side button → power off, then boot the watch.
2. Do **not** open the app. Expect the next reminder to fire at its already-scheduled slot after boot.

**H3 — App Store submission** (tasks.md M6, unchecked): manual, not performed
(see `store/metadata.ar.md`). Archive with the watch-only "azkari" container
scheme, upload, then complete the listing with `store/metadata.ar.md` +
`store/screenshots/` (price free, privacy "Data Not Collected").

M6 "done when" — *all 10 ACs pass on physical watch* — is therefore **not met**
from this environment; AC-9/AC-10 pass statically, AC-1…AC-8 await H1/H2.
