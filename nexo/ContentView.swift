//
//  ContentView.swift
//  nexo
//
//  Created by José Manuel Sánchez Pérez on 04/05/26.
// ContentView.swift — Rediseño Bateman/Apple
import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab : Int     = 0
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
        .tint(Color.nexoBlack)
    }

    private var recolectorTabs: some View {
        TabView(selection: $selectedTab) {
            RecolectorView(listings: repo.listings, isLoading: repo.isLoading)
                .tabItem { Label("Fichas", systemImage: "map") }
                .tag(0)
                .task { await repo.fetchAvailable() }

            modoToggleTab
        }
        .tint(Color.nexoAmber)
    }

    private var modoToggleTab: some View {
        ModoSelectorView(appMode: $appMode)
            .tabItem {
                Label(
                    appMode == .hogar ? "Recolector" : "Hogar",
                    systemImage: appMode == .hogar ? "figure.walk" : "house"
                )
            }
            .tag(99)
    }
}

// MARK: - Selector de modo — rediseñado
struct ModoSelectorView: View {
    @Binding var appMode: AppMode

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Modo")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(2.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.secondary)
                    Text("¿Cómo usas\nNEXO ahora?")
                        .font(.system(size: 32, weight: .black))
                        .tracking(-2)
                        .lineSpacing(2)
                }
                .padding(.top, 48)
                .padding(.horizontal, Sp.lg)
                .padding(.bottom, 32)

                // Regla
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 0.5)

                // Opciones
                VStack(spacing: 0) {
                    modoRow(
                        mode : .hogar,
                        icon : "house",
                        desc : "Escanea, prepara y comparte residuos",
                        isOn : appMode == .hogar
                    )
                    Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 0.5)
                    modoRow(
                        mode : .recolector,
                        icon : "figure.walk",
                        desc : "Encuentra materiales en tu ruta",
                        isOn : appMode == .recolector
                    )
                    Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 0.5)
                }

                Spacer()

                // Nota
                Text("El cambio aplica inmediatamente.")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, Sp.lg)
                    .padding(.bottom, 32)
            }
        }
    }

    private func modoRow(mode: AppMode, icon: String, desc: String, isOn: Bool) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { appMode = mode }
            UserDefaults.standard.set(mode == .hogar ? "hogar" : "recolector", forKey: "nexoRole")
        } label: {
            HStack(spacing: Sp.md) {
                Image(systemName: isOn ? icon + ".fill" : icon)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(isOn ? Color.primary : Color.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.rawValue)
                        .font(.system(size: 16, weight: isOn ? .semibold : .regular))
                        .foregroundStyle(isOn ? Color.primary : Color.secondary)
                    Text(desc)
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.primary)
                }
            }
            .padding(.horizontal, Sp.lg)
            .padding(.vertical, 18)
            .background(isOn ? Color.primary.opacity(0.03) : Color.clear)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cambiar a \(mode.rawValue)")
    }
}

#Preview {
    ContentView().modelContainer(for: FichaRegistro.self, inMemory: true)
}
