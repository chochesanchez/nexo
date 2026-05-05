// FichaView.swift
// Corrección: @ObservedObject para el singleton FoundationModelsService
// (no @StateObject, que es para objetos de los que la vista toma ownership).
// También elimina el import CoreLocation duplicado al final.

import SwiftUI
import AVFoundation
import Combine
import SwiftData
import CoreLocation

// MARK: - Speech Manager
private final class SpeechManager: NSObject, ObservableObject {
    @Published var isSpeaking = false
    private let synth = AVSpeechSynthesizer()
    override init() { super.init(); synth.delegate = self }
    func toggle(text: String) {
        if isSpeaking { synth.stopSpeaking(at: .immediate); isSpeaking = false }
        else {
            let utt = AVSpeechUtterance(string: text)
            utt.voice = AVSpeechSynthesisVoice(language: "es-MX")
            utt.rate  = 0.44
            synth.speak(utt); isSpeaking = true
        }
    }
    func stop() { synth.stopSpeaking(at: .immediate); isSpeaking = false }
}
extension SpeechManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}

// MARK: - FichaView
struct FichaView: View {
    let material  : NEXOMaterial
    let ocrText   : String?
    var imageData : Data? = nil
    @Binding var isPresented: Bool

    @Environment(\.modelContext)    private var context
    @EnvironmentObject private var repo     : ListingsRepository
    @EnvironmentObject private var location : LocationManager
    @EnvironmentObject private var auth     : AuthService

    @ObservedObject private var fmService = FoundationModelsService.shared
    @StateObject private var speech = SpeechManager()

