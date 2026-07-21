# أذكار — Milestones & Tasks

AC-n = acceptance criterion n in PRD.md.

## M1 — Project baseline
Done when: app builds and runs on watchOS 11 simulator in Arabic/RTL with empty screen.

- [x] Lower `WATCHOS_DEPLOYMENT_TARGET` 26.5 → 11.0
- [x] Set display name أذكار
- [x] Set `ar` as development language and only localization; add String Catalog
- [x] Strip Xcode template boilerplate from `ContentView.swift` / `azkariApp.swift`
- [x] Verify RTL + system font rendering of longest dhikr (id 10) on smallest watch size
## M2 — Data & settings store
Done when: settings persist across relaunch; library exposes enabled subset.

- [x] `Dhikr` type + hardcoded 12-item library from PRD table
- [x] Settings store on UserDefaults: master on/off, interval (15m/30m/1h/2h/3h/4h), quiet start/end, enabled dhikr ids
- [x] Defaults: on, 1h, 22:00–07:00, all 12 enabled
- [x] Guard: enabled set can never become empty (AC-8)

## M3 — Scheduling engine
Done when: pending queue matches spec after every rebuild; self-check passes.

- [x] Pure function: fire times from (now, interval, quiet window) — cadence, quiet-window jump, midnight wrap, equal start/end = disabled, cap 64
- [x] Pure function: random dhikr per slot from enabled set, no consecutive repeat (AC-2)
- [x] Notification builder: body = text only, `sound = nil`, `.active`, `threadIdentifier = "dhikr"`, unique id, non-repeating `UNCalendarNotificationTrigger`
- [x] Rebuild: remove all pending + delivered, schedule fresh queue
- [x] Pause/master-off: remove all pending + delivered (AC-5)
- [x] Unit test: fire-time computation (quiet wrap, DST-agnostic wall clock, cap) + no-repeat picker

## M4 — Lifecycle & background refresh
Done when: residue clears on open; refresh chain reschedules itself; revoked permission flips master off.

- [x] Rebuild on app becoming active (AC-4, AC-6)
- [x] `WKApplicationRefreshBackgroundTask` chain: preferred 60 min while enabled; handler = rebuild + schedule next + complete
- [x] Stop chain on pause/master-off
- [x] Re-check notification auth on activation; revoked → master off + hint state

## M5 — UI
Done when: every setting reachable in ≤2 taps; all flows work on device.

- [x] Home: master toggle, interval row, links to Adhkar list and Quiet hours
- [x] Adhkar list: 12 wrapping toggle rows; block turning off last enabled + brief hint (AC-8)
- [x] Quiet hours: start/end time pickers
- [x] First-enable permission request; denied state on Home with settings hint
- [x] Wire every settings change → immediate rebuild (AC-6)

## M6 — Verify & ship
Done when: all 10 ACs pass on physical watch.

- [ ] On-device pass of AC-1…AC-8 (short interval for testing)
- [ ] Reboot test: reminders continue without opening app (AC-7)
- [ ] Code audit: no networking, no `WKExtendedRuntimeSession`, no extra frameworks (AC-9), no English strings (AC-10)
- [ ] App icon
- [ ] App Store: free, privacy label "Data Not Collected", Arabic metadata + screenshots, submit
