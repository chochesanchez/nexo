//
//  Bulkvaluecalculator.swift
//  nexo
//
//  Created by Guillermo Lira on 05/05/26.
//

// BulkValueCalculator.swift
// Calcula el valor económico estimado de un lote de materiales recolectados.
// Los precios son de referencia según mercado informal CDMX (SEMARNAT 2023).

import SwiftUI

// MARK: - Precio por unidad (rango conservador–optimista en MXN)

struct PrecioUnitario {
    let bajo  : Double   // precio mínimo por unidad
    let alto  : Double   // precio máximo por unidad
    let unidad: String   // descripción de la unidad
    let nota  : String   // contexto del precio
}

enum BulkValueCalculator {

    private static let precios: [String: PrecioUnitario] = [
        "pet_bottle": PrecioUnitario(
            bajo  : 0.30,
            alto  : 1.00,
            unidad: "botella",
            nota  : "Precio sube si están limpias y aplastadas"
        ),
        "aluminum_can": PrecioUnitario(
            bajo  : 0.50,
            alto  : 1.20,
            unidad: "lata",
            nota  : "El aluminio es el material más rentable por kg"
        ),
        "cardboard_box": PrecioUnitario(
            bajo  : 0.50,
            alto  : 2.50,
            unidad: "caja",
            nota  : "Precio varía según tamaño y si está seca"
        ),
        "glass_bottle": PrecioUnitario(
            bajo  : 0.05,
            alto  : 0.30,
            unidad: "botella",
            nota  : "Bajo valor unitario — rentable en volumen"
        ),
        "organic_simple": PrecioUnitario(
            bajo  : 0.00,
            alto  : 0.00,
            unidad: "kg",
            nota  : "Sin valor monetario directo para el recolector"
        ),
        "battery_electronic": PrecioUnitario(
            bajo  : 0.00,
            alto  : 50.00,
            unidad: "pieza",
            nota  : "Muy variable: cables valen poco, smartphones más"
        ),
    ]

    // MARK: - Resultado de cálculo bulk

    struct BulkResult {
        let items          : [String: Int]   // classKey → cantidad
        let valorBajo      : Double
        let valorAlto      : Double
        let co2TotalGramos : Double
        let categorias     : Int

        var valorDisplay: String {
            if valorAlto == 0 { return "Sin valor monetario directo" }
            if valorBajo == valorAlto {
                return String(format: "$%.0f MXN", valorBajo)
            }
            return String(format: "$%.0f – $%.0f MXN", valorBajo, valorAlto)
        }

        var co2Display: String {
            co2TotalGramos >= 1000
                ? String(format: "%.1f kg CO₂", co2TotalGramos / 1000)
                : "\(Int(co2TotalGramos)) g CO₂"
        }

        var totalPiezas: Int { items.values.reduce(0, +) }

        var impactoNarrativa: String {
            let piezas = totalPiezas
            if piezas == 0 { return "" }
            if piezas == 1 { return "1 material recuperado" }
            if piezas < 5  { return "\(piezas) materiales — pequeño impacto local" }
            if piezas < 10 { return "\(piezas) materiales — ruta rentable" }
            return "\(piezas) materiales — ruta de alto impacto"
        }
    }

    // MARK: - Calcular desde lista de pines

    static func calcular(desde pines: [FichaPin]) -> BulkResult {
        var itemsPorCategoria: [String: Int] = [:]
        var co2Total: Double = 0

        for pin in pines {
            itemsPorCategoria[pin.material.classKey, default: 0] += 1
            let co2 = Double(pin.material.co2
                .components(separatedBy: CharacterSet.decimalDigits.inverted)
                .joined()) ?? 0
            co2Total += co2
        }

        var valorBajoTotal = 0.0
        var valorAltoTotal = 0.0

        for (classKey, cantidad) in itemsPorCategoria {
            let precio = precios[classKey] ?? PrecioUnitario(bajo: 0, alto: 0, unidad: "pieza", nota: "")
            valorBajoTotal += precio.bajo * Double(cantidad)
            valorAltoTotal += precio.alto * Double(cantidad)
        }

        return BulkResult(
            items          : itemsPorCategoria,
            valorBajo      : valorBajoTotal,
            valorAlto      : valorAltoTotal,
            co2TotalGramos : co2Total,
            categorias     : itemsPorCategoria.keys.count
        )
    }

