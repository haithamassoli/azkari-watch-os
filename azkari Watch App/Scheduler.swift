//
//  Scheduler.swift
//  azkari Watch App
//
//  UserNotifications glue over DhikrEngine. MainActor-isolated via the
//  project's default actor isolation.
//

import Foundation
import UserNotifications

enum Scheduler {
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
        let dates = fireDates(
            now: Date(),
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
        guard !texts.isEmpty else { return }

        for (index, (date, text)) in zip(dates, texts).enumerated() {
            let content = UNMutableNotificationContent()
            content.body = text // no title — body only
            content.sound = nil // default system haptic, no sound
            content.interruptionLevel = .active
            content.threadIdentifier = "dhikr"
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "dhikr-\(index)", content: content, trigger: trigger))
        }
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
        let sorted = pending.sorted { (Int($0.identifier.dropFirst(6)) ?? 0) < (Int($1.identifier.dropFirst(6)) ?? 0) }
        for request in sorted {
            if let date = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() {
                print("PLAN|\(formatter.string(from: date))|\(request.content.body)")
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
