//
//  azkariApp.swift
//  azkari Watch App
//
//  Created by Goldentik on 21/07/2026.
//

import SwiftUI
import UserNotifications

@main
struct azkari_Watch_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    /// UNUserNotificationCenter.delegate is weak — the App instance keeps it alive.
    private let notificationDelegate = NotificationDelegate()

    init() {
        registerDefaults()
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
        }
        // Every activation (launch included): re-check permission, clear
        // delivered residue, rebuild the queue, re-arm the refresh chain
        // (AC-4, AC-6).
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await Scheduler.activate() }
        }
        // Hourly-preferred refresh chain link. Bare .appRefresh on watchOS
        // passes the scheduled userInfo as String? directly — unused here.
        .backgroundTask(.appRefresh) { _ in
            await Scheduler.backgroundRefresh()
        }
    }
}

/// A reminder landing while the app is open still shows as a banner.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner]
    }
}
