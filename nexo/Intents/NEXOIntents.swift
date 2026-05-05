// NEXOIntents.swift
import AppIntents
import SwiftUI

struct EscanearResiduoIntent: AppIntent {
    static var title       = LocalizedStringResource("Escanear residuo")
    static var description = IntentDescription("Abre NEXO directo al escáner de residuos.")
    static var openAppWhenRun: Bool = true
    static var parameterSummary: some ParameterSummary { Summary("Escanear un residuo con NEXO") }

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .nexoOpenScanner, object: nil)
        return .result()
    }
}

struct VerImpactoIntent: AppIntent {
    static var title       = LocalizedStringResource("Ver mi impacto")
    static var description = IntentDescription("Muestra el historial de impacto ambiental en NEXO.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .nexoOpenHistorial, object: nil)
        return .result()
    }
}

struct NEXOShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: EscanearResiduoIntent(),
            phrases: ["Escanear residuo en \(.applicationName)", "Abrir escáner de \(.applicationName)"],
            shortTitle: "Escanear residuo",
            systemImageName: "viewfinder"
        )
        AppShortcut(
            intent: VerImpactoIntent(),
            phrases: ["Ver mi impacto en \(.applicationName)"],
            shortTitle: "Ver impacto",
            systemImageName: "clock.arrow.circlepath"
        )
    }
}

extension Notification.Name {
    static let nexoOpenScanner   = Notification.Name("nexoOpenScanner")
    static let nexoOpenHistorial = Notification.Name("nexoOpenHistorial")
}
