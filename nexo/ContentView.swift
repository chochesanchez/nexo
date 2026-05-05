//
//  ContentView.swift
//  nexo
//
//  Created by José Manuel Sánchez Pérez on 04/05/26.
// ContentView.swift
// Cambios vs versión anterior:
// 1. LocationManager y ListingsRepository son @EnvironmentObject disponibles globalmente.
// 2. El TabView cambia según appMode: Modo Hogar = Escanear+Historial / Modo Recolector = Mapa optimizado.
// 3. En Modo Recolector el mapa carga fichas automáticamente.

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab : Int     = 0
    @State private var appMode     : AppMode = .hogar

    @StateObject private var repo     = ListingsRepository()
    @StateObject private var location = LocationManager.shared

    var body: some View {
        Group {
            if appMode == .hogar {
                hogarTabs
            } else {
                recolectorTabs
            }
        }
        .environmentObject(repo)
        .environmentObject(location)
        .onAppear { location.startUpdating() }
        .onReceive(NotificationCenter.default.publisher(for: .nexoOpenScanner))   { _ in
            appMode = .hogar; withAnimation { selectedTab = 0 }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nexoOpenHistorial)) { _ in
            appMode = .hogar; withAnimation { selectedTab = 2 }
        }
        .alert("Error", isPresented: .constant(repo.lastError != nil)) {
            Button("OK") { repo.lastError = nil }
        } message: { Text(repo.lastError ?? "") }
    }

    // MARK: - Tabs Modo Hogar

    private var hogarTabs: some View {
        TabView(selection: $selectedTab) {
            ScannerView(appMode: $appMode)
                .tabItem { Label("Escanear", systemImage: "viewfinder") }
                .tag(0)

            MapView(listings: repo.listings, isLoading: repo.isLoading)
                .tabItem { Label("Mapa", systemImage: "map.fill") }
                .tag(1)
                .task { await repo.fetchAvailable() }

            HistorialView()
                .tabItem { Label("Historial", systemImage: "clock.arrow.circlepath") }
                .tag(2)

            modoToggleTab
        }
        .tint(Color.nexoGreen)
    }

    // MARK: - Tabs Modo Recolector

    private var recolectorTabs: some View {
        TabView(selection: $selectedTab) {
            RecolectorView(listings: repo.listings, isLoading: repo.isLoading)
                .tabItem { Label("Fichas", systemImage: "map.fill") }
                .tag(0)
                .task { await repo.fetchAvailable() }

            modoToggleTab
        }
        .tint(Color.nexoAmber)
    }

    // MARK: - Tab de cambio de modo

    private var modoToggleTab: some View {
        ModoSelectorView(appMode: $appMode)
            .tabItem {
                Label(
                    appMode == .hogar ? "Modo Recolector" : "Modo Hogar",
                    systemImage: appMode == .hogar ? "person.crop.circle.fill" : "house.fill"
                )
            }
            .tag(99)
    }
}

// MARK: - Pantalla de selección de modo

struct ModoSelectorView: View {
    @Binding var appMode: AppMode

    var body: some View {
        VStack(spacing: Sp.xl) {
            Spacer()
            Text("¿Cómo usas NEXO?")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            VStack(spacing: Sp.md) {
                modoCard(
                    mode  : .hogar,
                    icon  : "house.fill",
                    color : Color.nexoGreen,
                    desc  : "Escaneo, fichas e historial de impacto"
                )
                modoCard(
                    mode  : .recolector,
                    icon  : "person.crop.circle.fill",
                    color : Color.nexoAmber,
                    desc  : "Mapa de fichas, voz y confirmación de recolección"
                )
            }
            .padding(.horizontal, Sp.lg)
            Spacer()
        }
    }

    private func modoCard(mode: AppMode, icon: String,
                          color: Color, desc: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { appMode = mode }
        } label: {
            HStack(spacing: Sp.md) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 52, height: 52)
                    Image(systemName: icon).font(.system(size: 22)).foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.rawValue).font(.system(size: 17, weight: .bold))
                    Text(desc).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                if appMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(color).font(.system(size: 20))
                }
            }
            .padding(Sp.md)
            .background(
                appMode == mode ? color.opacity(0.08) : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: Rd.md)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Rd.md)
                    .strokeBorder(appMode == mode ? color : .clear, lineWidth: 1.5)
            )
        }
        .foregroundStyle(.primary)
        .accessibilityLabel("Cambiar a \(mode.rawValue)")
    }
}

#Preview {
    ContentView().modelContainer(for: FichaRegistro.self, inMemory: true)
}
