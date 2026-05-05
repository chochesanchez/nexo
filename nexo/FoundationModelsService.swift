// FoundationModelsService.swift
// Versión corregida para iOS 26 / Xcode 16+
// La API de Foundation Models recibe String directamente, no un tipo Prompt().
// La disponibilidad se verifica con model.isAvailable (Bool), no con un switch.

// FoundationModelsService.swift
import Foundation
import FoundationModels
import Combine

final class FoundationModelsService: ObservableObject {

    static let shared = FoundationModelsService()
    @Published var isGenerating     = false
    @Published var isGeneratingFact = false

    private init() {}

    // MARK: - 1. Instrucción de preparación (sin cambios)

    @MainActor
    func generarInstruccion(material: NEXOMaterial, textoOCR: String? = nil) async -> String {
        let model = SystemLanguageModel.default
        guard model.isAvailable else { return fallbackInstruccion(material) }

        isGenerating = true
        defer { isGenerating = false }

        let contextoTexto = textoOCR.map { "Texto visible en la etiqueta: \"\($0)\"." } ?? ""
        let instrBase = material.instructions.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        let smellBase = material.smellTip.map { "\nConsejo de olor: \($0)" } ?? ""

        let prompt = """
        Eres un asistente de reciclaje amigable en México. \
        Reescribe estas instrucciones en español mexicano coloquial, \
        sin tecnicismos, sin bullets, en texto corrido, máximo dos oraciones.

        Material: \(material.displayName)
        Ruta: \(material.route.rawValue)
        Instrucciones base:
        \(instrBase)\(smellBase)
        \(contextoTexto)

        Responde SOLO con las instrucciones reescritas. Sin saludos ni explicaciones.
        """

        do {
            let session = LanguageModelSession(
                instructions: "Eres un asistente de reciclaje en México. Siempre en español mexicano coloquial."
            )
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? fallbackInstruccion(material) : text
        } catch {
            return fallbackInstruccion(material)
        }
    }

    // MARK: - 2. Fact contextual de impacto ambiental ← NUEVO

    /// Genera un dato de impacto ambiental específico al material,
    /// usando estadísticas reales de México (SEMARNAT, INEGI, WEF).
    /// Máximo 2 oraciones. Primera persona plural. Memorable y concreto.
    @MainActor
    func generarFact(material: NEXOMaterial) async -> String? {
        let model = SystemLanguageModel.default
        guard model.isAvailable else { return fallbackFact(material) }

        isGeneratingFact = true
        defer { isGeneratingFact = false }

        let prompt = factPrompt(for: material)

        do {
            let session = LanguageModelSession(
                instructions: """
                Eres un experto en medio ambiente en México con acceso a datos de SEMARNAT, \
                INEGI, WEF y PNUMA. Generas datos impactantes, concretos y verificables \
                sobre reciclaje en México. Nunca inventas números. \
                Usas primera persona plural. Máximo 2 oraciones. Sin hashtags ni emojis.
                """
            )
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? fallbackFact(material) : text
        } catch {
            return fallbackFact(material)
        }
    }

    // MARK: - Prompts específicos por material

    private func factPrompt(for material: NEXOMaterial) -> String {
        switch material.classKey {

        case "pet_bottle":
            return """
            Genera UN dato de impacto sobre reciclar botellas PET en México. \
            Incluye: México produce 900,000 toneladas de PET al año, \
            solo recicla el 58%, reciclar 1 kg ahorra 1.5 kg de CO₂, \
            1 botella reciclada = energía para cargar un teléfono 3 veces. \
            Sé específico con un número memorable. Máximo 2 oraciones.
            """

        case "aluminum_can":
            return """
            Genera UN dato de impacto sobre reciclar latas de aluminio en México. \
            Incluye: reciclar aluminio usa 95% menos energía que producirlo nuevo, \
            una lata reciclada en 60 días vuelve a ser lata en tienda, \
            México recicla solo el 40% de su aluminio. \
            Elige el dato más impactante. Máximo 2 oraciones.
            """

        case "cardboard_box":
            return """
            Genera UN dato de impacto sobre reciclar cartón en México. \
            Incluye: reciclar 1 tonelada de cartón salva 17 árboles y \
            ahorra 26,500 litros de agua, México genera 4 millones de \
            toneladas de papel y cartón al año. \
            Elige el dato más visual y concreto. Máximo 2 oraciones.
            """

        case "glass_bottle":
            return """
            Genera UN dato de impacto sobre reciclar vidrio en México. \
            Incluye: el vidrio es 100% reciclable infinitas veces sin perder calidad, \
            reciclar 1 botella ahorra energía para encender un foco LED 4 horas, \
            México recicla solo el 25% de su vidrio. \
            Máximo 2 oraciones. Primera persona plural.
            """

        case "organic_simple":
            return """
            Genera UN dato de impacto sobre residuos orgánicos en México. \
            Incluye: el 52% de los residuos en México son orgánicos, \
            solo el 1.7% se compostan, si todos compostan en casa \
            reducirían el peso de su basura a la mitad, \
            1 kg de composta reemplaza fertilizante químico. \
            Máximo 2 oraciones.
            """

        case "battery_electronic":
            return """
            Genera UN dato de impacto sobre residuos electrónicos en México. \
            Incluye: México genera 1.1 millones de toneladas de basura electrónica \
            al año (4to lugar en América Latina), menos del 10% se recicla \
            correctamente, una batería de litio puede contaminar \
            600,000 litros de agua subterránea. \
            Elige el dato más urgente. Máximo 2 oraciones.
            """

        default:
            return """
            Genera UN dato de impacto sobre reciclaje de \(material.displayName) en México. \
            Usa estadísticas reales de SEMARNAT o INEGI. \
            Sé concreto con números memorables. \
            Primera persona plural. Máximo 2 oraciones.
            """
        }
    }

    // MARK: - Fallbacks (cuando Foundation Models no está disponible)

    private func fallbackInstruccion(_ material: NEXOMaterial) -> String {
        material.instructions.joined(separator: ". ") + "."
    }

    private func fallbackFact(_ material: NEXOMaterial) -> String? {
        // Datos hardcodeados de respaldo — fuente: SEMARNAT 2023 / WEF 2024
        let facts: [String: String] = [
            "pet_bottle"       : "México produce 900,000 toneladas de PET al año pero solo recicla el 58%. Reciclar esta botella equivale a ahorrar la energía de cargar 3 teléfonos.",
            "aluminum_can"     : "Reciclar aluminio usa 95% menos energía que producirlo desde cero. En 60 días esta lata puede volver a estar en un anaquel.",
            "cardboard_box"    : "Reciclar una tonelada de cartón salva 17 árboles y 26,500 litros de agua. México desperdicia millones de toneladas de cartón cada año.",
            "glass_bottle"     : "El vidrio es el único material 100% reciclable infinitas veces sin perder calidad. México solo recicla el 25% del suyo.",
            "organic_simple"   : "El 52% de nuestra basura en México es orgánica pero solo el 1.7% se composta. Si la compostas, produces fertilizante gratis y reduces tu basura a la mitad.",
            "battery_electronic": "México genera 1.1 millones de toneladas de basura electrónica al año. Una sola batería de litio puede contaminar hasta 600,000 litros de agua subterránea."
        ]
        return facts[material.classKey]
    }
}
