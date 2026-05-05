// ContentView.swift — Modo Empresa con tab de Historial

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab : Int = 0
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
        ZStack {
            switch appMode {
            case .hogar:      hogarTabs.transition(.opacity)
            case .recolector: recolectorTabs.transition(.opacity)
            case .empresa:    empresaTabs.transition(.opacity)
            }
        }
        .environmentObject(repo)
        .environmentObject(location)
        .onAppear { location.startUpdating() }
        .onReceive(NotificationCenter.default.publisher(for: .nexoOpenScanner)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) { appMode = .hogar; selectedTab = 0 }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nexoOpenHistorial)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) { appMode = .hogar; selectedTab = 2 }
        }
        .alert("Error", isPresented: .constant(repo.lastError != nil)) {
            Button("OK") { repo.lastError = nil }
        } message: { Text(repo.lastError ?? "") }
    }

    // MARK: - Hogar

    private var hogarTabs: some View {
        TabView(selection: $selectedTab) {
            ScannerView(appMode: $appMode)
                .tabItem { Label("Escanear", systemImage: "viewfinder") }.tag(0)

            MapView(listings: repo.listings, isLoading: repo.isLoading)
                .tabItem { Label("Mapa", systemImage: "map") }.tag(1)
                .task { await repo.fetchAvailable() }

            HistorialView()
                .tabItem { Label("Historial", systemImage: "clock") }.tag(2)

            modoToggleTab
        }
        .tint(Color.nexoBlack)
    }

    // MARK: - Recolector

    private var recolectorTabs: some View {
        TabView(selection: $selectedTab) {
            RecolectorView(listings: repo.listings, isLoading: repo.isLoading)
                .tabItem { Label("Fichas", systemImage: "map") }.tag(0)
                .task { await repo.fetchAvailable() }

            modoToggleTab
        }
        .tint(Color.nexoAmber)
    }

    // MARK: - Empresa (3 tabs: Publicar · Historial · Mapa)

    private var empresaTabs: some View {
        TabView(selection: $selectedTab) {
            EmpresaView()
                .tabItem { Label("Publicar lote", systemImage: "shippingbox") }.tag(0)

            HistorialEmpresaView()
                .tabItem { Label("Mis lotes", systemImage: "clock") }.tag(1)

            MapView(
                listings: repo.listings.filter { $0.notes?.contains("Tipo:") ?? false },
                isLoading: repo.isLoading
            )
            .tabItem { Label("Mapa", systemImage: "map") }.tag(2)
            .task { await repo.fetchAvailable() }

            modoToggleTab
        }
        .tint(Color.nexoForest)
    }

    // MARK: - Modo toggle tab

    private var modoToggleTab: some View {
        ModoSelectorView(appMode: $appMode)
            .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
            .tag(99)
    }
}

// MARK: - ModoSelectorView

