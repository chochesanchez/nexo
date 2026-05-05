// HistorialView.swift
// Flujo nuevo:
//   Escanear → guardar como "pendiente" → compartir en bulk desde aquí → "activa" → "recogida"
//
// FichaRegistro ahora tiene 3 estados:
//   pendiente → guardada localmente, NO publicada al mapa
//   activa    → publicada a Supabase, visible para recolectores
//   recogida  → el recolector la confirmó

import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Modelo actualizado

@Model
final class FichaRegistro {
    var classKey      : String
    var displayName   : String
    var icon          : String
    var route         : String
    var co2           : String
    var water         : String
    var value         : String
    var fecha         : Date
    var estado        : String   // "pendiente" | "activa" | "recogida"
    var instruccionFM : String?
    var ocrText       : String?
    var lat           : Double
    var lng           : Double
    var supabaseId    : String?  // UUID del listing en Supabase

    init(material: NEXOMaterial,
         instruccionFM: String? = nil,
         ocrText: String? = nil,
         lat: Double = 19.4326,
         lng: Double = -99.1332) {
        self.classKey      = material.classKey
        self.displayName   = material.displayName
        self.icon          = material.icon
        self.route         = material.route.rawValue
        self.co2           = material.co2
        self.water         = material.water
        self.value         = material.value
        self.fecha         = Date()
        self.estado        = "pendiente"
        self.instruccionFM = instruccionFM
        self.ocrText       = ocrText
        self.lat           = lat
        self.lng           = lng
        HistorialView.writeWidgetData()
    }
}

// MARK: - Segmentos del historial

enum HistorialSegmento: String, CaseIterable {
    case pendientes = "Por compartir"
    case enMapa     = "En el mapa"
    case recogidas  = "Recogidas"

    var icon: String {
        switch self {
        case .pendientes: return "clock"
        case .enMapa:     return "map"
        case .recogidas:  return "checkmark.circle"
        }
    }
}

// MARK: - HistorialView

struct HistorialView: View {
    @EnvironmentObject private var repo: ListingsRepository
    @Environment(\.modelContext) private var context

    @Query(sort: \FichaRegistro.fecha, order: .reverse) private var todas: [FichaRegistro]

    @State private var segmento     : HistorialSegmento = .pendientes
    @State private var seleccionados: Set<PersistentIdentifier> = []
    @State private var isPublishing  = false
    @State private var publishError  : String? = nil
    @State private var showSuccess   = false
    @State private var successCount  = 0

    private var pendientes : [FichaRegistro] { todas.filter { $0.estado == "pendiente" } }
    private var enMapa     : [FichaRegistro] { todas.filter { $0.estado == "activa"    } }
    private var recogidas  : [FichaRegistro] { todas.filter { $0.estado == "recogida"  } }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segment control
                    segmentPicker
                        .padding(.horizontal, Sp.lg)
                        .padding(.top, Sp.md)
                        .padding(.bottom, Sp.sm)

                    // Impact summary (solo en recogidas)
                    if segmento == .recogidas && !recogidas.isEmpty {
                        impactSummary
                            .padding(.horizontal, Sp.lg)
                            .padding(.bottom, Sp.sm)
                    }

