//
//  Historialrecolectorview.swift
//  nexo
//
//  Created by Guillermo Lira on 05/05/26.
//

// HistorialRecolectorView.swift
// Historial del recolector con:
//   • SwiftData model RecoleccionRegistro
//   • Totales por semana / mes / todo
//   • Valor acumulado estimado
//   • Gráfica por categoría de material (Swift Charts)
//   • Lista de recolecciones recientes

import SwiftUI
import SwiftData
import Charts

// MARK: - Modelo SwiftData

@Model
final class RecoleccionRegistro {
    var uuid        : UUID   = UUID()
    var classKey    : String = ""
    var displayName : String = ""
    var icon        : String = ""
    var value       : String = ""
    var co2Raw      : String = ""   // "120 g CO₂" — parseamos el número
    var zona        : String = ""   // placeholder para colonia futura
    var lat         : Double = 0
    var lng         : Double = 0
    var fecha       : Date   = Date()

    init(material: NEXOMaterial, lat: Double = 19.4326, lng: Double = -99.1332) {
        self.uuid        = UUID()
        self.classKey    = material.classKey
        self.displayName = material.displayName
        self.icon        = material.icon
        self.value       = material.value
        self.co2Raw      = material.co2
        self.lat         = lat
        self.lng         = lng
        self.fecha       = Date()
    }

    // Extrae el primer número del string de valor ("$18 MXN/kg" → 18.0)
    var valorNumerico: Double {
        let digits = value
            .components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
            .joined()
        return Double(digits) ?? 0
    }

    // Extrae gramos de CO₂ ("120 g CO₂" → 120.0)
    var co2Gramos: Double {
        let digits = co2Raw
            .components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
            .joined()
        return Double(digits) ?? 0
    }
}

// MARK: - Stat por categoría para la gráfica

struct CategoryStat: Identifiable {
    let id         : String
    let classKey   : String
    let shortName  : String
    let icon       : String
    let count      : Int
    let color      : Color
    let valorTotal : Double
}

// MARK: - HistorialRecolectorView

struct HistorialRecolectorView: View {

    @Query(sort: \RecoleccionRegistro.fecha, order: .reverse)
    private var registros: [RecoleccionRegistro]

    @Environment(\.modelContext) private var context

    @State private var periodo: Periodo = .semana

    enum Periodo: String, CaseIterable {
        case semana = "Semana"
        case mes    = "Mes"
        case todo   = "Todo"
    }

    // MARK: - Filtrado por periodo

    private var registrosFiltrados: [RecoleccionRegistro] {
        let ahora = Date()
        let cal   = Calendar.current
        switch periodo {
        case .semana:
            let inicio = cal.dateInterval(of: .weekOfYear, for: ahora)?.start ?? ahora
            return registros.filter { $0.fecha >= inicio }
        case .mes:
            let inicio = cal.dateInterval(of: .month, for: ahora)?.start ?? ahora
            return registros.filter { $0.fecha >= inicio }
        case .todo:
            return registros
        }
    }

    // MARK: - Métricas calculadas

    private var totalRecolecciones: Int { registrosFiltrados.count }

    private var valorAcumulado: Double {
        registrosFiltrados.reduce(0) { $0 + $1.valorNumerico }
    }

    private var co2Total: Double {
        registrosFiltrados.reduce(0) { $0 + $1.co2Gramos }
    }

    private var co2Display: String {
        co2Total >= 1000
            ? String(format: "%.1f kg", co2Total / 1000)
            : "\(Int(co2Total)) g"
    }

    // MARK: - Stats por categoría para la gráfica

