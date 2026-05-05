// FoundationModelsService.swift
// Versión corregida para iOS 26 / Xcode 16+
// La API de Foundation Models recibe String directamente, no un tipo Prompt().
// La disponibilidad se verifica con model.isAvailable (Bool), no con un switch.

import Foundation
import FoundationModels
import Combine

final class FoundationModelsService: ObservableObject {

    static let shared = FoundationModelsService()

    @Published var isGenerating = false

    private init() {}

    // MARK: - Generar instrucción en lenguaje natural

    /// Recibe un NEXOMaterial y texto OCR opcional capturado por VNRecognizeTextRequest,
    /// y retorna instrucciones redactadas en español mexicano coloquial.
    /// Si Foundation Models no está disponible, regresa el fallback hardcodeado.
    @MainActor
    func generarInstruccion(material: NEXOMaterial, textoOCR: String? = nil) async -> String {
        // Verificar disponibilidad del modelo on-device
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            return fallback(material)
        }

        isGenerating = true
        defer { isGenerating = false }

        let contextoTexto: String
        if let ocr = textoOCR, !ocr.trimmingCharacters(in: .whitespaces).isEmpty {
            contextoTexto = "Texto visible en la etiqueta: \"\(ocr)\"."
        } else {
            contextoTexto = ""
        }

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
                instructions: "Eres un asistente de reciclaje en México. Siempre respondes en español mexicano coloquial, sin tecnicismos."
            )
            // Se pasa el prompt como String directamente (sin wrapper Prompt())
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? fallback(material) : text
        } catch {
            print("[FoundationModels] error:", error.localizedDescription)
            return fallback(material)
        }
    }

    // MARK: - Fallback

    private func fallback(_ material: NEXOMaterial) -> String {
        material.instructions.joined(separator: ". ") + "."
    }
}
