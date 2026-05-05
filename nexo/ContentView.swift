//
//  ContentView.swift
//  nexo
//
//  Created by José Manuel Sánchez Pérez on 04/05/26.
// ContentView.swift — Rediseño Bateman/Apple
// ContentView.swift — Light mode, ModoSelectorView con cerrar sesión restaurado
import SwiftUI
import SwiftData
import Combine

struct ContentView: View {
    @State private var selectedTab: Int = 0
    @State private var appMode: AppMode = {
        let saved = UserDefaults.standard.string(forKey: "nexoRole")
        return saved == "recolector" ? .recolector : .hogar
    }()

    @StateObject private var repo     = ListingsRepository()
    @StateObject private var location = LocationManager.shared

    var body: some View {
        Group {
            if appMode == .hogar { hogarTabs }
            else                 { recolectorTabs }
        }
        .environmentObject(repo)
        .environmentObject(location)
        .onAppear { location.startUpdating() }
        .onReceive(NotificationCenter.default.publisher(for: .nexoOpenScanner)) { _ in
            appMode = .hogar; withAnimation { selectedTab = 0 }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nexoOpenHistorial)) { _ in
            appMode = .hogar; withAnimation { selectedTab = 2 }
        }
        .alert("Error", isPresented: .constant(repo.lastError != nil)) {
            Button("OK") { repo.lastError = nil }
        } message: { Text(repo.lastError ?? "") }
    }

    private var hogarTabs: some View {
        TabView(selection: $selectedTab) {
            ScannerView(appMode: $appMode)
                .tabItem { Label("Escanear", systemImage: "viewfinder") }
                .tag(0)

            MapView(listings: repo.listings, isLoading: repo.isLoading)
                .tabItem { Label("Mapa", systemImage: "map") }
                .tag(1)
                .task { await repo.fetchAvailable() }

            HistorialView()
                .tabItem { Label("Historial", systemImage: "clock") }
                .tag(2)

            modoToggleTab
        }
        .tint(Color.nexoBrand)
    }

    private var recolectorTabs: some View {
        TabView(selection: $selectedTab) {
            RecolectorView(listings: repo.listings, isLoading: repo.isLoading)
                .tabItem { Label("Fichas", systemImage: "map") }
                .tag(0)
                .task { await repo.fetchAvailable() }

            HistorialRecolectorView()
                .tabItem { Label("Historial", systemImage: "clock") }
                .tag(1)

            modoToggleTab
        }
        .tint(Color.nexoBrand)
    }
    

    private var modoToggleTab: some View {
        ModoSelectorView(appMode: $appMode)
            .tabItem {
                Label(
                    appMode == .hogar ? "Ajustes" : "Ajustes",
                    systemImage: "gearshape"
                )
            }
            .tag(99)
    }
}

// MARK: - ModoSelectorView — light mode Apple Settings style + cerrar sesión
struct ModoSelectorView: View {
    @Binding var appMode: AppMode
    @EnvironmentObject private var auth: AuthService

    var body: some View {
        NavigationStack {
            List {
                // MARK: Modo actual
                Section {
                    modoRow(
                        mode : .hogar,
                        icon : "house.fill",
                        color: Color.nexoBrand,
                        desc : "Escaneo, fichas e historial de impacto"
                    )
                    modoRow(
                        mode : .recolector,
                        icon : "figure.walk",
                        color: Color.nexoBrand,
                        desc : "Mapa de fichas, voz y confirmación de recolección"
                    )
                } header: {
                    Text("Modo de uso")
                }

                // MARK: Cuenta
                Section {
                    // Info de usuario si está disponible
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.nexoMint)
                                .frame(width: 40, height: 40)
                            Image(systemName: "person")
                                .font(.system(size: 16, weight: .light))
                                .foregroundStyle(Color.nexoBrand)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mi cuenta")
                                .font(.system(size: 15, weight: .medium))
                            Text(auth.currentUserId != nil ? "Sesión activa" : "No has iniciado sesión")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Cuenta")
                }

                // MARK: Cerrar sesión — restaurado
                Section {
                    Button(role: .destructive) {
                        Task { await auth.signOut() }
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .frame(width: 20)
                            Text("Cerrar sesión")
                        }
                        .font(.system(size: 15, weight: .regular))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("NEXO")
            .navigationBarTitleDisplayMode(.large)
            .tint(Color.nexoBrand)
        }
    }

    private func modoRow(mode: AppMode, icon: String, color: Color, desc: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { appMode = mode }
            UserDefaults.standard.set(mode == .hogar ? "hogar" : "recolector", forKey: "nexoRole")
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(appMode == mode ? Color.nexoMint : Color(uiColor: .systemGray6))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(appMode == mode ? Color.nexoBrand : Color(uiColor: .secondaryLabel))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.rawValue)
                        .font(.system(size: 15, weight: appMode == mode ? .semibold : .regular))
                        .foregroundStyle(Color(uiColor: .label))
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }

                Spacer()

                if appMode == mode {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.nexoBrand)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView().modelContainer(for: FichaRegistro.self, inMemory: true)
}
