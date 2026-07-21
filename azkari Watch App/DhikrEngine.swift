//
//  DhikrEngine.swift
//  azkari Watch App
//
//  Pure scheduling logic. Foundation only — no UserNotifications/SwiftUI —
//  so scripts/engine_check.swift can compile this file standalone.
//

import Foundation

/// True when `m` (local minutes-of-day, 0...1439) falls inside the quiet window.
/// Non-wrapping window (start < end): quiet is `start <= m < end`.
/// Wrapping window (start > end): quiet is `m >= start || m < end`.
/// `start == end`: no quiet window.
/// Boundaries: exactly at quiet start is inside; exactly at quiet end is outside.
func isQuiet(minutesOfDay m: Int, quietStartMinutes start: Int, quietEndMinutes end: Int) -> Bool {
    if start == end { return false }
    if start < end { return m >= start && m < end }
    return m >= start || m < end
}

/// Successive local-wall-clock fire times: first fire = `now` + interval, then
/// `interval` cadence. A fire falling inside the quiet window jumps to the quiet
/// window end (same or next day, whichever comes next) and the cadence continues
/// from that new anchor. At most `cap` dates (64 = system pending-request limit).
func fireDates(now: Date, intervalMinutes: Int, quietStartMinutes: Int, quietEndMinutes: Int, calendar: Calendar, cap: Int = 64) -> [Date] {
    guard intervalMinutes > 0, cap > 0 else { return [] }
    var dates: [Date] = []
    dates.reserveCapacity(cap)
    var t = addingMinutes(intervalMinutes, to: now, calendar: calendar)
    while dates.count < cap {
        while isQuiet(minutesOfDay: minutesOfDay(of: t, calendar: calendar), quietStartMinutes: quietStartMinutes, quietEndMinutes: quietEndMinutes) {
            t = quietWindowExit(from: t, quietEndMinutes: quietEndMinutes, calendar: calendar)
        }
        dates.append(t)
        t = addingMinutes(intervalMinutes, to: t, calendar: calendar)
    }
    return dates
}

/// Uniformly random texts from `pool`, one per slot. No two consecutive picks are
/// equal, and the first pick also differs from `avoidingFirst` — both rules apply
/// only while the pool holds 2+ distinct texts (a single choice repeats freely).
func pickTexts<R: RandomNumberGenerator>(count: Int, from pool: [String], avoidingFirst: String?, using rng: inout R) -> [String] {
    guard count > 0, !pool.isEmpty else { return [] }
    let canAvoidRepeats = Set(pool).count >= 2
    var picks: [String] = []
    picks.reserveCapacity(count)
    var previous = avoidingFirst
    for _ in 0..<count {
        var choice = pool.randomElement(using: &rng)!
        while canAvoidRepeats && choice == previous {
            choice = pool.randomElement(using: &rng)!
        }
        picks.append(choice)
        previous = choice
    }
    return picks
}

// MARK: - Helpers

private func minutesOfDay(of t: Date, calendar: Calendar) -> Int {
    calendar.component(.hour, from: t) * 60 + calendar.component(.minute, from: t)
}

/// First moment strictly after `t` whose local WALL CLOCK reads exactly
/// `quietEndMinutes`. Matching wall-clock hour/minute (not elapsed minutes from
/// midnight) keeps the exit correct across DST transitions; a quiet end inside
/// a spring-forward gap resolves to the next existing instant (`.nextTime`),
/// which is why callers re-check the quiet window after jumping.
private func quietWindowExit(from t: Date, quietEndMinutes: Int, calendar: Calendar) -> Date {
    calendar.nextDate(
        after: t,
        matching: DateComponents(hour: quietEndMinutes / 60, minute: quietEndMinutes % 60),
        matchingPolicy: .nextTime
    ) ?? t.addingTimeInterval(60) // never nil for gregorian; if it ever is, still advance so caller loops terminate
}

private func addingMinutes(_ minutes: Int, to t: Date, calendar: Calendar) -> Date {
    calendar.date(byAdding: .minute, value: minutes, to: t) ?? t.addingTimeInterval(TimeInterval(minutes) * 60)
}
