// cd "/Users/goldentik/Documents/azkari" && swiftc "azkari Watch App/Model.swift" "azkari Watch App/DhikrEngine.swift" scripts/engine_check.swift -o /tmp/engcheck && /tmp/engcheck
//
// Deterministic self-checks for DhikrEngine. Prints ENGINE_CHECK_PASS on success,
// FAIL|<name> and exits 1 on the first failure. (swiftc multi-file mode forbids
// top-level expressions outside main.swift, hence the @main wrapper.)

import Foundation

// Fixed calendar + timezone (UTC+3, no DST) so every expectation is exact.
let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Riyadh")!
    return c
}()

// DST timezone for the wall-clock checks (EU transitions: last Sunday of
// March springs forward 02:00→03:00, last Sunday of October falls back
// 03:00→02:00; in 2026 that is Mar 29 and Oct 25).
let berlin: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return c
}()

func bat(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int = 0) -> Date {
    berlin.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
}

func berlinMinutesOfDay(_ t: Date) -> Int {
    berlin.component(.hour, from: t) * 60 + berlin.component(.minute, from: t)
}

func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int = 0) -> Date {
    cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
}

func minutesOfDay(_ t: Date) -> Int {
    cal.component(.hour, from: t) * 60 + cal.component(.minute, from: t)
}

func check(_ condition: Bool, _ name: String) {
    if !condition {
        print("FAIL|\(name)")
        exit(1)
    }
}

/// Tiny seeded LCG (Knuth MMIX constants) for reproducible pickTexts runs.
struct LCG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

