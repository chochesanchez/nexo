import SwiftUI
import SwiftData
import Combine

struct ContentView: View {
    @State private var selectedTab : Int     = 0
    @State private var appMode: AppMode = {
        let saved = UserDefaults.standard.string(forKey: "nexoRole")
        switch saved {
        case "recolector": return .recolector
        case "empresa":    return .empresa
        default:           return .hogar
        }
    }()

    @StateObject private var repo     = ListingsRepository()
    @StateObject private var location = LocationManager.shared

    var body: some View {
        Group {
            switch appMode {
            case .hogar:      hogarTabs
            case .recolector: recolectorTabs
            case .empresa:    empresaTabs
            }
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

    // MARK: - Tabs: Hogar

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

    // MARK: - Tabs: Recolector

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
        .tint(Color.nexoAmber)
    }
    

    // MARK: - Tabs: Empresa

    private var empresaTabs: some View {
        TabView(selection: $selectedTab) {
            EmpresaView()
                .tabItem { Label("Publicar lote", systemImage: "shippingbox") }
                .tag(0)

            MapView(listings: repo.listings.filter { isLoteListing($0) }, isLoading: repo.isLoading)
                .tabItem { Label("Mis lotes", systemImage: "map") }
                .tag(1)
                .task { await repo.fetchAvailable() }

            modoToggleTab
        }
        .tint(Color.nexoBlue)
    }

    // MARK: - Modo toggle tab

    private var modoToggleTab: some View {
        ModoSelectorView(appMode: $appMode)
            .tabItem { Label("Cambiar modo", systemImage: "arrow.2.squarepath") }
            .tag(99)
    }

    private func isLoteListing(_ listing: Listing) -> Bool {
        listing.notes?.contains("Tipo:") ?? false
    }
}

// MARK: - ModoSelectorView

struct ModoSelectorView: View {
    @Binding var appMode: AppMode

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Modo")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.nexoBrand.opacity(0.5))
                    Text("¿Cómo usas\nNEXO ahora?")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-2)
                        .foregroundStyle(Color.nexoForest)
                        .lineSpacing(2)
                }
                .padding(.top, 48)
                .padding(.horizontal, Sp.lg)
                .padding(.bottom, 32)

                Rectangle()
                    .fill(Color.nexoForest.opacity(0.07))
                    .frame(height: 0.5)

                VStack(spacing: 0) {
                    modoRow(mode: .hogar,      icon: "house",      desc: "Escanea, prepara y comparte residuos",          isOn: appMode == .hogar)
                    Rectangle().fill(Color.nexoForest.opacity(0.07)).frame(height: 0.5)
                    modoRow(mode: .recolector, icon: "figure.walk", desc: "Encuentra materiales en tu ruta",              isOn: appMode == .recolector)
                    Rectangle().fill(Color.nexoForest.opacity(0.07)).frame(height: 0.5)
                    modoRowEmpresa(isOn: appMode == .empresa)
                    Rectangle().fill(Color.nexoForest.opacity(0.07)).frame(height: 0.5)
                }

                Spacer()

                Text("El cambio aplica inmediatamente.")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .padding(.horizontal, Sp.lg)
                    .padding(.bottom, 32)
            }
        }
    }

    private func modoRow(mode: AppMode, icon: String, desc: String, isOn: Bool) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { appMode = mode }
            saveMode(mode)
        } label: {
            HStack(spacing: Sp.md) {
                Image(systemName: isOn ? icon + ".fill" : icon)
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(isOn ? Color.nexoForest : Color(uiColor: .tertiaryLabel))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.rawValue)
                        .font(.system(size: 16, weight: isOn ? .semibold : .regular))
                        .foregroundStyle(isOn ? Color.nexoForest : Color(uiColor: .secondaryLabel))
                    Text(desc)
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                }

                Spacer()

                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.nexoForest)
                }
            }
            .padding(.horizontal, Sp.lg)
            .padding(.vertical, 18)
            .background(isOn ? Color.nexoForest.opacity(0.04) : Color.clear)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cambiar a \(mode.rawValue)")
    }

    private func modoRowEmpresa(isOn: Bool) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { appMode = .empresa }
            saveMode(.empresa)
        } label: {
            HStack(spacing: Sp.md) {
                Image(systemName: isOn ? "building.2.fill" : "building.2")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(isOn ? Color.nexoForest : Color(uiColor: .tertiaryLabel))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Empresa")
                            .font(.system(size: 16, weight: isOn ? .semibold : .regular))
                            .foregroundStyle(isOn ? Color.nexoForest : Color(uiColor: .secondaryLabel))

                        Text("2.5× impacto")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.3)
                            .foregroundStyle(Color.nexoBrand)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.nexoBrand.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                    }
                    Text("Publica lotes para gestores certificados")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                }

                Spacer()

                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.nexoForest)
                }
            }
            .padding(.horizontal, Sp.lg)
            .padding(.vertical, 18)
            .background(isOn ? Color.nexoForest.opacity(0.04) : Color.clear)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cambiar a Modo Empresa")
    }

    private func saveMode(_ mode: AppMode) {
        switch mode {
        case .hogar:      UserDefaults.standard.set("hogar",      forKey: "nexoRole")
        case .recolector: UserDefaults.standard.set("recolector", forKey: "nexoRole")
        case .empresa:    UserDefaults.standard.set("empresa",    forKey: "nexoRole")
        }
    }
}

#Preview {
    ContentView().modelContainer(for: FichaRegistro.self, inMemory: true)
}
