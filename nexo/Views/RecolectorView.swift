// RecolectorView.swift

// RecolectorView.swift 
import SwiftUI
import MapKit
import AVFoundation
import Speech
import CoreLocation
import Combine

// MARK: - Voice Command Manager (sin cambios funcionales)
@MainActor
final class VoiceCommandManager: ObservableObject {
    enum Command { case siguiente, confirmar, ruta, ninguno }
    @Published var isListening = false
    @Published var lastCommand : Command = .ninguno
    @Published var authorized  = false

    private var recognizer  : SFSpeechRecognizer?
    private var audioEngine  = AVAudioEngine()
    private var request      : SFSpeechAudioBufferRecognitionRequest?
    private var task         : SFSpeechRecognitionTask?

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-MX"))
        recognizer?.defaultTaskHint = .confirmation
        requestAuthorization()
    }
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in self?.authorized = (status == .authorized) }
        }
    }
    func startListening() {
        guard authorized, let recognizer, recognizer.isAvailable, !isListening else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            request = SFSpeechAudioBufferRecognitionRequest()
            guard let request else { return }
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            request.shouldReportPartialResults  = true
            let inputNode = audioEngine.inputNode
            let fmt = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { buf, _ in request.append(buf) }
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let result { Task { @MainActor in self.process(transcript: result.bestTranscription.formattedString) } }
                if error != nil || result?.isFinal == true { Task { @MainActor in self.stopListening() } }
            }
        } catch { print("[VoiceCommand] error:", error) }
    }
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio(); task?.cancel()
        request = nil; task = nil; isListening = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    private func process(transcript: String) {
        let t = transcript.lowercased()
        if      t.contains("siguiente") || t.contains("next")    { lastCommand = .siguiente; stopListening() }
        else if t.contains("confirmar") || t.contains("recogí")  { lastCommand = .confirmar; stopListening() }
        else if t.contains("ruta")                                { lastCommand = .ruta;      stopListening() }
    }
}

// MARK: - RecolectorView
struct RecolectorView: View {
    var listings  : [Listing]
    var isLoading : Bool

