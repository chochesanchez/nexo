//
//  HistorialEmpresView.swift
//  nexo
//
//  Created by Grecia Saucedo on 05/05/26.
//

import SwiftUI
import SwiftData

// MARK: - Modelo SwiftData

@Model
final class LoteRegistro {
    var classKey      : String
    var displayName   : String
    var icon          : String
    var route         : String
    var co2           : String
    var value         : String
    var kgEstimados   : Double
    var frecuencia    : String
    var tipoGenerador : String
    var notes         : String
    var fecha         : Date
    var estado        : String   // "activo" | "recogido"
    var supabaseId    : String?

    init(
        material      : NEXOMaterial,
        kgEstimados   : Double,
        frecuencia    : FrecuenciaGeneracion,
        tipoGenerador : TipoGenerador,
        notes         : String = ""
    ) {
        self.classKey      = material.classKey
        self.displayName   = material.displayName
        self.icon          = material.icon
        self.route         = material.route.rawValue
        self.co2           = material.co2
        self.value         = material.value
        self.kgEstimados   = kgEstimados
        self.frecuencia    = frecuencia.rawValue
        self.tipoGenerador = tipoGenerador.rawValue
        self.notes         = notes
        self.fecha         = Date()
        self.estado        = "activo"
    }
}

// MARK: - Segmentos

enum LoteSegmento: String, CaseIterable {
    case activos   = "Activos"
    case recogidos = "Recogidos"
    case todos     = "Todos"

    var icon: String {
        switch self {
        case .activos:   return "map"
        case .recogidos: return "checkmark.circle"
        case .todos:     return "list.bullet"
        }
    }
}

// MARK: - HistorialEmpresaView

struct HistorialEmpresaView: View {
    @EnvironmentObject private var repo: ListingsRepository
    @Environment(\.modelContext) private var context

    @Query(sort: \LoteRegistro.fecha, order: .reverse) private var todos: [LoteRegistro]

    @State private var segmento    : LoteSegmento = .activos
    @State private var publishError: String?      = nil

