import SwiftUI
import SwiftData

@main
struct nexoApp: App {
    @StateObject private var auth = AuthService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
        }
        .modelContainer(for: [
            FichaRegistro.self,
            RecoleccionRegistro.self,
            LoteRegistro.self
        ])
    }
}

struct RootView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        Group {
            if auth.isAuthenticated {
                ContentView()
                    .onOpenURL { url in
                        if url.host == "scan"      { NotificationCenter.default.post(name: .nexoOpenScanner,   object: nil) }
                        if url.host == "historial" { NotificationCenter.default.post(name: .nexoOpenHistorial, object: nil) }
                    }
            } else {
                WelcomeView()
            }
        }
        .task { await auth.loadSession() }
    }
}