                    // Lista
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            switch segmento {
                            case .pendientes: pendientesSection
                            case .enMapa:     enMapaSection
                            case .recogidas:  recogidasSection
                            }
                        }
                        .padding(.horizontal, Sp.lg)
                        .padding(.top, Sp.sm)
                        // Espacio para el botón flotante
                        .padding(.bottom, seleccionados.isEmpty ? 24 : 100)
                    }
                }

                // Botón bulk flotante
                if !seleccionados.isEmpty && segmento == .pendientes {
                    bulkShareButton
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Historial")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .alert("Error al compartir", isPresented: .constant(publishError != nil)) {
                Button("OK") { publishError = nil }
            } message: { Text(publishError ?? "") }
            .overlay {
                if showSuccess { successOverlay }
            }
        }
        .task { await repo.fetchAvailable() }
    }

    // MARK: - Segment picker

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(HistorialSegmento.allCases, id: \.self) { seg in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        segmento = seg
                        seleccionados.removeAll()
                    }
                } label: {
                    VStack(spacing: 3) {
                        Text(seg.rawValue)
                            .font(.system(size: 12, weight: segmento == seg ? .semibold : .regular))
                            .foregroundStyle(segmento == seg ? Color.nexoForest : Color(uiColor: .secondaryLabel))

                        // Badge de cantidad
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
                        segmento == seg
                        ? Color(uiColor: .systemBackground)
                        : Color.clear,
                        in: RoundedRectangle(cornerRadius: Rd.md)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(uiColor: .systemGray5), in: RoundedRectangle(cornerRadius: Rd.lg))
    }

    private func countFor(_ seg: HistorialSegmento) -> Int {
        switch seg {
        case .pendientes: return pendientes.count
        case .enMapa:     return enMapa.count
        case .recogidas:  return recogidas.count
        }
    }

    // MARK: - Sección: Por compartir

    @ViewBuilder
    private var pendientesSection: some View {
        if pendientes.isEmpty {
            emptyState(
                icon   : "viewfinder",
                titulo : "Sin fichas pendientes",
                detalle: "Escanea residuos y guárdalos aquí.\nDesde aquí los compartes todos de una vez."
            )
        } else {
            // Header con "seleccionar todo"
            HStack {
                Text("Selecciona las que quieras compartir")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                Spacer()
                Button {
                    withAnimation {
                        if seleccionados.count == pendientes.count {
                            seleccionados.removeAll()
                        } else {
                            seleccionados = Set(pendientes.map { $0.persistentModelID })
                        }
                    }
                } label: {
                    Text(seleccionados.count == pendientes.count ? "Quitar todo" : "Seleccionar todo")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.nexoBrand)
                }
            }
            .padding(.bottom, 4)

            ForEach(pendientes) { ficha in
                PendienteRow(
                    ficha       : ficha,
                    isSelected  : seleccionados.contains(ficha.persistentModelID)
                ) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        if seleccionados.contains(ficha.persistentModelID) {
                            seleccionados.remove(ficha.persistentModelID)
                        } else {
                            seleccionados.insert(ficha.persistentModelID)
                        }
                    }
                } onDelete: {
                    context.delete(ficha)
                }
            }
        }
    }

    // MARK: - Sección: En el mapa

    @ViewBuilder
    private var enMapaSection: some View {
        if enMapa.isEmpty {
            emptyState(
                icon   : "map",
                titulo : "Nada en el mapa aún",
                detalle: "Comparte tus fichas pendientes\npara que aparezcan en el mapa."
            )
        } else {
            ForEach(enMapa) { ficha in
                ActivaRow(ficha: ficha) {
                    // Marcar como recogida manualmente
                    withAnimation { ficha.estado = "recogida" }
                }
            }
        }
    }

    // MARK: - Sección: Recogidas

    @ViewBuilder
    private var recogidasSection: some View {
        if recogidas.isEmpty {
            emptyState(
                icon   : "checkmark.circle",
                titulo : "Sin recolecciones aún",
                detalle: "Cuando un recolector recoja\ntus materiales aparecerán aquí."
            )
        } else {
            ForEach(recogidas) { ficha in
                RecogidaRow(ficha: ficha)
            }
        }
    }

    // MARK: - Impact summary

    private var impactSummary: some View {
        HStack(spacing: 10) {
            summaryCard(
                label : "Materiales",
                value : "\(recogidas.count)",
                icon  : "arrow.3.trianglepath",
                color : Color.nexoBrand
            )
            summaryCard(
                label : "CO₂ evitado",
                value : co2Total,
                icon  : "wind",
                color : Color.nexoBrand
            )
        }
    }

    private func summaryCard(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundStyle(color)
                Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(Color(uiColor: .secondaryLabel))
            }
            Text(value).font(.system(size: 20, weight: .bold)).tracking(-0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Sp.md)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.lg))
        .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
    }

    // MARK: - Botón bulk compartir

    private var bulkShareButton: some View {
        Button { Task { await compartirSeleccionadas() } } label: {
            HStack(spacing: 10) {
                if isPublishing {
                    ProgressView().tint(.white).scaleEffect(0.85)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(isPublishing
                     ? "Compartiendo…"
                     : "Compartir \(seleccionados.count) ficha\(seleccionados.count == 1 ? "" : "s") al mapa")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.nexoForest, in: RoundedRectangle(cornerRadius: Rd.lg))
            .shadow(color: Color.nexoForest.opacity(0.3), radius: 12, y: 4)
            .padding(.horizontal, Sp.lg)
            .padding(.bottom, 24)
        }
        .disabled(isPublishing)
    }

    // MARK: - Success overlay

    private var successOverlay: some View {
        ZStack {
            Color.nexoForest.opacity(0.96).ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.1)).frame(width: 100, height: 100)
                    Image(systemName: "map.fill")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.white)
                }
                VStack(spacing: 6) {
                    Text("\(successCount) ficha\(successCount == 1 ? "" : "s") en el mapa")
                        .font(.system(size: 22, weight: .bold)).tracking(-0.8).foregroundStyle(.white)
                    Text("Los recolectores ya pueden verlas.")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.3)) { showSuccess = false }
            }
        }
    }

    // MARK: - Empty state

    private func emptyState(icon: String, titulo: String, detalle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(Color.nexoGreen.opacity(0.4))
            Text(titulo)
                .font(.system(size: 16, weight: .semibold))
            Text(detalle)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if segmento == .pendientes && !pendientes.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    pendientes.forEach { context.delete($0) }
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Bulk publish

    private func compartirSeleccionadas() async {
        guard !seleccionados.isEmpty else { return }
        isPublishing = true
        let fichasACompartir = pendientes.filter { seleccionados.contains($0.persistentModelID) }
        var exitosos = 0

        for ficha in fichasACompartir {
            let nuevo = NewListing(
                material      : ficha.displayName,
                quantityLabel : "1 unidad",
                notes         : ficha.instruccionFM ?? "",
                lat           : ficha.lat,
                lng           : ficha.lng,
                classKey      : ficha.classKey,
                displayName   : ficha.displayName,
                icon          : ficha.icon,
                route         : ficha.route,
                co2           : ficha.co2,
                water         : ficha.water,
                value         : ficha.value,
                fmInstruction : ficha.instruccionFM
            )
            let ok = await repo.publish(nuevo)
            if ok {
                ficha.estado = "activa"
                exitosos += 1
            }
        }

        isPublishing = false

        if exitosos > 0 {
            successCount = exitosos
            seleccionados.removeAll()
            withAnimation(.easeOut(duration: 0.2)) { showSuccess = true }
            Self.writeWidgetData(count: todas.count, co2: co2Total)
            WidgetKit.WidgetCenter.shared.reloadAllTimelines()
        } else {
            publishError = "No pudimos compartir las fichas. Verifica tu conexión."
        }
    }

    // MARK: - Cálculo de impacto

    private var co2Total: String {
        let total = recogidas.compactMap { reg -> Double? in
            let digits = reg.co2.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            return Double(digits)
        }.reduce(0, +)
        return total >= 1000 ? String(format: "%.1f kg", total / 1000) : "\(Int(total)) g"
    }

    // MARK: - Widget data

    static func writeWidgetData(count: Int? = nil, co2: String? = nil) {
        let defaults = UserDefaults(suiteName: "group.com.nexo.app")
        if let count { defaults?.set(count, forKey: "nexo_materiales_semana") }
        if let co2   { defaults?.set(co2,   forKey: "nexo_co2_semana") }
    }
}

