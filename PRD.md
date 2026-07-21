# أذكار — Standalone watchOS Dhikr Reminders

Standalone Apple Watch app, no iOS companion. At a user-set interval it taps the wrist and shows one dhikr — picked at random from the enabled subset of a built-in 12-item library — as a local notification engineered to leave no clutter. Arabic-only, fully offline, free, battery-first, minimal UI.

## Goals
- Peaceful periodic dhikr reminders with zero notification clutter.
- Negligible battery: no extended-runtime/workout sessions, no complication, no network. Only system-scheduled local notifications + opportunistic background refresh.
- Any setting reachable in ≤2 taps from home.
- Reminders survive reboot and app updates without user action.

## Non-goals (v1)
Tasbih counter, stats/streaks, iOS companion, complication/watch face, custom user adhkar, categories, accounts, network access, monetization, timed pause, Sleep Focus integration, non-Arabic locales — but all UI strings go through a String Catalog so locales can be added later.

## Platform
- watchOS 11+, SwiftUI, standalone watch app. Existing `azkari` Xcode project; lower `WATCHOS_DEPLOYMENT_TARGET` from 26.5 to 11.0.
- Display name: أذكار. Development language and only localization: `ar` (RTL, system font).
- Frameworks: SwiftUI, UserNotifications, WatchKit (background refresh). Nothing else.
- Persistence: UserDefaults only. Dhikr library hardcoded as Swift data (`id`, `text`).
- Privacy: no data collected (App Store label "Data Not Collected").

## Dhikr library (all enabled by default)
| id | text |
|----|------|
| 1 | سبحان الله |
| 2 | الحمد لله |
| 3 | لا إله إلا الله |
| 4 | الله أكبر |
| 5 | أستغفر الله |
| 6 | سبحان الله وبحمده |
| 7 | سبحان الله العظيم |
| 8 | لا حول ولا قوة إلا بالله |
| 9 | اللهم صلِّ وسلم على نبينا محمد |
| 10 | لا إله إلا الله وحده لا شريك له، له الملك وله الحمد، وهو على كل شيء قدير |
| 11 | أستغفر الله العظيم وأتوب إليه |
| 12 | سبحان الله والحمد لله ولا إله إلا الله والله أكبر |

## Settings & defaults
| Setting | Values | Default |
|---|---|---|
| Reminders (master toggle) | on / off | on |
| Interval | 15m, 30m, 1h, 2h, 3h, 4h | 1h |
| Quiet hours | start + end time pickers; may wrap midnight | 22:00–07:00 |
| Per-dhikr toggles (×12) | on / off | all on |

## Scheduling engine
1. **Build queue**: from now, compute successive fire times at `interval` cadence in local wall-clock time; any time falling inside the quiet window jumps to quiet end. Cap: 64 pending notifications (system limit).
2. **Per notification**: body = dhikr text (no title), random from enabled set, uniform, no same dhikr in consecutive slots (when ≥2 enabled). `sound = nil` (default system haptic only), `interruptionLevel = .active`, shared `threadIdentifier = "dhikr"`, unique identifier, non-repeating `UNCalendarNotificationTrigger`.
3. **Rebuild** = remove all pending + all delivered, then build queue. Triggered by: app becoming active, any settings change, background refresh, unpause.
4. **Background refresh**: while enabled, maintain a `WKApplicationRefreshBackgroundTask` chain, preferred every 60 min. Handler: rebuild, schedule next refresh, complete task. This clears residue roughly hourly and keeps the queue full and DST-correct.
5. **Pause / master off**: remove all pending + delivered; stop the refresh chain.
6. **Reboot / update**: pending notifications persist (system behavior) → coverage floor with zero runtime = 64 × interval of active hours. If watchOS starves the refresh chain and the queue drains, reminders resume on next app open — accepted limitation.

## UI (3 screens)
- **Home**: master toggle (1 tap), interval row, rows to Adhkar list and Quiet hours (each 2 taps to change).
- **Adhkar list**: 12 toggle rows, full text wrapping. Turning off the last enabled item is blocked (toggle reverts + brief hint).
- **Quiet hours**: start and end time pickers. Equal start and end = quiet hours disabled.
- **Permissions**: first enable requests notification authorization. Denied → master toggle stays off, home shows a short hint to enable notifications in watch Settings. Re-check auth status on every activation; if revoked, flip master off with hint.

## Edge cases
- Quiet window wrapping midnight handled in fire-time computation.
- Timezone/DST change: wall-clock scheduling self-corrects at next rebuild (≤ ~1h via refresh).
- 15m interval → queue covers ~1 active day; acceptable given hourly refresh and rebuild-on-open.

## Acceptance criteria
1. Fresh install, permission granted, defaults: a reminder fires within ~1h; body is one of the 12 texts; wrist tap, no sound.
2. With ≥2 enabled adhkar, consecutive reminders never repeat the same text.
3. No reminder fires inside quiet hours; next fires after quiet end.
4. All delivered reminders collapse into a single Notification Center group; opening the app clears them; background refresh clears them roughly hourly.
5. Pause → 0 pending requests and delivered cleared; unpause rebuilds immediately.
6. Any settings change updates the pending queue immediately, no restart.
7. Reminders continue after watch reboot without opening the app.
8. The last enabled dhikr cannot be toggled off.
9. No networking, no `WKExtendedRuntimeSession`, no HealthKit/location — only the listed frameworks.
10. All UI renders RTL Arabic; no English visible.
