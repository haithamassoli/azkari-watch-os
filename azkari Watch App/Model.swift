//
//  Model.swift
//  azkari Watch App
//
//  Foundation-only data & settings store. No SwiftUI/Combine imports:
//  later milestones type-check this file standalone for engine self-checks.
//

import Foundation

// MARK: - Dhikr library

struct Dhikr: Identifiable {
    let id: Int
    let text: String

    /// The built-in 12-item library, exactly as in the PRD table.
    static let all: [Dhikr] = [
        Dhikr(id: 1, text: "سبحان الله"),
        Dhikr(id: 2, text: "الحمد لله"),
        Dhikr(id: 3, text: "لا إله إلا الله"),
        Dhikr(id: 4, text: "الله أكبر"),
        Dhikr(id: 5, text: "أستغفر الله"),
        Dhikr(id: 6, text: "سبحان الله وبحمده"),
        Dhikr(id: 7, text: "سبحان الله العظيم"),
        Dhikr(id: 8, text: "لا حول ولا قوة إلا بالله"),
        Dhikr(id: 9, text: "اللهم صلِّ وسلم على نبينا محمد"),
        Dhikr(id: 10, text: "لا إله إلا الله وحده لا شريك له، له الملك وله الحمد، وهو على كل شيء قدير"),
        Dhikr(id: 11, text: "أستغفر الله العظيم وأتوب إليه"),
        Dhikr(id: 12, text: "سبحان الله والحمد لله ولا إله إلا الله والله أكبر"),
    ]
}

// MARK: - Settings

/// Shared UserDefaults keys so SwiftUI can `@AppStorage` the same keys later.
enum SettingsKey {
    static let remindersOn = "remindersOn"
    static let intervalMinutes = "intervalMinutes"
    static let quietStartMinutes = "quietStartMinutes"
    static let quietEndMinutes = "quietEndMinutes"
    static let enabledMask = "enabledMask"
    static let lastDeliveredText = "lastDeliveredText"
}

/// Shared default values, registered via `registerDefaults()`.
enum SettingsDefault {
    static let remindersOn = true
    static let intervalMinutes = 5
    static let quietStartMinutes = 1320 // 22:00
    static let quietEndMinutes = 420    // 07:00
    /// All 12 bits set: bit (id-1) enables dhikr `id`.
    static let enabledMask = (1 << Dhikr.all.count) - 1 // 4095
    static let lastDeliveredText = ""

    /// Allowed interval choices (minutes).
    static let allowedIntervals = [1, 3, 5, 7, 10, 15, 20, 25, 30, 45, 60, 120, 180, 240]
}

/// Registers default values with `UserDefaults.standard`. Called from `azkariApp.init`.
func registerDefaults() {
    UserDefaults.standard.register(defaults: [
        SettingsKey.remindersOn: SettingsDefault.remindersOn,
        SettingsKey.intervalMinutes: SettingsDefault.intervalMinutes,
        SettingsKey.quietStartMinutes: SettingsDefault.quietStartMinutes,
        SettingsKey.quietEndMinutes: SettingsDefault.quietEndMinutes,
        SettingsKey.enabledMask: SettingsDefault.enabledMask,
        SettingsKey.lastDeliveredText: SettingsDefault.lastDeliveredText,
    ])
}

// MARK: - Plain accessors (non-UI reads for the engine/scheduler side)

/// Reads over `UserDefaults.standard`. UI uses `@AppStorage` on the same keys.
enum Settings {
    private static var defaults: UserDefaults { .standard }

    static var remindersOn: Bool {
        get { defaults.bool(forKey: SettingsKey.remindersOn) }
        set { defaults.set(newValue, forKey: SettingsKey.remindersOn) }
    }

    static var intervalMinutes: Int {
        defaults.integer(forKey: SettingsKey.intervalMinutes)
    }

    static var quietStartMinutes: Int {
        defaults.integer(forKey: SettingsKey.quietStartMinutes)
    }

    static var quietEndMinutes: Int {
        defaults.integer(forKey: SettingsKey.quietEndMinutes)
    }

    static var enabledMask: Int {
        defaults.integer(forKey: SettingsKey.enabledMask)
    }

    /// Body of the newest DELIVERED notification ever observed — the dhikr the
    /// user most recently received. Anchors the no-consecutive-repeat rule
    /// (AC-2) across rebuilds. Empty until something has been delivered.
    static var lastDeliveredText: String {
        get { defaults.string(forKey: SettingsKey.lastDeliveredText) ?? "" }
        set { defaults.set(newValue, forKey: SettingsKey.lastDeliveredText) }
    }

    /// Enabled subset of the library, decoded from `enabledMask`.
    /// Defensively falls back to the full library if the mask decodes empty
    /// (the UI additionally blocks emptying the set — AC-8).
    static var enabledDhikr: [Dhikr] {
        let mask = enabledMask
        let enabled = Dhikr.all.filter { mask & (1 << ($0.id - 1)) != 0 }
        return enabled.isEmpty ? Dhikr.all : enabled
    }
}