    private var activos   : [LoteRegistro] { todos.filter { $0.estado == "activo"   } }
    private var recogidos : [LoteRegistro] { todos.filter { $0.estado == "recogido" } }
    private var listaActual: [LoteRegistro] {
        switch segmento {
        case .activos:   return activos
        case .recogidos: return recogidos
        case .todos:     return todos
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    segmentPicker
                        .padding(.horizontal, Sp.lg)
                        .padding(.top, Sp.md)
                        .padding(.bottom, Sp.sm)

                    // Resumen de impacto anual (solo en recogidos)
                    if segmento == .recogidos && !recogidos.isEmpty {
                        impactSummary
                            .padding(.horizontal, Sp.lg)
                            .padding(.bottom, Sp.sm)
                    }

                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            if listaActual.isEmpty {
                                emptyState
                            } else {
                                switch segmento {
                                case .activos:   activosSection
                                case .recogidos: recogidosSection
                                case .todos:     todosSection
                                }
                            }
                        }
                        .padding(.horizontal, Sp.lg)
                        .padding(.top, Sp.sm)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Mis lotes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .alert("Error", isPresented: .constant(publishError != nil)) {
                Button("OK") { publishError = nil }
            } message: { Text(publishError ?? "") }
        }
    }

    // MARK: - Segment picker 

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(LoteSegmento.allCases, id: \.self) { seg in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { segmento = seg }
                } label: {
                    VStack(spacing: 3) {
                        Text(seg.rawValue)
                            .font(.system(size: 12, weight: segmento == seg ? .semibold : .regular))
                            .foregroundStyle(segmento == seg ? Color.nexoForest : Color(uiColor: .secondaryLabel))

                        let count = countFor(seg)
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(segmento == seg ? .white : Color(uiColor: .tertiaryLabel))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(
                                    segmento == seg ? Color.nexoForest : Color(uiColor: .systemGray4),
                                    in: Capsule()
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        segmento == seg ? Color(uiColor: .systemBackground) : Color.clear,
                        in: RoundedRectangle(cornerRadius: Rd.md)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(uiColor: .systemGray5), in: RoundedRectangle(cornerRadius: Rd.lg))
    }

    private func countFor(_ seg: LoteSegmento) -> Int {
        switch seg {
        case .activos:   return activos.count
        case .recogidos: return recogidos.count
        case .todos:     return todos.count
        }
    }

    // MARK: - Secciones

    @ViewBuilder
    private var activosSection: some View {
        // Header informativo
        HStack {
            Text("Visibles para gestores certificados")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
            Spacer()
        }
        .padding(.bottom, 4)

        ForEach(activos) { lote in
            LoteActivoRow(lote: lote) {
                withAnimation { lote.estado = "recogido" }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    @ViewBuilder
    private var recogidosSection: some View {
        ForEach(recogidos) { lote in
            LoteRecogidoRow(lote: lote)
        }
    }

    @ViewBuilder
    private var todosSection: some View {
        ForEach(todos) { lote in
            LoteGenericoRow(lote: lote) {
                withAnimation { lote.estado = lote.estado == "activo" ? "recogido" : "activo" }
            }
        }
    }

    // MARK: - Resumen de impacto anual (recogidos)

    private var impactSummary: some View {
        HStack(spacing: 10) {
            summaryCard(
                label: "Lotes recogidos",
                value: "\(recogidos.count)",
                icon:  "checkmark.circle.fill",
                color: Color.nexoForest
            )
            summaryCard(
                label: "CO₂ proyectado",
                value: co2AnualTotal,
                icon:  "wind",
                color: Color.nexoBrand
            )
            summaryCard(
                label: "Kg totales",
                value: kgTotal,
                icon:  "scalemass.fill",
                color: Color.nexoForest
            )
        }
    }

    private func summaryCard(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundStyle(color)
                Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(Color(uiColor: .secondaryLabel))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold)).tracking(-0.5)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Sp.md)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.lg))
        .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: segmento == .activos ? "shippingbox" : "checkmark.circle")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(Color.nexoForest.opacity(0.3))
                .padding(.top, 48)

            Text(emptyTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(uiColor: .label))

            Text(emptyDetail)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 40)
    }

    private var emptyTitle: String {
        switch segmento {
        case .activos:   return "Sin lotes activos"
        case .recogidos: return "Sin lotes recogidos aún"
        case .todos:     return "Sin lotes publicados"
        }
    }

    private var emptyDetail: String {
        switch segmento {
        case .activos:   return "Publica tu primer lote desde\n\"Publicar lote\" para verlo aquí."
        case .recogidos: return "Cuando un gestor recoja tus materiales\naparecerán aquí."
        case .todos:     return "Usa \"Publicar lote\" para empezar."
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !todos.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    listaActual.forEach { context.delete($0) }
                } label: {
                    Image(systemName: "trash").foregroundStyle(.red)
                }
                .accessibilityLabel("Borrar lotes de este segmento")
            }
        }
    }

    // MARK: - Cálculos de impacto

    private var co2AnualTotal: String {
        let total = recogidos.reduce(0.0) { acc, lote in
            let digits = lote.co2.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            let co2PerKg = Double(digits) ?? 0
            let mult = multiplicador(frecuencia: lote.frecuencia)
            return acc + co2PerKg * lote.kgEstimados * mult / 1000
        }
        return total >= 1000
            ? String(format: "%.1f t", total / 1000)
            : String(format: "%.0f kg", total)
    }

    private var kgTotal: String {
        let total = recogidos.reduce(0.0) { $0 + $1.kgEstimados }
        return total >= 1000
            ? String(format: "%.1f t", total / 1000)
            : String(format: "%.0f kg", total)
    }

    private func multiplicador(frecuencia: String) -> Double {
        switch frecuencia {
        case "Diaria":    return 365
        case "Semanal":   return 52
        case "Quincenal": return 26
        case "Mensual":   return 12
        default:          return 52
        }
    }
}

// MARK: - LoteActivoRow

