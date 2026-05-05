//
//  ContentView.swift
//  nexo
//
//  Created by José Manuel Sánchez Pérez on 04/05/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var appMode     : AppMode = .hogar
    @StateObject private var repo  = ListingsRepository()

    var body: some View {
        TabView(selection: $selectedTab) {
            ScannerView(appMode: $appMode)
                .tabItem { Label("Escanear", systemImage: "viewfinder") }
                .tag(0)

            MapView(listings: repo.listings, isLoading: repo.isLoading)
                .tabItem { Label("Mapa", systemImage: "map.fill") }
                .tag(1)
                .task { await repo.fetchAvailable() }

            HistorialView()
                .tabItem { Label("Historia", systemImage: "clock.arrow.circlepath") }
                .tag(2)
        }
        .tint(Color.nexoGreen)
        .onReceive(NotificationCenter.default.publisher(for: .nexoOpenScanner))   { _ in withAnimation { selectedTab = 0 } }
        .onReceive(NotificationCenter.default.publisher(for: .nexoOpenHistorial)) { _ in withAnimation { selectedTab = 2 } }
        .alert("Error", isPresented: .constant(repo.lastError != nil)) {
            Button("OK") { repo.lastError = nil }
        } message: { Text(repo.lastError ?? "") }
    }
}

#Preview {
    ContentView().modelContainer(for: FichaRegistro.self, inMemory: true)
}
