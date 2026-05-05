// RecolectorView.swift

import SwiftUI
import MapKit
import AVFoundation
import Speech
import CoreLocation
import Combine

// MARK: - Voice Command Manager

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
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { buf, _ in
                request.append(buf)
            }
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    Task { @MainActor in self.process(transcript: result.bestTranscription.formattedString) }
                }
                if error != nil || result?.isFinal == true {
                    Task { @MainActor in self.stopListening() }
                }
            }
        } catch {
            print("[VoiceCommand] error:", error)
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil; task = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func process(transcript: String) {
        let t = transcript.lowercased()
        if      t.contains("siguiente") || t.contains("next")     { lastCommand = .siguiente; stopListening() }
        else if t.contains("confirmar") || t.contains("recogí")   { lastCommand = .confirmar; stopListening() }
        else if t.contains("ruta")                                  { lastCommand = .ruta;      stopListening() }
    }
}

// MARK: - RecolectorView

struct RecolectorView: View {

    var listings  : [Listing]
    var isLoading : Bool

    @EnvironmentObject private var repo: ListingsRepository
    @EnvironmentObject private var auth: AuthService

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
            Map(coordinateRegion: $region,
                showsUserLocation: true,
                annotationItems: pins) { pin in
                MapAnnotation(coordinate: pin.coordinate) {
                    // ← Fix: PinView solo recibe (material:) + trailing closure onTap
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

            VStack { topBar; Spacer() }

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
        .onChange(of: listings)          { _ in buildPins() }
        .onChange(of: voiceCmd.lastCommand) { cmd in handleVoiceCommand(cmd) }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(listings.isEmpty ? "Fichas de ejemplo" : "Fichas disponibles")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text("Modo Recolector")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            if isLoading {
                ProgressView().tint(Color.nexoGreen)
            } else {
                Text("\(pins.count)")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.nexoGreen, in: Capsule())
            }
            Button {
                Task { await auth.signOut() }
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(Color(.secondarySystemBackground), in: Circle())
            }
            .accessibilityLabel("Cerrar sesión")
        }
        .padding(.horizontal, Sp.lg).padding(.top, 60).padding(.bottom, Sp.md)
        .background(.ultraThinMaterial)
    }

    // MARK: - Bottom panel

    private var bottomPanel: some View {
        VStack(spacing: Sp.sm) {
            if let pin = currentPin {
                HStack(spacing: Sp.sm) {
                    Image(systemName: pin.material.icon).foregroundStyle(pin.material.accent)
                    Text(pin.material.displayName).font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text("\(selectedIndex + 1) / \(pins.count)")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, Sp.lg)
            }

            HStack(spacing: Sp.md) {
                bigButton(icon: speech.isSpeaking ? "speaker.slash.fill" : "speaker.wave.2.fill",
                          label: speech.isSpeaking ? "Detener" : "Escuchar",
                          color: Color.nexoDark.opacity(0.08), fg: Color.nexoDeep) {
                    if speech.isSpeaking { speech.stop() }
                    else if let pin = currentPin { speech.read(pin.material) }
                }
                bigButton(icon: "arrow.right.circle.fill", label: "Siguiente",
                          color: Color.nexoDark.opacity(0.08), fg: Color.nexoDeep) {
                    siguiente()
                }
                bigButton(icon: "checkmark.circle.fill", label: "Recoger",
                          color: Color.nexoGreen, fg: .white) {
                    if let pin = currentPin { confirmarRecoleccion(pin: pin) }
                }
                .disabled(isConfirming)
            }
            .padding(.horizontal, Sp.lg)

            voiceButton
        }
        .padding(.vertical, Sp.md).padding(.bottom, 20)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func bigButton(icon: String, label: String,
                           color: Color, fg: Color,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 26, weight: .semibold))
                Text(label).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity).padding(.vertical, Sp.md)
            .background(color, in: RoundedRectangle(cornerRadius: Rd.md))
        }
        .accessibilityLabel(label)
    }

    private var voiceButton: some View {
        Button {
            voiceCmd.isListening ? voiceCmd.stopListening() : voiceCmd.startListening()
        } label: {
            HStack(spacing: Sp.sm) {
                Image(systemName: voiceCmd.isListening ? "waveform.circle.fill" : "mic.circle")
                    .font(.system(size: 18))
                Text(voiceCmd.isListening
                     ? "Escuchando… di \"siguiente\", \"recoger\" o \"ruta\""
                     : "Activar comandos de voz")
                    .font(.system(size: 13))
            }
            .foregroundStyle(voiceCmd.authorized ? Color.nexoDeep : .secondary)
            .padding(.horizontal, Sp.lg)
        }
        .disabled(!voiceCmd.authorized)
        .accessibilityLabel(voiceCmd.isListening ? "Detener escucha" : "Activar comandos de voz")
    }

    // MARK: - Lógica

    private func buildPins() {
        if listings.isEmpty {
            pins = mockPins()      // ← mockPins() ya es internal en MapView.swift
        } else {
            pins = listings
                .filter { !confirmedIDs.contains($0.id) }
                .compactMap { listing in
                    guard let mat = NEXOMaterial.from(supabaseMaterial: listing.material) else { return nil }
                    return FichaPin(
                        coordinate: CLLocationCoordinate2D(latitude: listing.lat, longitude: listing.lng),
                        material  : mat
                    )
                }
        }
        if selectedIndex >= pins.count { selectedIndex = max(0, pins.count - 1) }
    }

    private func siguiente() {
        guard !pins.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % pins.count
        if let pin = currentPin {
            speech.read(pin.material)
            withAnimation { region.center = pin.coordinate }
        }
    }

    private func autoRead() {
        if let pin = currentPin { speech.read(pin.material) }
    }

    private func confirmarRecoleccion(pin: FichaPin) {
        isConfirming = true
        speech.stop()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        if let listing = listings.first(where: { l in
            abs(l.lat - pin.coordinate.latitude) < 0.001 &&
            abs(l.lng - pin.coordinate.longitude) < 0.001
        }) {
            Task {
                await repo.markClaimed(listing)
                confirmedIDs.insert(listing.id)
                buildPins()
                isConfirming = false
                showDetail   = false
            }
        } else {
            if let idx = pins.firstIndex(where: { $0.id == pin.id }) { pins.remove(at: idx) }
            selectedIndex = min(selectedIndex, max(0, pins.count - 1))
            isConfirming  = false
            showDetail    = false
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

// MARK: - Hoja detalle del recolector

struct FichaRecolectorSheet: View {
    let pin        : FichaPin
    let onConfirm  : () -> Void
    let onSiguiente: () -> Void

    @StateObject private var speech = RecolectorSpeech()

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 4).padding(.top, Sp.md)

            ScrollView {
                VStack(alignment: .leading, spacing: Sp.lg) {
                    HStack(spacing: Sp.md) {
                        ZStack {
                            Circle().fill(pin.material.accent.opacity(0.15)).frame(width: 56, height: 56)
                            Image(systemName: pin.material.icon)
                                .font(.system(size: 26)).foregroundStyle(pin.material.accent)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pin.material.displayName)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            HStack(spacing: 4) {
                                Image(systemName: pin.material.route.icon).font(.system(size: 12))
                                Text(pin.material.route.rawValue).font(.system(size: 13))
                            }.foregroundStyle(pin.material.route.color)
                        }
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: Sp.sm) {
                        Text("Preparación")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary).textCase(.uppercase).kerning(0.6)
                        ForEach(pin.material.instructions, id: \.self) { step in
                            Label(step, systemImage: "checkmark.circle").font(.system(size: 15))
                        }
                    }

                    HStack {
                        Image(systemName: "tag.fill").foregroundStyle(Color.nexoAmber)
                        Text(pin.material.value).font(.system(size: 15, weight: .bold))
                    }
                }
                .padding(Sp.lg)
            }

            VStack(spacing: Sp.sm) {
                Button(action: onConfirm) {
                    Label("Confirmar recolección", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(Color.nexoGreen, in: RoundedRectangle(cornerRadius: Rd.pill))
                }
                .accessibilityLabel("Confirmar que recogiste este material")

                HStack(spacing: Sp.md) {
                    Button {
                        speech.isSpeaking ? speech.stop() : speech.read(pin.material)
                    } label: {
                        Label(speech.isSpeaking ? "Detener" : "Escuchar",
                              systemImage: speech.isSpeaking ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.nexoDeep)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.nexoDark.opacity(0.08), in: RoundedRectangle(cornerRadius: Rd.pill))
                    }
                    Button(action: onSiguiente) {
                        Label("Siguiente", systemImage: "arrow.right.circle.fill")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.nexoDeep)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.nexoDark.opacity(0.08), in: RoundedRectangle(cornerRadius: Rd.pill))
                    }
                }
            }
            .padding(.horizontal, Sp.lg).padding(.bottom, 32)
        }
        .onAppear  { speech.read(pin.material) }
        .onDisappear { speech.stop() }
    }
}

// MARK: - RecolectorSpeech

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
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer,
                                       didFinish u: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = false }
    }
}

// MARK: - Array safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview("Recolector") {
    RecolectorView(
        listings: [],
        isLoading: false
    )
    .environmentObject(ListingsRepository())
}
