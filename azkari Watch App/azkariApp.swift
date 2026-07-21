//
//  azkariApp.swift
//  azkari Watch App
//
//  Created by Goldentik on 21/07/2026.
//

import SwiftUI

@main
struct azkari_Watch_AppApp: App {
    init() {
        registerDefaults()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
        }
    }
}