    private var categoryStats: [CategoryStat] {
        let colorMap: [String: Color] = [
            "pet_bottle"       : Color(hex: "006D8F"),
            "aluminum_can"     : Color(hex: "9E9E9E"),
            "cardboard_box"    : Color(hex: "C8A97E"),
            "glass_bottle"     : Color(hex: "1D9E75"),
            "organic_simple"   : Color(hex: "4CAF50"),
            "battery_electronic": Color(hex: "FACF00"),
        ]
        let shortNames: [String: String] = [
            "pet_bottle"       : "PET",
            "aluminum_can"     : "Alum.",
            "cardboard_box"    : "Cartón",
            "glass_bottle"     : "Vidrio",
            "organic_simple"   : "Orgánico",
            "battery_electronic": "Electr.",
        ]
        let icons: [String: String] = [
            "pet_bottle"       : "waterbottle.fill",
            "aluminum_can"     : "cylinder.fill",
            "cardboard_box"    : "shippingbox.fill",
            "glass_bottle"     : "wineglass.fill",
            "organic_simple"   : "leaf.fill",
            "battery_electronic": "bolt.fill",
        ]

        var grouped: [String: [RecoleccionRegistro]] = [:]
        for reg in registrosFiltrados {
            grouped[reg.classKey, default: []].append(reg)
        }

        return grouped
            .map { key, regs in
                CategoryStat(
                    id        : key,
                    classKey  : key,
                    shortName : shortNames[key] ?? key,
                    icon      : icons[key] ?? "leaf",
                    count     : regs.count,
                    color     : colorMap[key] ?? Color.nexoBrand,
                    valorTotal: regs.reduce(0) { $0 + $1.valorNumerico }
                )
            }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                if registros.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            periodoPicker
                            resumenCards
                            if !categoryStats.isEmpty { graficaSection }
                            if !registrosFiltrados.isEmpty { recentesSection }
                        }
                        .padding(.horizontal, Sp.lg)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Mi historial")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !registros.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                registrosFiltrados.forEach { context.delete($0) }
                            } label: {
                                Label("Borrar este periodo", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle").foregroundStyle(Color.nexoBrand)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Picker de periodo

    private var periodoPicker: some View {
        Picker("Periodo", selection: $periodo.animation(.easeOut(duration: 0.25))) {
            ForEach(Periodo.allCases, id: \.self) { p in
                Text(p.rawValue).tag(p)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Tarjetas de resumen

    private var resumenCards: some View {
        HStack(spacing: 10) {
            summaryCard(
                icon  : "checkmark.circle.fill",
                label : "Recolectadas",
                value : "\(totalRecolecciones)",
                unit  : totalRecolecciones == 1 ? "ficha" : "fichas",
                color : Color.nexoBrand
            )
            summaryCard(
                icon  : "tag.fill",
                label : "Valor estimado",
                value : valorAcumulado > 0 ? String(format: "$%.0f", valorAcumulado) : "—",
                unit  : "MXN",
                color : Color(hex: "7A5F00")
            )
            summaryCard(
                icon  : "wind",
                label : "CO₂ evitado",
                value : co2Display,
                unit  : "",
                color : Color.nexoBrand
            )
        }
    }

    private func summaryCard(icon: String, label: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(.system(size: 10, weight: .semibold)).tracking(0.2)
            }
            .foregroundStyle(Color(uiColor: .secondaryLabel))

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 24, weight: .black)).tracking(-1.5)
                    .foregroundStyle(totalRecolecciones == 0 ? Color(uiColor: .tertiaryLabel) : color)
                if !unit.isEmpty {
                    Text(unit).font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Rd.lg))
        .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
    }

    // MARK: - Gráfica por categoría

    private var graficaSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Por material", subtitle: "\(categoryStats.count) categoría\(categoryStats.count == 1 ? "" : "s")")

            Chart(categoryStats) { stat in
                BarMark(
                    x: .value("Material", stat.shortName),
                    y: .value("Recolectadas", stat.count)
                )
                .foregroundStyle(stat.color)
                .cornerRadius(6)
                .annotation(position: .top, alignment: .center) {
                    Text("\(stat.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(stat.color)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color(uiColor: .separator))
                    AxisValueLabel()
                        .font(.system(size: 10))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
            }
            .frame(height: 180)
            .padding(.horizontal, 4)

            // Leyenda de valores
            if categoryStats.contains(where: { $0.valorTotal > 0 }) {
                VStack(spacing: 6) {
                    ForEach(categoryStats.filter { $0.valorTotal > 0 }) { stat in
                        HStack(spacing: 8) {
                            Image(systemName: stat.icon)
                                .font(.system(size: 11)).foregroundStyle(stat.color)
                            Text(stat.shortName)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                            Spacer()
                            Text("\(stat.count) · \(String(format: "$%.0f est.", stat.valorTotal))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(uiColor: .label))
                        }
                    }
                }
                .padding(12)
                .background(Color(uiColor: .systemGray6), in: RoundedRectangle(cornerRadius: Rd.md))
            }
        }
        .padding(Sp.lg)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Rd.lg))
        .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
    }

    // MARK: - Lista recientes

    private var recentesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Recientes", subtitle: nil)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(registrosFiltrados.prefix(20).enumerated()), id: \.element.uuid) { idx, reg in
                    recenteRow(reg)
                    if idx < min(registrosFiltrados.count, 20) - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Rd.lg))
            .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))

            if registrosFiltrados.count > 20 {
                Text("Mostrando las 20 más recientes de \(registrosFiltrados.count)")
                    .font(.system(size: 11)).foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
        }
    }

    private func recenteRow(_ reg: RecoleccionRegistro) -> some View {
        HStack(spacing: 12) {
            // Ícono
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.nexoMint)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: reg.icon)
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(Color.nexoBrand)
                }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(reg.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .label))
                Text(reg.fecha, style: .relative)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }

            Spacer()

            // Valor
            if reg.valorNumerico > 0 {
                Text(String(format: "$%.0f", reg.valorNumerico))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "7A5F00"))
            }
        }
        .padding(.horizontal, Sp.md)
        .padding(.vertical, 10)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { context.delete(reg) } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundStyle(Color.nexoBrand.opacity(0.35))
            Text("Sin recolecciones aún")
                .font(.system(size: 17, weight: .semibold))
            Text("Cada vez que confirmes una recolección\nen el mapa, aparecerá aquí.")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .multilineTextAlignment(.center).lineSpacing(3)
        }
        .padding(40)
    }

    // MARK: - Helpers UI

    private func sectionHeader(_ title: String, subtitle: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(uiColor: .label))
            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
            Spacer()
        }
    }
}

#Preview {
    HistorialRecolectorView()
        .modelContainer(for: RecoleccionRegistro.self, inMemory: true)
}
