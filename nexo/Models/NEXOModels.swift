// NEXOModels.swift
// Enumeraciones, modelos de datos y mapeo de etiquetas de Vision.

import SwiftUI

// MARK: - App Mode
enum AppMode: String, CaseIterable {
    case hogar      = "Hogar"
    case recolector = "Recolector"
}

// MARK: - Material Route
enum MaterialRoute: String {
    case reciclaje      = "Reciclaje"
    case composta       = "Composta"
    case acopioEspecial = "Acopio especial"

    var icon: String {
        switch self {
        case .reciclaje:      return "arrow.3.trianglepath"
        case .composta:       return "leaf.fill"
        case .acopioEspecial: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .reciclaje:      return .nexoGreen
        case .composta:       return Color(hex: "6DB33F")
        case .acopioEspecial: return .nexoAmber
        }
    }
}

// MARK: - NEXO Material
struct NEXOMaterial: Identifiable, Equatable {
    let id          = UUID()
    let classKey    : String
    let displayName : String
    let icon        : String
    let accent      : Color
    let route       : MaterialRoute
    let instructions: [String]
    let value       : String
    let co2         : String
    let water       : String
    let smellTip    : String?

    static func == (lhs: NEXOMaterial, rhs: NEXOMaterial) -> Bool { lhs.id == rhs.id }

    var voiceText: String {
        var t = "Detecté \(displayName). Ruta: \(route.rawValue). "
        t += instructions.joined(separator: ". ")
        t += ". Valor estimado: \(value)."
        return t
    }
}

// MARK: - Material Library
extension NEXOMaterial {

    static let all: [String: NEXOMaterial] = [
        "pet_bottle": .init(
            classKey: "pet_bottle", displayName: "Botella PET",
            icon: "waterbottle.fill", accent: .nexoBlue, route: .reciclaje,
            instructions: ["Vacía el contenido por completo","Enjuaga brevemente con agua","Aplasta para reducir volumen"],
            value: "$1.50 MXN/kg", co2: "60 g CO₂", water: "0.5 L",
            smellTip: "Si quedó líquido, deja escurrir boca abajo 2 min antes de guardar."
        ),
        "aluminum_can": .init(
            classKey: "aluminum_can", displayName: "Lata de aluminio",
            icon: "cylinder.fill", accent: Color(hex: "9E9E9E"), route: .reciclaje,
            instructions: ["Vacía y enjuaga brevemente","Aplasta con el pie para ahorrar espacio","Junta varias antes de entregar"],
            value: "$18 MXN/kg", co2: "95 g CO₂", water: "1.2 L",
            smellTip: "El azúcar residual genera olor rápido — enjuaga aunque sea poco."
        ),
        "cardboard_box": .init(
            classKey: "cardboard_box", displayName: "Cartón",
            icon: "shippingbox.fill", accent: Color(hex: "C8A97E"), route: .reciclaje,
            instructions: ["Aplana completamente la caja","Retira cinta adhesiva si es posible","Mantén seco — el cartón húmedo pierde todo su valor"],
            value: "$1.20 MXN/kg", co2: "45 g CO₂", water: "0.8 L",
            smellTip: nil
        ),
        "glass_bottle": .init(
            classKey: "glass_bottle", displayName: "Botella de vidrio",
            icon: "wineglass.fill", accent: .nexoGreen, route: .reciclaje,
            instructions: ["Vacía el contenido","No necesita lavado profundo","Maneja con cuidado — no mezcles vidrio roto"],
            value: "$0.50 MXN/kg", co2: "300 g CO₂", water: "2.0 L",
            smellTip: nil
        ),
        "organic_simple": .init(
            classKey: "organic_simple", displayName: "Residuo orgánico",
            icon: "leaf.fill", accent: Color(hex: "6DB33F"), route: .composta,
            instructions: ["Separa de plásticos y envoltorios","Junta cáscaras, frutas y café usado","Guarda en recipiente con tapa"],
            value: "Sin valor monetario directo", co2: "120 g CO₂ equiv.", water: "—",
            smellTip: "Si no lo entregas en 24 h, guárdalo en el congelador para evitar fermentación."
        ),
        "battery_electronic": .init(
            classKey: "battery_electronic", displayName: "Batería o electrónico",
            icon: "bolt.fill", accent: .nexoAmber, route: .acopioEspecial,
            instructions: ["No aplastes ni perforés — riesgo de fuego","No mojes — puede generar gases tóxicos","Lleva a punto de acopio especial"],
            value: "Requiere acopio especial", co2: "Variable", water: "—",
            smellTip: nil
        )
    ]

    // MARK: - Vision label → NEXOMaterial
    static func from(visionLabel: String) -> NEXOMaterial? {
        let label = visionLabel.lowercased()
        let mapping: [(keys: [String], classKey: String)] = [
            (["bottle","water bottle","plastic","pet","jug","container"],   "pet_bottle"),
            (["can","tin","aluminum","beverage","soda","beer"],             "aluminum_can"),
            (["cardboard","box","carton","package","parcel"],              "cardboard_box"),
            (["wine","glass bottle","jar","mason","flask","vase"],         "glass_bottle"),
            (["banana","apple","orange","fruit","lemon","food","vegetable","peel","mango","avocado","tomato"], "organic_simple"),
            (["phone","mobile","cell","laptop","battery","electronic","earphone","remote","tablet","charger","vape","headphone","keyboard"], "battery_electronic"),
        ]
        for (keys, classKey) in mapping {
            if keys.contains(where: { label.contains($0) }) { return all[classKey] }
        }
        return nil
    }

    // MARK: - Supabase material string → NEXOMaterial
    static func from(supabaseMaterial: String) -> NEXOMaterial? {
        let m = supabaseMaterial.lowercased()
        if m.contains("pet") || m.contains("plástico") || m.contains("plastico") || m.contains("botella") { return all["pet_bottle"] }
        if m.contains("lata") || m.contains("aluminio") || m.contains("metal") { return all["aluminum_can"] }
        if m.contains("cartón") || m.contains("carton") || m.contains("caja") { return all["cardboard_box"] }
        if m.contains("vidrio") || m.contains("glass") { return all["glass_bottle"] }
        if m.contains("orgánico") || m.contains("organico") || m.contains("compost") { return all["organic_simple"] }
        if m.contains("batería") || m.contains("bateria") || m.contains("electrónico") || m.contains("electronico") { return all["battery_electronic"] }
        return nil
    }
}