@main
enum EngineCheck {
    static func main() {
        // 1. Exact cadence spacing, quiet disabled (start == end), default cap 64.
        let now = at(2026, 7, 21, 10, 0)
        let plain = fireDates(now: now, intervalMinutes: 60, quietStartMinutes: 540, quietEndMinutes: 540, calendar: cal)
        check(plain.count == 64, "cap-default-64")
        for (i, d) in plain.enumerated() {
            check(d == now.addingTimeInterval(TimeInterval(i + 1) * 3600), "cadence-exact-\(i)")
        }

        // 2. Explicit cap respected.
        check(fireDates(now: now, intervalMinutes: 15, quietStartMinutes: 540, quietEndMinutes: 540, calendar: cal, cap: 10).count == 10, "cap-custom-10")

        // 3. Wrap window 22:00-07:00 — evening fire jumps to next-day quiet end,
        //    lands exactly on 07:00:00 (seconds stripped), cadence re-anchors.
        let wrapped = fireDates(now: at(2026, 7, 21, 20, 30, 42), intervalMinutes: 60, quietStartMinutes: 1320, quietEndMinutes: 420, calendar: cal)
        check(wrapped[0] == at(2026, 7, 21, 21, 30, 42), "wrap-first-before-window")
        check(wrapped[1] == at(2026, 7, 22, 7, 0, 0), "wrap-jump-exactly-quiet-end")
        check(wrapped[2] == at(2026, 7, 22, 8, 0, 0), "wrap-reanchor-1")
        check(wrapped[3] == at(2026, 7, 22, 9, 0, 0), "wrap-reanchor-2")
        for (i, d) in wrapped.enumerated() {
            check(!isQuiet(minutesOfDay: minutesOfDay(d), quietStartMinutes: 1320, quietEndMinutes: 420), "wrap-none-inside-\(i)")
        }

        // 3b. Early-morning side of the wrap: fire before 07:00 jumps within the same day.
        let morning = fireDates(now: at(2026, 7, 21, 1, 30), intervalMinutes: 60, quietStartMinutes: 1320, quietEndMinutes: 420, calendar: cal)
        check(morning[0] == at(2026, 7, 21, 7, 0), "wrap-morning-same-day-jump")
        check(morning[1] == at(2026, 7, 21, 8, 0), "wrap-morning-reanchor")

        // 3c. Re-anchored cadence with a 90-minute interval.
        let ninety = fireDates(now: at(2026, 7, 21, 20, 0), intervalMinutes: 90, quietStartMinutes: 1320, quietEndMinutes: 420, calendar: cal)
        check(ninety[0] == at(2026, 7, 21, 21, 30), "wrap90-first")
        check(ninety[1] == at(2026, 7, 22, 7, 0), "wrap90-jump")
        check(ninety[2] == at(2026, 7, 22, 8, 30), "wrap90-reanchor-1")
        check(ninety[3] == at(2026, 7, 22, 10, 0), "wrap90-reanchor-2")

        // 4. Non-wrapping window 13:00-14:00.
        let lunch = fireDates(now: at(2026, 7, 21, 12, 30), intervalMinutes: 60, quietStartMinutes: 780, quietEndMinutes: 840, calendar: cal)
        check(lunch[0] == at(2026, 7, 21, 14, 0), "nonwrap-jump")
        check(lunch[1] == at(2026, 7, 21, 15, 0), "nonwrap-reanchor")

        // 4b. Exactly AT quiet start is inside -> jumps.
        let atStart = fireDates(now: at(2026, 7, 21, 12, 0), intervalMinutes: 60, quietStartMinutes: 780, quietEndMinutes: 840, calendar: cal)
        check(atStart[0] == at(2026, 7, 21, 14, 0), "boundary-at-start-jumps")

        // 4c. Exactly AT quiet end is allowed -> stays.
        let atEnd = fireDates(now: at(2026, 7, 21, 12, 0), intervalMinutes: 120, quietStartMinutes: 780, quietEndMinutes: 840, calendar: cal)
        check(atEnd[0] == at(2026, 7, 21, 14, 0), "boundary-at-end-allowed")
        check(atEnd[1] == at(2026, 7, 21, 16, 0), "boundary-at-end-cadence")

        // 5. start == end -> no quiet window even when a fire lands exactly on it.
        let disabled = fireDates(now: at(2026, 7, 21, 8, 30), intervalMinutes: 30, quietStartMinutes: 540, quietEndMinutes: 540, calendar: cal, cap: 4)
        check(disabled == [at(2026, 7, 21, 9, 0), at(2026, 7, 21, 9, 30), at(2026, 7, 21, 10, 0), at(2026, 7, 21, 10, 30)], "start-equals-end-disabled")

        // 6. pickTexts: no consecutive repeats over many picks, avoidingFirst honored,
        //    uniform enough that every text appears.
        var rng = LCG(state: 20_260_721)
        let pool = ["أ", "ب", "ج"]
        let picks = pickTexts(count: 500, from: pool, avoidingFirst: "أ", using: &rng)
        check(picks.count == 500, "picks-count")
        check(picks[0] != "أ", "picks-avoids-first")
        for i in 1..<picks.count {
            check(picks[i] != picks[i - 1], "picks-no-consecutive-\(i)")
        }
        for text in pool {
            check(picks.contains(text), "picks-uniform-covers-\(text)")
        }

        // 6b. avoidingFirst forces the only alternative, for any seed.
        for seed in 1...20 {
            var r = LCG(state: UInt64(seed))
            let two = pickTexts(count: 3, from: ["أ", "ب"], avoidingFirst: "أ", using: &r)
            check(two == ["ب", "أ", "ب"], "picks-two-alternate-seed-\(seed)")
        }

        // 6c. Single-item pool: repeats allowed, avoidingFirst ignored, no hang.
        var single = LCG(state: 7)
        check(pickTexts(count: 10, from: ["س"], avoidingFirst: "س", using: &single) == Array(repeating: "س", count: 10), "picks-single-item")

        // 6d. Pool with duplicates of one text counts as a single distinct choice.
        var dupes = LCG(state: 9)
        check(pickTexts(count: 5, from: ["س", "س"], avoidingFirst: "س", using: &dupes) == Array(repeating: "س", count: 5), "picks-duplicate-pool")

        // 7. DST fall-back night (Europe/Berlin 2026-10-25, 03:00 CEST → 02:00 CET,
        //    a 25-hour day), quiet 22:00-07:00. Elapsed-minutes math would exit
        //    quiet at 06:00 wall clock — inside the window (AC-3 violation).
        //    The exit must be 07:00 WALL CLOCK.
        check(bat(2026, 10, 26, 0, 0).timeIntervalSince(bat(2026, 10, 25, 0, 0)) == 25 * 3600, "dst-fallback-day-is-25h")
        let fallBack = fireDates(now: bat(2026, 10, 24, 21, 30), intervalMinutes: 60, quietStartMinutes: 1320, quietEndMinutes: 420, calendar: berlin)
        check(fallBack[0] == bat(2026, 10, 25, 7, 0), "dst-fallback-exit-at-wall-clock-7")
        check(fallBack[1] == bat(2026, 10, 25, 8, 0), "dst-fallback-reanchor")
        for (i, d) in fallBack.enumerated() {
            check(!isQuiet(minutesOfDay: berlinMinutesOfDay(d), quietStartMinutes: 1320, quietEndMinutes: 420), "dst-fallback-none-inside-\(i)")
        }

        // 7b. Rebuild DURING the extended quiet night (05:30 CET, hourly refresh
        //     time): must exit the SAME morning at 07:00, not skip a whole day.
        let fallBackNight = fireDates(now: bat(2026, 10, 25, 5, 30), intervalMinutes: 60, quietStartMinutes: 1320, quietEndMinutes: 420, calendar: berlin)
        check(fallBackNight[0] == bat(2026, 10, 25, 7, 0), "dst-fallback-same-morning-exit")
        check(fallBackNight[1] == bat(2026, 10, 25, 8, 0), "dst-fallback-same-morning-reanchor")

        // 7c. Spring-forward night (2026-03-29, 02:00 → 03:00 CEST, a 23-hour
        //     day): elapsed-minutes math would exit at 08:00 wall clock (an hour
        //     late); must be 07:00.
        check(bat(2026, 3, 30, 0, 0).timeIntervalSince(bat(2026, 3, 29, 0, 0)) == 23 * 3600, "dst-spring-day-is-23h")
        let spring = fireDates(now: bat(2026, 3, 28, 21, 30), intervalMinutes: 60, quietStartMinutes: 1320, quietEndMinutes: 420, calendar: berlin)
        check(spring[0] == bat(2026, 3, 29, 7, 0), "dst-spring-exit-at-wall-clock-7")
        check(spring[1] == bat(2026, 3, 29, 8, 0), "dst-spring-reanchor")

        // 7d. Quiet end 02:30 falls inside the spring-forward gap (02:00-03:00
        //     does not exist that night): exit resolves forward to 03:00 and the
        //     re-check keeps every slot outside the 01:00-02:30 window.
        let gap = fireDates(now: bat(2026, 3, 29, 0, 30), intervalMinutes: 60, quietStartMinutes: 60, quietEndMinutes: 150, calendar: berlin)
        check(gap[0] == bat(2026, 3, 29, 3, 0), "dst-gap-resolves-forward")
        for (i, d) in gap.prefix(8).enumerated() {
            check(!isQuiet(minutesOfDay: berlinMinutesOfDay(d), quietStartMinutes: 60, quietEndMinutes: 150), "dst-gap-none-inside-\(i)")
        }

        print("ENGINE_CHECK_PASS")
    }
}
