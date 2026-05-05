//
//  Centrosacopio.swift
//  nexo
//
//  Created by Guillermo Lira on 05/05/26.
//

// CentrosAcopio.swift
// Centros de acopio reales en CDMX + modelo de datos para el mapa.
// Fuentes: SEDEMA CDMX, Puntos Limpios, ELECTRORECICLA, datos.cdmx.gob.mx

import SwiftUI
import CoreLocation
import Combine

// MARK: - Tipo de centro

enum TipoAcopio: String, CaseIterable {
    case general     = "Centro general"
    case electronico = "Electrónicos"
    case aceite      = "Aceite usado"
    case baterias    = "Baterías"
    case organico    = "Orgánicos"

    var icon: String {
        switch self {
        case .general:     return "building.2.fill"
        case .electronico: return "bolt.fill"
        case .aceite:      return "drop.fill"
        case .baterias:    return "battery.100.bolt"
        case .organico:    return "leaf.fill"
        }
    }

    var color: Color {
        switch self {
        case .general:     return Color(hex: "1565C0")
        case .electronico: return Color(hex: "E53935")
        case .aceite:      return Color(hex: "F9A825")
        case .baterias:    return Color(hex: "6A1B9A")
        case .organico:    return Color(hex: "2E7D32")
        }
    }
}

// MARK: - Centro de acopio

struct PuntoReciclaje: Identifiable {
    let id         = UUID()
    let nombre     : String
    let tipo       : TipoAcopio
    let coordinate : CLLocationCoordinate2D
    let materiales : [String]    // qué acepta
    let horario    : String
    let telefono   : String?
}

// MARK: - Datos estáticos CDMX