    @State private var heroIn       = false
    @State private var contentIn    = false
    @State private var compartida   = false
    @State private var isPublishing = false
    @State private var publishError : String? = nil
    @State private var instruccionFM: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 1) {
                    // Cada sección separada por una línea de 0.5px
                    routeSection
                    divider
                    instructionsSection
                    if let tip = material.smellTip { divider; smellSection(tip) }
                    if let ocr = ocrText           { divider; ocrSection(ocr)   }
                    divider
                    metricsSection
                    divider
                    valueSection
                }
                .padding(.bottom, 24)
                .opacity(contentIn ? 1 : 0)
                .offset(y: contentIn ? 0 : 12)
            }
            actionBar
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.05)) { heroIn    = true }
            withAnimation(.easeOut(duration: 0.35).delay(0.3)) { contentIn = true }
            location.startUpdating()
            Task { instruccionFM = await fmService.generarInstruccion(material: material, textoOCR: ocrText) }
        }
        .onDisappear { speech.stop() }
        .alert("No se pudo publicar", isPresented: .constant(publishError != nil)) {
            Button("OK") { publishError = nil }
        } message: { Text(publishError ?? "") }
    }

    // MARK: - Header
    // Negro puro. El color del material solo vive en el badge de ruta.
    private var header: some View {
        ZStack(alignment: .bottom) {
            Color.nexoBlack.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Nav row
                HStack {
                    Button {
                        speech.stop(); isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .accessibilityLabel("Cerrar")

                    Spacer()

                    if fmService.isGenerating {
                        HStack(spacing: 6) {
                            ProgressView().tint(Color.white.opacity(0.4)).scaleEffect(0.75)
                            Text("Generando")
                                .font(.system(size: 10, weight: .regular))
                                .tracking(0.3)
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                    }
                }
                .padding(.horizontal, Sp.lg)
                .padding(.top, 60)
                .padding(.bottom, 20)

                // Material name — tipografía editorial
                VStack(alignment: .leading, spacing: 6) {
                    Text(material.classKey.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(2.5)
                        .foregroundStyle(Color.white.opacity(0.2))

                    Text(material.displayName)
                        .font(.system(size: 32, weight: .black))
                        .tracking(-2)
                        .foregroundStyle(.white)
                        .scaleEffect(heroIn ? 1 : 0.94, anchor: .leading)
                        .opacity(heroIn ? 1 : 0)
                }
                .padding(.horizontal, Sp.lg)
                .padding(.bottom, 24)

                // Regla inferior del header
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 0.5)
            }
        }
        .frame(height: 220)
    }

    // MARK: - Sections
    private var routeSection: some View {
        HStack(spacing: 8) {
            Image(systemName: material.route.icon)
                .font(.system(size: 11, weight: .semibold))
            Text(material.route.rawValue)
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.2)
        }
        .foregroundStyle(material.route.color)
        .padding(.horizontal, Sp.lg)
        .padding(.vertical, 14)
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Preparación", badge: instruccionFM != nil ? "IA" : nil)
            Text(instruccionFM ?? material.instructions.joined(separator: " "))
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Color.primary.opacity(0.8))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Sp.lg)
        .padding(.vertical, 16)
    }

    private func smellSection(_ tip: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "nose")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
            Text(tip)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Color.primary.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Sp.lg)
        .padding(.vertical, 14)
    }

    private func ocrSection(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 12))
                .foregroundStyle(Color.nexoBlue)
            VStack(alignment: .leading, spacing: 3) {
                Text("Texto en etiqueta")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.secondary)
                Text(text)
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Color.primary.opacity(0.7))
            }
        }
        .padding(.horizontal, Sp.lg)
        .padding(.vertical, 14)
    }

    private var metricsSection: some View {
        HStack(spacing: 0) {
            metricCell(label: "CO₂ evitado", value: material.co2, color: Color.nexoGreen)

            Rectangle().fill(Color.primary.opacity(0.06)).frame(width: 0.5)

            if material.water != "—" {
                metricCell(label: "Agua ahorrada", value: material.water, color: Color.nexoBlue)
            }
        }
    }

    private func metricCell(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.secondary)
            Text(value)
                .font(.system(size: 22, weight: .black))
                .tracking(-1)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Sp.lg)
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var valueSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Valor estimado")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.secondary)
                Text(material.value)
                    .font(.system(size: 18, weight: .black))
                    .tracking(-0.5)
                    .foregroundStyle(Color(hex: "9A7800"))
            }
            Spacer()
            Rectangle()
                .fill(Color.nexoAmber)
                .frame(width: 3, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.horizontal, Sp.lg)
        .padding(.vertical, 16)
        .background(Color(hex: "FFFDE8"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Valor estimado: \(material.value)")
    }

    // MARK: - Divider
    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 0.5)
    }

    // MARK: - Action bar
    private var actionBar: some View {
        VStack(spacing: 8) {
            Button { publicarFicha() } label: {
                Group {
                    if isPublishing {
                        ProgressView().tint(.white)
                    } else {
                        Text(compartida ? "Ficha compartida" : "Compartir con recolector")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(compartida ? Color.nexoGreen : .white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    compartida
                    ? Color.nexoGreen.opacity(0.08)
                    : Color.nexoBlack,
                    in: RoundedRectangle(cornerRadius: Rd.sm)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Rd.sm)
                        .strokeBorder(
                            compartida ? Color.nexoGreen.opacity(0.3) : Color.clear,
                            lineWidth: 0.5
                        )
                )
            }
            .disabled(compartida || isPublishing)
            .accessibilityLabel(compartida ? "Ficha ya compartida" : "Compartir ficha con recolectores")

            Button { speech.toggle(text: voiceText) } label: {
                HStack(spacing: 8) {
                    Image(systemName: speech.isSpeaking ? "speaker.slash" : "speaker.wave.2")
                        .font(.system(size: 13, weight: .regular))
                    Text(speech.isSpeaking ? "Detener" : "Leer en voz alta")
                        .font(.system(size: 12, weight: .regular))
                        .tracking(0.2)
                }
                .foregroundStyle(Color.primary.opacity(0.4))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: Rd.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: Rd.sm)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
                )
            }
            .accessibilityLabel(speech.isSpeaking ? "Detener lectura" : "Leer instrucciones en voz alta")
        }
        .padding(.horizontal, Sp.lg)
        .padding(.vertical, 12)
        .padding(.bottom, 16)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers
    private var voiceText: String {
        let base = instruccionFM ?? material.voiceText
        let tip  = material.smellTip.map { " \($0)" } ?? ""
        return "\(material.displayName). \(base)\(tip) Valor estimado: \(material.value)."
    }

    private func sectionLabel(_ text: String, badge: String? = nil) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.secondary)

            if let badge {
                Text(badge)
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Color.nexoGreen)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.nexoGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
            }
        }
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Publicar
    private func publicarFicha() {
        guard !compartida else { return }
        if !location.isAvailable { location.requestWhenInUse() }
        isPublishing = true
        let localImageData = imageData
        Task {
            let coord = location.anonymizedCoordinate
                     ?? location.coordinate
                     ?? CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332)

            var uploadedImageUrl: String? = nil
            if let data = localImageData, let userId = auth.currentUserId {
                uploadedImageUrl = try? await StorageService.shared.uploadScanImage(data, userId: userId)
            }

            if let userId = auth.currentUserId {
                let record = NewScanRecord(
                    userId        : userId,
                    material      : material.displayName,
                    imageUrl      : uploadedImageUrl,
                    ocrText       : ocrText,
                    lat           : coord.latitude,
                    lng           : coord.longitude,
                    classKey      : material.classKey,
                    displayName   : material.displayName,
                    icon          : material.icon,
                    route         : material.route.rawValue,
                    co2           : material.co2,
                    water         : material.water,
                    value         : material.value,
                    smellTip      : material.smellTip,
                    instructions  : material.instructions,
                    fmInstruction : instruccionFM
                )
                await repo.insertScanRecord(record)
            }

            let nuevo = NewListing(
                material      : material.displayName,
                quantityLabel : "1 unidad",
                notes         : instruccionFM ?? material.instructions.joined(separator: ". "),
                lat           : coord.latitude,
                lng           : coord.longitude,
                classKey      : material.classKey,
                displayName   : material.displayName,
                icon          : material.icon,
                route         : material.route.rawValue,
                co2           : material.co2,
                water         : material.water,
                value         : material.value,
                fmInstruction : instruccionFM
            )
            let ok = await repo.publish(nuevo)
            isPublishing = false
            if ok {
                context.insert(FichaRegistro(material: material))
                withAnimation(.easeOut(duration: 0.3)) { compartida = true }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                publishError = repo.lastError ?? "Intenta de nuevo."
            }
        }
    }
}
