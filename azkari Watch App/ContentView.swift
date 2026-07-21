//
//  ContentView.swift
//  azkari Watch App
//
//  Created by Goldentik on 21/07/2026.
//
//  Temporary RTL smoke screen for M1 — M5 replaces this with the real UI.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ScrollView {
            Text("لا إله إلا الله وحده لا شريك له، له الملك وله الحمد، وهو على كل شيء قدير")
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding()
        }
    }
}

#Preview {
    ContentView()
}
