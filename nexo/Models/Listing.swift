import Foundation

struct Listing: Codable, Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let material: String
    let quantityLabel: String?
    let notes: String?
    let lat: Double
    let lng: Double
    let status: String
    let claimedBy: UUID?
    let classKey: String?
    let displayName: String?
    let icon: String?
    let route: String?
    let co2: String?
    let water: String?
    let value: String?
    let fmInstruction: String?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt     = "created_at"
        case material
        case quantityLabel = "quantity_label"
        case notes
        case lat, lng, status
        case claimedBy     = "claimed_by"
        case classKey      = "class_key"
        case displayName   = "display_name"
        case icon, route, co2, water, value
        case fmInstruction = "fm_instruction"
    }
}

struct NewListing: Encodable {
    let material: String
    let quantityLabel: String?
    let notes: String?
    let lat: Double
    let lng: Double
    let classKey: String?
    let displayName: String?
    let icon: String?
    let route: String?
    let co2: String?
    let water: String?
    let value: String?
    let fmInstruction: String?

    enum CodingKeys: String, CodingKey {
        case material
        case quantityLabel = "quantity_label"
        case notes
        case lat, lng
        case classKey      = "class_key"
        case displayName   = "display_name"
        case icon, route, co2, water, value
        case fmInstruction = "fm_instruction"
    }
}

struct ScanRecord: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let material: String
    let imageUrl: String?
    let ocrText: String?
    let classKey: String?
    let displayName: String?
    let icon: String?
    let route: String?
    let co2: String?
    let water: String?
    let value: String?
    let smellTip: String?
    let instructions: [String]?
    let fmInstruction: String?
    let lat: Double?
    let lng: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt     = "created_at"
        case material
        case imageUrl      = "image_url"
        case ocrText       = "ocr_text"
        case classKey      = "class_key"
        case displayName   = "display_name"
        case icon, route, co2, water, value
        case smellTip      = "smell_tip"
        case instructions
        case fmInstruction = "fm_instruction"
        case lat, lng
    }
}

struct NewScanRecord: Encodable {
    let userId: UUID
    let material: String
    let imageUrl: String?
    let ocrText: String?
    let lat: Double?
    let lng: Double?
    let classKey: String?
    let displayName: String?
    let icon: String?
    let route: String?
    let co2: String?
    let water: String?
    let value: String?
    let smellTip: String?
    let instructions: [String]?
    let fmInstruction: String?

    enum CodingKeys: String, CodingKey {
        case userId        = "user_id"
        case material
        case imageUrl      = "image_url"
        case ocrText       = "ocr_text"
        case lat, lng
        case classKey      = "class_key"
        case displayName   = "display_name"
        case icon, route, co2, water, value
        case smellTip      = "smell_tip"
        case instructions
        case fmInstruction = "fm_instruction"
    }
}

struct CentroAcopio: Codable, Identifiable, Hashable {
    let id: String
    let nombre: String
    let tipo: String
    let direccion: String
    let alcaldia: String?
    let codigoPostal: String?
    let telefono: String?
    let email: String?
    let materiales: [String]
    let lat: Double
    let lng: Double
    let horario: String?
    let fuente: String?
    let notas: String?

    enum CodingKeys: String, CodingKey {
        case id, nombre, tipo, direccion, alcaldia
        case codigoPostal = "codigo_postal"
        case telefono, email, materiales
        case lat, lng
        case horario, fuente, notas
    }
}