    @EnvironmentObject private var repo: ListingsRepository
    @StateObject private var voiceCmd = VoiceCommandManager()
    @StateObject private var speech   = RecolectorSpeech()

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332),
        span:   MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
    )
    @State private var pins          : [FichaPin] = []
    @State private var selectedIndex : Int        = 0
    @State private var showDetail    = false
    @State private var isConfirming  = false
    @State private var confirmedIDs  : Set<UUID>  = []

    private var currentPin: FichaPin? {
        guard !pins.isEmpty, selectedIndex < pins.count else { return nil }
        return pins[selectedIndex]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Mapa full bleed
            Map(coordinateRegion: $region,
                showsUserLocation: true,
                annotationItems: pins) { pin in
                MapAnnotation(coordinate: pin.coordinate) {
                    PinView(material: pin.material) {
                        if let idx = pins.firstIndex(where: { $0.id == pin.id }) {
                            selectedIndex = idx
                            showDetail    = true
                            autoRead()
                        }
                    }
                }
            }
            .ignoresSafeArea()

            // Floating pill en top-left
            VStack {
                floatingTopBar
                Spacer()
            }

            // Bottom panel
            if !pins.isEmpty { bottomPanel }
        }
        .sheet(isPresented: $showDetail) {
            if let pin = currentPin {
                FichaRecolectorSheet(
                    pin        : pin,
                    onConfirm  : { confirmarRecoleccion(pin: pin) },
                    onSiguiente: { siguiente() }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .onAppear {
            buildPins()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if let first = pins.first { speech.read(first.material) }
            }
        }
        .onChange(of: listings)               { _ in buildPins() }
        .onChange(of: voiceCmd.lastCommand)   { cmd in handleVoiceCommand(cmd) }
    }

    // MARK: - Floating top bar — pill minimalista
    private var floatingTopBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                // Dot de estado
                Circle()
                    .fill(isLoading ? Color.yellow : Color.nexoGreen)
                    .frame(width: 6, height: 6)

                if isLoading {
                    Text("Cargando")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                } else {
                    Text("\(pins.count) ficha\(pins.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
            )

            Spacer()
        }
        .padding(.horizontal, Sp.lg)
        .padding(.top, 60)
    }

    // MARK: - Bottom panel
    private var bottomPanel: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.primary.opacity(0.12))
                .frame(width: 32, height: 3)
                .padding(.top, 10)
                .padding(.bottom, 14)

            if let pin = currentPin {
                // Material info
                HStack(spacing: 12) {
                    // Ícono cuadrado — no círculo
                    RoundedRectangle(cornerRadius: 8)
                        .fill(pin.material.accent.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: pin.material.icon)
                                .font(.system(size: 18, weight: .light))
                                .foregroundStyle(pin.material.accent)
                        }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(pin.material.displayName)
                            .font(.system(size: 16, weight: .bold))
                            .tracking(-0.5)
                        HStack(spacing: 4) {
                            Image(systemName: pin.material.route.icon)
                                .font(.system(size: 9))
                            Text(pin.material.route.rawValue)
                                .font(.system(size: 10, weight: .medium))
                            Text("·")
                            Text(pin.material.value)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(hex: "9A7800"))
                        }
                        .foregroundStyle(pin.material.route.color)
                    }

                    Spacer()

                    Text("\(selectedIndex + 1) / \(pins.count)")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.secondary)
                }
                .padding(.horizontal, Sp.lg)
                .padding(.bottom, 14)

                // Regla
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 0.5)
                    .padding(.bottom, 12)

                // Botones — 3 en fila
                HStack(spacing: 8) {
                    // Voz — cuadrado negro, el CTA de voice-first
                    Button {
                        voiceCmd.isListening ? voiceCmd.stopListening() : voiceCmd.startListening()
                    } label: {
                        RoundedRectangle(cornerRadius: Rd.sm)
                            .fill(voiceCmd.isListening ? Color.nexoGreen : Color.nexoBlack)
                            .frame(width: 50, height: 50)
                            .overlay {
                                Image(systemName: voiceCmd.isListening ? "waveform" : "mic")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(.white)
                            }
                    }
                    .disabled(!voiceCmd.authorized)
                    .accessibilityLabel(voiceCmd.isListening ? "Detener escucha" : "Comandos de voz")

                    // Leer
                    actionBtn(
                        icon  : speech.isSpeaking ? "speaker.slash" : "speaker.wave.2",
                        label : speech.isSpeaking ? "Detener" : "Escuchar",
                        style : .secondary
                    ) {
                        speech.isSpeaking ? speech.stop() : speech.read(pin.material)
                    }

                    // Siguiente
                    actionBtn(icon: "arrow.right", label: "Siguiente", style: .secondary) {
                        siguiente()
                    }

                    // Recoger — ámbar de la pantalla
                    actionBtn(icon: "checkmark", label: "Recoger", style: .primary) {
                        confirmarRecoleccion(pin: pin)
                    }
                    .disabled(isConfirming)
                }
                .padding(.horizontal, Sp.lg)
                .padding(.bottom, 28)
            }
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Action button helper
    enum BtnStyle { case primary, secondary }
    @ViewBuilder
    private func actionBtn(icon: String, label: String, style: BtnStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: style == .primary ? .semibold : .regular))
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.3)
            }
            .foregroundStyle(style == .primary ? Color.nexoBlack : Color.primary.opacity(0.6))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                style == .primary ? Color.nexoAmber : Color.primary.opacity(0.05),
                in: RoundedRectangle(cornerRadius: Rd.sm)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Rd.sm)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
            )
        }
        .accessibilityLabel(label)
    }

    // MARK: - Lógica
    private func buildPins() {
        if listings.isEmpty {
            pins = mockPins()
        } else {
            pins = listings
                .filter { !confirmedIDs.contains($0.id) }
                .compactMap { listing in
                    guard let mat = NEXOMaterial.from(supabaseMaterial: listing.material) else { return nil }
                    return FichaPin(
                        coordinate: CLLocationCoordinate2D(latitude: listing.lat, longitude: listing.lng),
                        material: mat
                    )
                }
        }
        if selectedIndex >= pins.count { selectedIndex = max(0, pins.count - 1) }
    }

    private func siguiente() {
        guard !pins.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % pins.count
        if let pin = currentPin { speech.read(pin.material); withAnimation { region.center = pin.coordinate } }
    }

    private func autoRead() { if let pin = currentPin { speech.read(pin.material) } }

    private func confirmarRecoleccion(pin: FichaPin) {
        isConfirming = true; speech.stop()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if let listing = listings.first(where: { l in
            abs(l.lat - pin.coordinate.latitude) < 0.001 &&
            abs(l.lng - pin.coordinate.longitude) < 0.001
        }) {
            Task {
                await repo.markClaimed(listing)
                confirmedIDs.insert(listing.id)
                buildPins(); isConfirming = false; showDetail = false
            }
        } else {
            if let idx = pins.firstIndex(where: { $0.id == pin.id }) { pins.remove(at: idx) }
            selectedIndex = min(selectedIndex, max(0, pins.count - 1))
            isConfirming = false; showDetail = false
        }
    }

    private func handleVoiceCommand(_ cmd: VoiceCommandManager.Command) {
        switch cmd {
        case .siguiente: siguiente()
        case .confirmar: if let pin = currentPin { confirmarRecoleccion(pin: pin) }
        case .ruta:
            if let pin = currentPin {
                let item = MKMapItem(placemark: MKPlacemark(coordinate: pin.coordinate))
                item.name = pin.material.displayName
                item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
            }
        case .ninguno: break
        }
    }
}