// MARK: - PendienteRow

struct PendienteRow: View {
    let ficha      : FichaRegistro
    let isSelected : Bool
    let onTap      : () -> Void
    let onDelete   : () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(
                            isSelected ? Color.nexoBrand : Color(uiColor: .systemGray4),
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                        .frame(width: 22, height: 22)
                        .background(
                            isSelected ? Color.nexoMint : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.nexoBrand)
                    }
                }

                // Ícono
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.nexoMint)
                        .frame(width: 36, height: 36)
                    Image(systemName: ficha.icon)
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(Color.nexoBrand)
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(ficha.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .label))
                    HStack(spacing: 6) {
                        Text(ficha.route)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                        Text("·")
                            .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        Text(ficha.value)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(hex: "7A5F00"))
                    }
                }

                Spacer()

                // Fecha
                Text(ficha.fecha, style: .date)
                    .font(.system(size: 10, weight: .light))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
            .padding(Sp.md)
            .background(
                isSelected ? Color.nexoMint.opacity(0.3) : Color(uiColor: .systemBackground),
                in: RoundedRectangle(cornerRadius: Rd.lg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Rd.lg)
                    .strokeBorder(
                        isSelected ? Color.nexoBrand.opacity(0.4) : Color(uiColor: .separator),
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
            .animation(.easeOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Borrar", systemImage: "trash")
            }
        }
    }
}

// MARK: - ActivaRow

struct ActivaRow: View {
    let ficha    : FichaRegistro
    let onRecoger: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.nexoGreen.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: ficha.icon)
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(Color.nexoGreen)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(ficha.displayName)
                    .font(.system(size: 14, weight: .semibold))
                HStack(spacing: 5) {
                    Circle().fill(Color.nexoGreen).frame(width: 5, height: 5)
                    Text("En el mapa")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.nexoGreen)
                    Text("·")
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    Text(ficha.fecha, style: .date)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                }
            }

            Spacer()

            Text(ficha.value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: "7A5F00"))
        }
        .padding(Sp.md)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.lg))
        .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
        .swipeActions(edge: .trailing) {
            Button(action: onRecoger) {
                Label("Recogida", systemImage: "checkmark.circle")
            }
            .tint(Color.nexoBrand)
        }
    }
}

// MARK: - RecogidaRow

struct RecogidaRow: View {
    let ficha: FichaRegistro
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(uiColor: .systemGray5))
                    .frame(width: 36, height: 36)
                Image(systemName: ficha.icon)
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(ficha.displayName)
                    .font(.system(size: 14, weight: .semibold))
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.nexoBrand)
                    Text("Recogida")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.nexoBrand)
                    Text("·")
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    Text(ficha.co2)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
            }

            Spacer()

            Text(ficha.fecha, style: .date)
                .font(.system(size: 10))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .padding(Sp.md)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.lg))
        .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
    }
}

#Preview("Historial") {
    HistorialView()
        .environmentObject(ListingsRepository())
        .modelContainer(for: FichaRegistro.self, inMemory: true)
}
