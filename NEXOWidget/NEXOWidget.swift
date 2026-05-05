//
//  NEXOWidget.swift
//  NEXOWidget
//
//  Created by Guillermo Lira on 04/05/26.
//

// NEXOWidget.swift
// Versión autocontenida: no depende de NEXOTheme, NEXOIntents ni tipos del target principal.
// Todos los colores, spacing y App Intents están declarados aquí mismo.

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Colores locales (evitan la dependencia de NEXOTheme del target principal)

private extension Color {
    static let wGreen = Color(red: 0.271, green: 0.694, blue: 0.357)
    static let wAmber = Color(red: 0.980, green: 0.812, blue: 0.000)
}

// MARK: - App Intents locales del widget
// (Si NEXOIntents.swift ya está en el target del widget, elimina estas dos structs)

struct EscanearResiduoWidgetIntent: AppIntent {
    static var title       = LocalizedStringResource("Escanear residuo")
    static var description = IntentDescription("Abre NEXO directo al escáner.")
    static var openAppWhenRun: Bool = true
    func perform() async throws -> some IntentResult { .result() }
}

struct VerImpactoWidgetIntent: AppIntent {
    static var title       = LocalizedStringResource("Ver mi impacto")
    static var description = IntentDescription("Muestra el historial de impacto en NEXO.")
    static var openAppWhenRun: Bool = true
    func perform() async throws -> some IntentResult { .result() }
}

// MARK: - Entry

struct NEXOWidgetEntry: TimelineEntry {
    let date         : Date
    let materialesHoy: Int
    let co2Total     : String
}

// MARK: - Provider

struct NEXOWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> NEXOWidgetEntry {
        NEXOWidgetEntry(date: .now, materialesHoy: 3, co2Total: "225 g")
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (NEXOWidgetEntry) -> Void) {
        completion(NEXOWidgetEntry(date: .now, materialesHoy: 3, co2Total: "225 g"))
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<NEXOWidgetEntry>) -> Void) {
        // La app principal escribe estos valores en App Group UserDefaults
        let defaults = UserDefaults(suiteName: "group.com.nexo.app")
        let count    = defaults?.integer(forKey: "nexo_materiales_semana") ?? 0
        let co2      = defaults?.string(forKey: "nexo_co2_semana") ?? "0 g"

        let entry = NEXOWidgetEntry(date: .now, materialesHoy: count, co2Total: co2)
        let next  = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Small Widget

private struct SmallView: View {
    let entry: NEXOWidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("NEXO")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.wGreen)
                Spacer()
                Image(systemName: "arrow.3.trianglepath")
                    .font(.system(size: 11)).foregroundStyle(Color.wGreen)
            }
            Spacer()
            Text("\(entry.materialesHoy)")
                .font(.system(size: 38, weight: .bold, design: .rounded))
            Text("materiales\nesta semana")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Button(intent: EscanearResiduoWidgetIntent()) {
                Label("Escanear", systemImage: "viewfinder")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.wGreen, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }
}

// MARK: - Medium Widget

private struct MediumView: View {
    let entry: NEXOWidgetEntry
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("NEXO")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.wGreen)
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.materialesHoy)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("materiales esta semana")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "wind")
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.wGreen)
                    Text(entry.co2Total).font(.system(size: 13, weight: .semibold))
                    Text("CO₂ evitado").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(14)

            Divider().padding(.vertical, 14)

            VStack(spacing: 8) {
                Button(intent: EscanearResiduoWidgetIntent()) {
                    VStack(spacing: 4) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 22)).foregroundStyle(Color.wGreen)
                        Text("Escanear").font(.system(size: 11, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.wGreen.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button(intent: VerImpactoWidgetIntent()) {
                    VStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 22)).foregroundStyle(Color.wAmber)
                        Text("Historial").font(.system(size: 11, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.wAmber.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(10)
        }
    }
}

// MARK: - Entry View

struct NEXOWidgetEntryView: View {
    var entry: NEXOWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemMedium: MediumView(entry: entry)
        default:            SmallView(entry: entry)
        }
    }
}

// MARK: - Widget Config

struct NEXOWidget: Widget {
    let kind = "NEXOWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NEXOWidgetProvider()) { entry in
            NEXOWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("NEXO")
        .description("Tus materiales reciclados y acceso rápido al escáner.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    NEXOWidget()
} timeline: {
    NEXOWidgetEntry(date: .now, materialesHoy: 5, co2Total: "375 g")
}

#Preview(as: .systemMedium) {
    NEXOWidget()
} timeline: {
    NEXOWidgetEntry(date: .now, materialesHoy: 5, co2Total: "375 g")
}