struct LoteActivoRow: View {
    let lote     : LoteRegistro
    let onRecoger: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Ícono con acento del material
            let accent = NEXOMaterial.all[lote.classKey]?.accent ?? Color.nexoForest
            RoundedRectangle(cornerRadius: 8)
                .fill(accent.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: lote.icon)
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(accent)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(lote.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .label))

                HStack(spacing: 6) {
                    // Kg + frecuencia
                    Text(String(format: "%.0f kg · %@", lote.kgEstimados, lote.frecuencia))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.nexoForest)

                    Text("·")
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))

                    // Tipo de generador
                    Text(lote.tipoGenerador)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }

                // Estado activo — punto verde
                HStack(spacing: 4) {
                    Circle().fill(Color.nexoGreen).frame(width: 5, height: 5)
                    Text("Visible para gestores")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.nexoGreen)
                }
            }

            Spacer()

            Text(lote.fecha, style: .date)
                .font(.system(size: 10, weight: .light))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .padding(Sp.md)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Rd.lg)
                .strokeBorder(Color(uiColor: .separator), lineWidth: 0.5)
        )
        .swipeActions(edge: .trailing) {
            Button(action: onRecoger) {
                Label("Recogido", systemImage: "checkmark.circle")
            }
            .tint(Color.nexoForest)
        }
        .swipeActions(edge: .leading) {
            Button(role: .destructive) {
                // se maneja desde toolbar o desde la vista padre
            } label: {
                Label("Borrar", systemImage: "trash")
            }
        }
    }
}

// MARK: - LoteRecogidoRow

struct LoteRecogidoRow: View {
    let lote: LoteRegistro

    var body: some View {
        HStack(spacing: 12) {
            // Ícono atenuado (recogido)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: .systemGray5))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: lote.icon)
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(lote.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .label))

                HStack(spacing: 6) {
                    Text(String(format: "%.0f kg · %@", lote.kgEstimados, lote.frecuencia))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                    Text("·")
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    // CO2 proyectado anual
                    let digits = lote.co2.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    let co2PerKg = Double(digits) ?? 0
                    let mult: Double = {
                        switch lote.frecuencia {
                        case "Diaria": return 365
                        case "Semanal": return 52
                        case "Quincenal": return 26
                        default: return 12
                        }
                    }()
                    let co2Anual = co2PerKg * lote.kgEstimados * mult / 1000
                    Text(String(format: "%.1f kg CO₂/año", co2Anual))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.nexoBrand)
                }

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.nexoForest)
                    Text("Recogido")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.nexoForest)
                }
            }

            Spacer()

            Text(lote.fecha, style: .date)
                .font(.system(size: 10, weight: .light))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .padding(Sp.md)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Rd.lg)
                .strokeBorder(Color(uiColor: .separator), lineWidth: 0.5)
        )
    }
}

// MARK: - LoteGenericoRow (segmento "Todos")

struct LoteGenericoRow: View {
    let lote    : LoteRegistro
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            let accent = NEXOMaterial.all[lote.classKey]?.accent ?? Color.nexoForest
            let isActivo = lote.estado == "activo"

            RoundedRectangle(cornerRadius: 8)
                .fill(isActivo ? accent.opacity(0.1) : Color(uiColor: .systemGray5))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: lote.icon)
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(isActivo ? accent : Color(uiColor: .secondaryLabel))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(lote.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .label))
                Text(String(format: "%.0f kg · %@ · %@", lote.kgEstimados, lote.frecuencia, lote.tipoGenerador))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))

                // Badge de estado
                Text(isActivo ? "Activo" : "Recogido")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isActivo ? Color.nexoGreen : Color.nexoForest)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(
                        isActivo ? Color.nexoGreen.opacity(0.1) : Color.nexoForest.opacity(0.08),
                        in: Capsule()
                    )
            }

            Spacer()

            Text(lote.fecha, style: .date)
                .font(.system(size: 10, weight: .light))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .padding(Sp.md)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Rd.lg)
                .strokeBorder(Color(uiColor: .separator), lineWidth: 0.5)
        )
        .swipeActions(edge: .trailing) {
            Button(action: onToggle) {
                Label(
                    lote.estado == "activo" ? "Marcar recogido" : "Reactivar",
                    systemImage: lote.estado == "activo" ? "checkmark.circle" : "arrow.counterclockwise"
                )
            }
            .tint(Color.nexoForest)
        }
    }
}

#Preview("Historial Empresa") {
    HistorialEmpresaView()
        .environmentObject(ListingsRepository())
        .modelContainer(for: LoteRegistro.self, inMemory: true)
}

