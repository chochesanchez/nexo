// HistorialView.swift
import SwiftUI
import SwiftData

@Model
final class FichaRegistro {
    var classKey    : String
    var displayName : String
    var icon        : String
    var route       : String
    var co2         : String
    var water       : String
    var fecha       : Date

    init(material: NEXOMaterial) {
        self.classKey    = material.classKey
        self.displayName = material.displayName
        self.icon        = material.icon
        self.route       = material.route.rawValue
        self.co2         = material.co2
        self.water       = material.water
        self.fecha       = Date()
    }
}

struct HistorialView: View {
    @Query(sort: \FichaRegistro.fecha, order: .reverse) private var registros: [FichaRegistro]
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Group {
                if registros.isEmpty { emptyState }
                else {
                    ScrollView {
                        VStack(spacing: Sp.md) { impactSummary; listadoRegistros }
                            .padding(Sp.lg)
                    }
                }
            }
            .navigationTitle("Tu impacto")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !registros.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) { registros.forEach { context.delete($0) } } label: {
                            Image(systemName: "trash").foregroundStyle(.red)
                        }.accessibilityLabel("Borrar historial")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Sp.lg) {
            Image(systemName: "clock.arrow.circlepath").font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.nexoGreen.opacity(0.5))
            Text("Sin registros aún").font(.system(size: 20, weight: .bold, design: .rounded))
            Text("Escanea tu primer residuo\npara empezar a ver tu impacto.")
                .font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    private var impactSummary: some View {
        VStack(alignment: .leading, spacing: Sp.md) {
            Text("Esta semana").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                .textCase(.uppercase).kerning(0.6)
            HStack(spacing: Sp.sm) {
                summaryCell(icon: "arrow.3.trianglepath", label: "Materiales", value: "\(registros.count)", color: Color.nexoGreen)
                summaryCell(icon: "wind", label: "CO₂ evitado", value: co2Total, color: Color(hex: "6DB33F"))
            }
        }
    }

    private func summaryCell(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
                Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            }
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(Sp.md)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Rd.md))
        .accessibilityElement(children: .combine).accessibilityLabel("\(label): \(value)")
    }

    private var listadoRegistros: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            Text("Registros").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                .textCase(.uppercase).kerning(0.6)
            VStack(spacing: Sp.xs) { ForEach(registros) { registroRow($0) } }
        }
    }

    private func registroRow(_ reg: FichaRegistro) -> some View {
        HStack(spacing: Sp.md) {
            ZStack {
                Circle().fill(Color.nexoGreen.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: reg.icon).font(.system(size: 18)).foregroundStyle(Color.nexoGreen)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(reg.displayName).font(.system(size: 15, weight: .semibold))
                Text(reg.route).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
            Text(reg.fecha, style: .date).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(Sp.md).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Rd.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reg.displayName), \(reg.route), \(reg.fecha.formatted(date: .abbreviated, time: .omitted))")
    }

    private var co2Total: String {
        let nums = registros.compactMap { reg -> Double? in
            let digits = reg.co2.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            return Double(digits)
        }
        let total = nums.reduce(0, +)
        return total >= 1000 ? String(format: "%.1f kg", total / 1000) : "\(Int(total)) g"
    }
}
