//
//  Scheduler.swift
//  azkari Watch App
//
//  UserNotifications + lifecycle glue over DhikrEngine. MainActor-isolated via
//  the project's default actor isolation.
//

import Foundation
import UserNotifications
import WatchKit

enum Scheduler {
    /// Runs on every scene activation (AC-4, AC-6): flip the master toggle off
    /// if permission was revoked (M5 Home shows the hint state), clear
    /// delivered residue + reschedule, and re-arm the refresh chain.
    static func activate() async {
        #if DEBUG
        if await handleDebugLaunchArguments() { return }
        #endif
        if await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied {
            Settings.remindersOn = false
        }
        await rebuild()
        scheduleNextRefresh()
    }

    /// Background-refresh handler body: rebuild (clears residue roughly hourly,
    /// keeps the queue full and DST-correct), then re-arm the chain.
    static func backgroundRefresh() async {
        await rebuild()
        scheduleNextRefresh()
    }

    /// Arms the next link of the refresh chain, preferred one hour out. No-op
    /// once reminders are off — that (plus rebuild clearing the queue) is the
    /// whole pause path; an already-armed link fires once, rebuilds to an empty
    /// queue, and does not re-arm.
    static func scheduleNextRefresh() {
        guard Settings.remindersOn else { return }
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: .now + 3600,
            userInfo: nil
        ) { _ in } // best effort — a dropped link re-arms on next activation
    }

    /// Clears everything, then — only while reminders are on and notifications
    /// are authorized — schedules a fresh queue from the current settings.
    static func rebuild() async {
        let center = UNUserNotificationCenter.current()
        // AC-2 anchor = the dhikr the user most recently RECEIVED. It lives in
        // the delivered list, so capture it before the wipe below discards it;
        // when nothing is delivered (nothing fired since the last capture),
        // the anchor persisted by an earlier rebuild stands.
        if let newest = await center.deliveredNotifications().max(by: { $0.date < $1.date }) {
            Settings.lastDeliveredText = newest.request.content.body
        }
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()

        guard Settings.remindersOn else { return }
        guard await center.notificationSettings().authorizationStatus == .authorized else { return }

        let calendar = Calendar.current
        for (index, slot) in plan(calendar: calendar).enumerated() {
            let content = UNMutableNotificationContent()
            content.body = slot.text // no title — body only
            content.sound = nil // default system haptic, no sound
            content.interruptionLevel = .active
            content.threadIdentifier = "dhikr"
            content.categoryIdentifier = "dhikr" // routes to the custom long look
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: slot.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "dhikr-\(index)", content: content, trigger: trigger))
        }
    }

    /// The queue the current settings produce — fire dates paired with texts.
    /// Pure of notification-center state, so the debug dump can print the plan
    /// even when authorization blocks actual scheduling.
    static func plan(now: Date = Date(), calendar: Calendar = .current) -> [(date: Date, text: String)] {
        let dates = fireDates(
            now: now,
            intervalMinutes: Settings.intervalMinutes,
            quietStartMinutes: Settings.quietStartMinutes,
            quietEndMinutes: Settings.quietEndMinutes,
            calendar: calendar
        )
        var rng = SystemRandomNumberGenerator()
        let texts = pickTexts(
            count: dates.count,
            from: Settings.enabledDhikr.map(\.text),
            avoidingFirst: Settings.lastDeliveredText,
            using: &rng
        )
        return zip(dates, texts).map { (date: $0, text: $1) }
    }

    static func requestAuth() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])) ?? false
    }
}

#if DEBUG
extension Scheduler {
    /// Headless-test hook, called on app startup.
    /// Applies repeated "-set <userDefaultsKey> <value>" launch args first, then —
    /// if "-dumpQueue" is present — prints persisted state (AUTH|, PENDING|),
    /// runs rebuild, prints the resulting queue (PLAN| lines, PENDING2|) and
    /// exits so the captured console output is bounded.
    /// Returns true when it handled the dump (callers must skip their own rebuild).
    static func handleDebugLaunchArguments() async -> Bool {
        let args = ProcessInfo.processInfo.arguments
        var i = 0
        while i < args.count {
            if args[i] == "-set", i + 2 < args.count {
                applyDebugSetting(key: args[i + 1], value: args[i + 2])
                i += 3
            } else {
                i += 1
            }
        }
        guard args.contains("-dumpQueue") else { return false }

        let center = UNUserNotificationCenter.current()
        let auth = await center.notificationSettings().authorizationStatus
        print("AUTH|\(auth.rawValue)")
        print("PENDING|\(await center.pendingNotificationRequests().count)")

        await rebuild()

        let pending = await center.pendingNotificationRequests()
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        if pending.isEmpty, Settings.remindersOn {
            // Unauthorized (simulator can't auto-grant the permission sheet):
            // rebuild scheduled nothing, so print the computed plan instead.
            for slot in plan() {
                print("PLAN|\(formatter.string(from: slot.date))|\(slot.text)")
            }
        } else {
            let sorted = pending.sorted { (Int($0.identifier.dropFirst(6)) ?? 0) < (Int($1.identifier.dropFirst(6)) ?? 0) }
            for request in sorted {
                if let date = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() {
                    print("PLAN|\(formatter.string(from: date))|\(request.content.body)")
                }
            }
        }
        print("PENDING2|\(pending.count)")
        UserDefaults.standard.synchronize() // flush -set writes before the hard exit
        exit(0)
    }

    /// Bool/Int/String typing chosen by key, matching the settings schema.
    private static func applyDebugSetting(key: String, value: String) {
        let defaults = UserDefaults.standard
        switch key {
        case SettingsKey.remindersOn:
            defaults.set((value as NSString).boolValue, forKey: key)
        case SettingsKey.intervalMinutes, SettingsKey.quietStartMinutes, SettingsKey.quietEndMinutes, SettingsKey.enabledMask:
            defaults.set(Int(value) ?? 0, forKey: key)
        default:
            defaults.set(value, forKey: key)
        }
    }
}
#endif