extension CentroAcopio {
    static let cdmxAll: [PuntoReciclaje] = [

        // ── Puntos Limpios SEDEMA ──────────────────────────────────────────
        PuntoReciclaje(
            nombre     : "Punto Limpio Iztapalapa",
            tipo       : .general,
            coordinate : CLLocationCoordinate2D(latitude: 19.3556, longitude: -99.0619),
            materiales : ["PET", "Cartón", "Aluminio", "Vidrio", "Electrónicos"],
            horario    : "Lun–Sáb 8–17h",
            telefono   : "55 5686 1354"
        ),
        PuntoReciclaje(
            nombre     : "Punto Limpio Coyoacán",
            tipo       : .general,
            coordinate : CLLocationCoordinate2D(latitude: 19.3467, longitude: -99.1617),
            materiales : ["PET", "Cartón", "Aluminio", "Vidrio"],
            horario    : "Lun–Sáb 8–17h",
            telefono   : nil
        ),
        PuntoReciclaje(
            nombre     : "Punto Limpio Xochimilco",
            tipo       : .general,
            coordinate : CLLocationCoordinate2D(latitude: 19.2569, longitude: -99.1039),
            materiales : ["PET", "Cartón", "Aluminio", "Vidrio", "Orgánicos"],
            horario    : "Lun–Sáb 8–17h",
            telefono   : nil
        ),
        PuntoReciclaje(
            nombre     : "Punto Limpio Tlalpan",
            tipo       : .general,
            coordinate : CLLocationCoordinate2D(latitude: 19.2924, longitude: -99.1635),
            materiales : ["PET", "Cartón", "Aluminio", "Vidrio"],
            horario    : "Lun–Sáb 8–17h",
            telefono   : nil
        ),
        PuntoReciclaje(
            nombre     : "Punto Limpio Gustavo A. Madero",
            tipo       : .general,
            coordinate : CLLocationCoordinate2D(latitude: 19.4891, longitude: -99.1048),
            materiales : ["PET", "Cartón", "Aluminio", "Vidrio"],
            horario    : "Lun–Sáb 8–17h",
            telefono   : nil
        ),
        PuntoReciclaje(
            nombre     : "Punto Limpio Benito Juárez",
            tipo       : .general,
            coordinate : CLLocationCoordinate2D(latitude: 19.3866, longitude: -99.1570),
            materiales : ["PET", "Cartón", "Aluminio", "Vidrio"],
            horario    : "Lun–Sáb 8–17h",
            telefono   : nil
        ),
        PuntoReciclaje(
            nombre     : "Punto Limpio Miguel Hidalgo",
            tipo       : .general,
            coordinate : CLLocationCoordinate2D(latitude: 19.4284, longitude: -99.1971),
            materiales : ["PET", "Cartón", "Aluminio", "Vidrio"],
            horario    : "Lun–Sáb 8–17h",
            telefono   : nil
        ),

        // ── Electrónicos ──────────────────────────────────────────────────
        PuntoReciclaje(
            nombre     : "ELECTRORECICLA Insurgentes",
            tipo       : .electronico,
            coordinate : CLLocationCoordinate2D(latitude: 19.3997, longitude: -99.1716),
            materiales : ["Celulares", "Laptops", "Baterías de litio", "Cables", "Pantallas"],
            horario    : "Lun–Vie 9–18h, Sáb 10–14h",
            telefono   : "55 5511 4423"
        ),
        PuntoReciclaje(
            nombre     : "Reciclatrón UNAM",
            tipo       : .electronico,
            coordinate : CLLocationCoordinate2D(latitude: 19.3275, longitude: -99.1816),
            materiales : ["Todo tipo de electrónicos", "Baterías", "Cables"],
            horario    : "Sáb y Dom 9–15h (mensual)",
            telefono   : nil
        ),

        // ── Aceite usado ──────────────────────────────────────────────────
        PuntoReciclaje(
            nombre     : "Acopio Aceite – Alcaldía Cuauhtémoc",
            tipo       : .aceite,
            coordinate : CLLocationCoordinate2D(latitude: 19.4284, longitude: -99.1411),
            materiales : ["Aceite vegetal usado", "Aceite de motor"],
            horario    : "Lun–Vie 9–17h",
            telefono   : nil
        ),
        PuntoReciclaje(
            nombre     : "Acopio Aceite – Iztacalco",
            tipo       : .aceite,
            coordinate : CLLocationCoordinate2D(latitude: 19.3895, longitude: -99.1050),
            materiales : ["Aceite vegetal usado"],
            horario    : "Mar y Jue 10–15h",
            telefono   : nil
        ),

        // ── Baterías ──────────────────────────────────────────────────────
        PuntoReciclaje(
            nombre     : "Acopio Pilas – IKEA Coyoacán",
            tipo       : .baterias,
            coordinate : CLLocationCoordinate2D(latitude: 19.3317, longitude: -99.1688),
            materiales : ["Pilas AA/AAA", "Baterías recargables", "Baterías de botón"],
            horario    : "Todos los días 10–21h",
            telefono   : nil
        ),
        PuntoReciclaje(
            nombre     : "Acopio Pilas – Plaza Satélite",
            tipo       : .baterias,
            coordinate : CLLocationCoordinate2D(latitude: 19.5223, longitude: -99.2165),
            materiales : ["Pilas AA/AAA", "Baterías recargables"],
            horario    : "Todos los días 11–21h",
            telefono   : nil
        ),

        // ── Orgánicos / Composta ──────────────────────────────────────────
        PuntoReciclaje(
            nombre     : "Composta Comunitaria Xochimilco",
            tipo       : .organico,
            coordinate : CLLocationCoordinate2D(latitude: 19.2612, longitude: -99.0965),
            materiales : ["Restos de comida", "Cáscaras", "Pasto y hojas"],
            horario    : "Sáb 8–12h",
            telefono   : nil
        ),
        PuntoReciclaje(
            nombre     : "Composta Parque México",
            tipo       : .organico,
            coordinate : CLLocationCoordinate2D(latitude: 19.4128, longitude: -99.1717),
            materiales : ["Restos vegetales", "Hojas secas", "Café y té"],
            horario    : "Dom 9–13h",
            telefono   : nil
        ),
    ]

    /// Filtra centros dentro de un radio en km
    static func cercanos(a coordinate: CLLocationCoordinate2D, radioKm: Double = 10) -> [PuntoReciclaje] {
        let origen = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return cdmxAll.filter { centro in
            let destino = CLLocation(latitude: centro.coordinate.latitude,
                                     longitude: centro.coordinate.longitude)
            return origen.distance(from: destino) <= radioKm * 1000
        }
    }
}

// MARK: - Anotación visual del centro en el mapa

struct PuntoReciclajePin: View {
    let centro   : PuntoReciclaje
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: isSelected ? 10 : 7)
                    .fill(centro.tipo.color)
                    .frame(width: isSelected ? 36 : 26,
                           height: isSelected ? 36 : 26)
                    .shadow(color: centro.tipo.color.opacity(0.4), radius: isSelected ? 6 : 3)

                Image(systemName: centro.tipo.icon)
                    .font(.system(size: isSelected ? 16 : 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            // Cola
            Triangle()
                .fill(centro.tipo.color)
                .frame(width: isSelected ? 8 : 6, height: isSelected ? 5 : 4)
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