// MARK: - Hoja detalle — rediseñada
struct FichaRecolectorSheet: View {
    let pin        : FichaPin
    let onConfirm  : () -> Void
    let onSiguiente: () -> Void
    @StateObject private var speech = RecolectorSpeech()

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.primary.opacity(0.12))
                .frame(width: 32, height: 3)
                .padding(.top, Sp.md)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header material
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(pin.material.accent.opacity(0.1))
                            .frame(width: 52, height: 52)
                            .overlay {
                                Image(systemName: pin.material.icon)
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundStyle(pin.material.accent)
                            }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pin.material.displayName)
                                .font(.system(size: 20, weight: .black))
                                .tracking(-1)
                            HStack(spacing: 5) {
                                Image(systemName: pin.material.route.icon).font(.system(size: 10))
                                Text(pin.material.route.rawValue).font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(pin.material.route.color)
                        }
                        Spacer()
                    }
                    .padding(Sp.lg)

                    Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 0.5)

                    // Preparación
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Preparación")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.secondary)

                        ForEach(Array(pin.material.instructions.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(i + 1)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.secondary)
                                    .frame(width: 16)
                                Text(step)
                                    .font(.system(size: 14, weight: .light))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(Sp.lg)

                    Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 0.5)

                    // Valor
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Valor estimado")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(1.5)
                                .textCase(.uppercase)
                                .foregroundStyle(Color.secondary)
                            Text(pin.material.value)
                                .font(.system(size: 20, weight: .black))
                                .tracking(-0.5)
                                .foregroundStyle(Color(hex: "9A7800"))
                        }
                        Spacer()
                        Rectangle()
                            .fill(Color.nexoAmber)
                            .frame(width: 3, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                    .padding(Sp.lg)
                    .background(Color(hex: "FFFDE8"))
                }
            }

            // Acciones
            VStack(spacing: 8) {
                Button(action: onConfirm) {
                    Text("Confirmar recolección")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.nexoBlack, in: RoundedRectangle(cornerRadius: Rd.sm))
                }
                .accessibilityLabel("Confirmar que recogiste este material")

                HStack(spacing: 8) {
                    Button {
                        speech.isSpeaking ? speech.stop() : speech.read(pin.material)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: speech.isSpeaking ? "speaker.slash" : "speaker.wave.2")
                                .font(.system(size: 12))
                            Text(speech.isSpeaking ? "Detener" : "Escuchar")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: Rd.sm))
                        .overlay(RoundedRectangle(cornerRadius: Rd.sm).strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5))
                    }

                    Button(action: onSiguiente) {
                        HStack(spacing: 6) {
                            Text("Siguiente")
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: Rd.sm))
                        .overlay(RoundedRectangle(cornerRadius: Rd.sm).strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5))
                    }
                }
            }
            .padding(.horizontal, Sp.lg)
            .padding(.bottom, 32)
            .padding(.top, 8)
        }
        .onAppear   { speech.read(pin.material) }
        .onDisappear { speech.stop() }
    }
}

// MARK: - RecolectorSpeech (sin cambios)
@MainActor
final class RecolectorSpeech: NSObject, ObservableObject {
    @Published var isSpeaking = false
    private let synth = AVSpeechSynthesizer()
    override init() { super.init(); synth.delegate = self }
    func read(_ material: NEXOMaterial) {
        stop()
        let text = "Material: \(material.displayName). Ruta: \(material.route.rawValue). "
                 + material.instructions.joined(separator: ". ")
                 + ". Valor: \(material.value)."
        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: "es-MX")
        utt.rate  = 0.44
        synth.speak(utt); isSpeaking = true
    }
    func stop() { synth.stopSpeaking(at: .immediate); isSpeaking = false }
}
extension RecolectorSpeech: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = false }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

#Preview("Recolector") {
    RecolectorView(listings: [], isLoading: false)
        .environmentObject(ListingsRepository())
}
