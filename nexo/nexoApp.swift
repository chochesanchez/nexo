import SwiftUI
import SwiftData

@main
struct nexoApp: App {
    @StateObject private var auth     = AuthService.shared
    @StateObject private var repo     = ListingsRepository()
    @StateObject private var location = LocationManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(repo)
                .environmentObject(location)
        }
        .modelContainer(for: FichaRegistro.self)
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
                SignUpView()
            }
        }
        .task {
            await auth.loadSession()
        }
    }
}