    // MARK: - Info de precio por material

    static func info(para classKey: String) -> PrecioUnitario? {
        precios[classKey]
    }
}

// MARK: - Vista del resumen bulk (se muestra en RecolectorView)

struct BulkValuePanel: View {
    let result     : BulkValueCalculator.BulkResult
    let onDescargar: () -> Void   // ir al centro de acopio más cercano

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Resumen de ruta")
                        .font(.system(size: 12, weight: .semibold)).tracking(0.3)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                    Text(result.impactoNarrativa)
                        .font(.system(size: 16, weight: .bold)).tracking(-0.5)
                        .foregroundStyle(Color(uiColor: .label))
                }
                Spacer()
                // Badge de piezas
                Text("\(result.totalPiezas)")
                    .font(.system(size: 20, weight: .black)).tracking(-1)
                    .foregroundStyle(Color.nexoBrand)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.nexoMint, in: RoundedRectangle(cornerRadius: 8))
            }

            // Métricas en grid
            HStack(spacing: 8) {
                bulkMetric(
                    icon : "tag.fill",
                    label: "Valor estimado",
                    value: result.valorDisplay,
                    color: result.valorAlto > 0 ? Color(hex: "7A5F00") : Color(uiColor: .secondaryLabel),
                    bg   : result.valorAlto > 0 ? Color(hex: "FFFCE8") : Color(uiColor: .systemGray6)
                )
                bulkMetric(
                    icon : "wind",
                    label: "CO₂ evitado",
                    value: result.co2Display,
                    color: Color.nexoBrand,
                    bg   : Color.nexoMint.opacity(0.5)
                )
            }

            // Breakdown por categoría
            if result.items.count > 1 {
                VStack(spacing: 4) {
                    ForEach(result.items.sorted(by: { $0.value > $1.value }), id: \.key) { key, count in
                        if let mat = NEXOMaterial.all[key] {
                            HStack(spacing: 8) {
                                Image(systemName: mat.icon)
                                    .font(.system(size: 11)).foregroundStyle(mat.accent)
                                    .frame(width: 16)
                                Text(mat.displayName)
                                    .font(.system(size: 12)).foregroundStyle(Color(uiColor: .label))
                                Spacer()
                                Text("×\(count)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                                if let precio = BulkValueCalculator.info(para: key), precio.alto > 0 {
                                    Text(String(format: "$%.0f–$%.0f",
                                                precio.bajo * Double(count),
                                                precio.alto * Double(count)))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color(hex: "7A5F00"))
                                }
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color(uiColor: .systemGray6), in: RoundedRectangle(cornerRadius: 8))
            }

            // CTA — ir a centro de acopio
            Button(action: onDescargar) {
                HStack(spacing: 8) {
                    Image(systemName: "building.2.fill").font(.system(size: 13, weight: .semibold))
                    Text("Ver centro de acopio más cercano")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color(hex: "1565C0"))
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(Color(hex: "E3F2FD"), in: RoundedRectangle(cornerRadius: Rd.lg))
                .overlay(RoundedRectangle(cornerRadius: Rd.lg)
                    .strokeBorder(Color(hex: "1565C0").opacity(0.2), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(Sp.lg)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Rd.lg))
        .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func bulkMetric(icon: String, label: String, value: String,
                             color: Color, bg: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundStyle(color)
                Text(label).font(.system(size: 9, weight: .semibold)).tracking(0.3)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
            Text(value).font(.system(size: 13, weight: .bold)).tracking(-0.3).foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(bg, in: RoundedRectangle(cornerRadius: 8))
    }
}