struct ModoSelectorView: View {
    @Binding var appMode: AppMode
    @EnvironmentObject private var auth: AuthService
    @Query(sort: \FichaRegistro.fecha, order: .reverse) private var fichas: [FichaRegistro]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                profileHeader
                impactStatsSection
                verImpactoButton
                modeSelectorSection
                signOutSection
                Color.clear.frame(height: 24)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    }

    private var profileHeader: some View {
        HStack(spacing: 16) {
            avatarView
            VStack(alignment: .leading, spacing: 4) {
                Text(fullName)
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(Color.nexoForest)
                Text(auth.correo ?? "Correo no disponible")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .lineLimit(1)
                Text(auth.telefono?.isEmpty == false ? auth.telefono! : "Sin teléfono")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
            Spacer()
        }
        .padding(20)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.lg))
        .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
        .padding(.horizontal, Sp.lg)
        .padding(.top, 56)
    }

    @ViewBuilder
    private var avatarView: some View {
        if let urlStr = auth.avatarURL, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .empty:
                    ProgressView().tint(Color.nexoBrand)
                case .failure:
                    initialsCircle
                @unknown default:
                    initialsCircle
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.nexoForest.opacity(0.12), lineWidth: 1))
        } else {
            initialsCircle
        }
    }

    private var initialsCircle: some View {
        ZStack {
            Circle()
                .fill(Color.nexoMint)
                .frame(width: 72, height: 72)
            if !initials.isEmpty {
                Text(initials)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.nexoBrand)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Color.nexoBrand)
            }
        }
    }

    private var initials: String {
        let n = (auth.nombre?.first).map { String($0) } ?? ""
        let a = (auth.apellido?.first).map { String($0) } ?? ""
        return (n + a).uppercased()
    }

    private var fullName: String {
        let n = auth.nombre?.trimmingCharacters(in: .whitespaces) ?? ""
        let a = auth.apellido?.trimmingCharacters(in: .whitespaces) ?? ""
        let combined = "\(n) \(a)".trimmingCharacters(in: .whitespaces)
        return combined.isEmpty ? "Mi cuenta" : combined
    }

    @ViewBuilder
    private var impactStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mi impacto")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .padding(.horizontal, Sp.lg)

            if fichas.isEmpty {
                emptyStatsCard
                    .padding(.horizontal, Sp.lg)
            } else {
                HStack(spacing: 10) {
                    statCard(
                        icon: "viewfinder",
                        label: "Escaneos",
                        value: "\(fichas.count)",
                        color: Color.nexoForest
                    )
                    statCard(
                        icon: "wind",
                        label: "CO₂ evitado",
                        value: co2Total,
                        color: Color.nexoBrand
                    )
                    statCard(
                        icon: "drop.fill",
                        label: "Agua",
                        value: aguaTotal,
                        color: Color.nexoBlue
                    )
                }
                .padding(.horizontal, Sp.lg)
            }
        }
    }

    private func statCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(Color(uiColor: .label))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.md))
        .overlay(RoundedRectangle(cornerRadius: Rd.md).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
    }

    private var emptyStatsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "viewfinder")
                .font(.system(size: 24, weight: .ultraLight))
                .foregroundStyle(Color.nexoForest.opacity(0.5))
            Text("Aún no tienes escaneos")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(uiColor: .label))
            Text("Escanea tu primer residuo para ver tu impacto.")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .lineSpacing(2)
            Button {
                NotificationCenter.default.post(name: .nexoOpenScanner, object: nil)
            } label: {
                Text("Ir a escanear")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.nexoBrand)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.lg))
        .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
    }

    private var co2Total: String {
        let total = fichas.compactMap { reg -> Double? in
            let digits = reg.co2.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            return Double(digits)
        }.reduce(0, +)
        if total <= 0 { return "—" }
        return total >= 1000 ? String(format: "%.1f kg", total / 1000) : "\(Int(total)) g"
    }

    private var aguaTotal: String {
        let total = fichas.compactMap { reg -> Double? in
            guard reg.water != "—" else { return nil }
            let digits = reg.water.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            return Double(digits)
        }.reduce(0, +)
        if total <= 0 { return "—" }
        return total >= 1000 ? String(format: "%.1f L", total / 1000) : "\(Int(total)) ml"
    }

    private var verImpactoButton: some View {
        Button {
            NotificationCenter.default.post(name: .nexoOpenHistorial, object: nil)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.nexoForest.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.nexoForest)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ver mi impacto")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .label))
                    Text("Historial completo de escaneos")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
            .padding(14)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.lg))
            .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Sp.lg)
    }

    private var modeSelectorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Modo de uso de NEXO")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                Text("Elige cómo quieres usar la app. Puedes cambiarlo cuando quieras.")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .padding(.bottom, 4)
            }
            .padding(.horizontal, Sp.lg)

            VStack(spacing: 0) {
                modoRow(mode: .hogar,      icon: "house",       desc: "Escanea, prepara y comparte residuos", isOn: appMode == .hogar)
                Rectangle().fill(Color.nexoForest.opacity(0.07)).frame(height: 0.5)
                modoRow(mode: .recolector, icon: "figure.walk", desc: "Encuentra materiales en tu ruta",      isOn: appMode == .recolector)
                Rectangle().fill(Color.nexoForest.opacity(0.07)).frame(height: 0.5)
                modoRowEmpresa(isOn: appMode == .empresa)
            }
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.lg))
            .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
            .padding(.horizontal, Sp.lg)
        }
    }

    private var signOutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cuenta")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .padding(.horizontal, Sp.lg)

            Button(role: .destructive) {
                Task { await auth.signOut() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.red)
                        .frame(width: 24)
                    Text("Cerrar sesión")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal, Sp.lg)
                .padding(.vertical, 16)
                .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.lg))
                .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Sp.lg)
        }
    }

    private func modoRow(mode: AppMode, icon: String, desc: String, isOn: Bool) -> some View {
        Button {
            saveMode(mode)
            withAnimation(.easeInOut(duration: 0.25)) { appMode = mode }
        } label: {
            HStack(spacing: Sp.md) {
                Image(systemName: isOn ? icon + ".fill" : icon)
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(isOn ? Color.nexoForest : Color(uiColor: .tertiaryLabel))
                    .frame(width: 24).animation(.easeOut(duration: 0.2), value: isOn)
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.rawValue).font(.system(size: 16, weight: isOn ? .semibold : .regular))
                        .foregroundStyle(isOn ? Color.nexoForest : Color(uiColor: .secondaryLabel))
                    Text(desc).font(.system(size: 12, weight: .light)).foregroundStyle(Color(uiColor: .tertiaryLabel))
                }
                Spacer()
                if isOn {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.nexoForest).transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Sp.lg).padding(.vertical, 18)
            .background(isOn ? Color.nexoForest.opacity(0.04) : Color.clear)
            .animation(.easeOut(duration: 0.2), value: isOn)
        }
        .buttonStyle(.plain)
    }

    private func modoRowEmpresa(isOn: Bool) -> some View {
        Button {
            saveMode(.empresa)
            withAnimation(.easeInOut(duration: 0.25)) { appMode = .empresa }
        } label: {
            HStack(spacing: Sp.md) {
                Image(systemName: isOn ? "building.2.fill" : "building.2")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(isOn ? Color.nexoForest : Color(uiColor: .tertiaryLabel))
                    .frame(width: 24).animation(.easeOut(duration: 0.2), value: isOn)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Empresa").font(.system(size: 16, weight: isOn ? .semibold : .regular))
                            .foregroundStyle(isOn ? Color.nexoForest : Color(uiColor: .secondaryLabel))
                        Text("2.5× impacto").font(.system(size: 9, weight: .bold)).tracking(0.3)
                            .foregroundStyle(Color.nexoBrand).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.nexoBrand.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                    }
                    Text("Publica lotes para gestores certificados")
                        .font(.system(size: 12, weight: .light)).foregroundStyle(Color(uiColor: .tertiaryLabel))
                }
                Spacer()
                if isOn {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.nexoForest).transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Sp.lg).padding(.vertical, 18)
            .background(isOn ? Color.nexoForest.opacity(0.04) : Color.clear)
            .animation(.easeOut(duration: 0.2), value: isOn)
        }
        .buttonStyle(.plain)
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
    ContentView().modelContainer(for: [FichaRegistro.self, LoteRegistro.self], inMemory: true)
}
