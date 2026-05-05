// RecolectorView.swift — Centros de acopio + bulk value + ruta en mapa
import SwiftUI
import MapKit
import AVFoundation
import Speech
import CoreLocation
import Combine
import SwiftData

// MARK: - VoiceCommandManager
@MainActor
final class VoiceCommandManager: ObservableObject {
    enum Command { case siguiente, confirmar, ruta, ninguno }
    @Published var isListening = false
    @Published var lastCommand: Command = .ninguno
    @Published var authorized  = false
    private var recognizer : SFSpeechRecognizer?
    private var audioEngine  = AVAudioEngine()
    private var request      : SFSpeechAudioBufferRecognitionRequest?
    private var task         : SFSpeechRecognitionTask?
    init() { recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-MX")); recognizer?.defaultTaskHint = .confirmation; requestAuthorization() }
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] s in Task { @MainActor in self?.authorized = (s == .authorized) } }
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
            let node = audioEngine.inputNode
            let fmt  = node.outputFormat(forBus: 0)
            node.installTap(onBus: 0, bufferSize: 1024, format: fmt) { buf, _ in request.append(buf) }
            audioEngine.prepare(); try audioEngine.start(); isListening = true
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let result { Task { @MainActor in self.process(result.bestTranscription.formattedString) } }
                if error != nil || result?.isFinal == true { Task { @MainActor in self.stopListening() } }
            }
        } catch { print("[Voice] error:", error) }
    }
    func stopListening() {
        audioEngine.stop(); audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio(); task?.cancel(); request = nil; task = nil; isListening = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    private func process(_ t: String) {
        let t = t.lowercased()
        if      t.contains("siguiente") || t.contains("next")   { lastCommand = .siguiente; stopListening() }
        else if t.contains("confirmar") || t.contains("recogí") { lastCommand = .confirmar; stopListening() }
        else if t.contains("ruta")                               { lastCommand = .ruta;      stopListening() }
    }
}

// MARK: - RecolectorView
struct RecolectorView: View {
    var listings  : [Listing]
    var isLoading : Bool

    @EnvironmentObject private var repo : ListingsRepository
    @Environment(\.modelContext) private var context

    @StateObject private var voiceCmd = VoiceCommandManager()
    @StateObject private var speech   = RecolectorSpeech()

    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332),
        span:   MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
    ))

    // Fichas
    @State private var pins            : [FichaPin] = []
    @State private var selectedIndex   : Int        = 0
    @State private var showDetail      = false
    @State private var isConfirming    = false
    @State private var confirmedIDs    : Set<UUID>  = []

    // Ruta
    @State private var currentRoute      : MKRoute? = nil
    @State private var isCalculatingRoute = false
    @State private var showRouteCard      = false

    // ── NUEVO: Centros de acopio ──────────────────────────────────────────
    @State private var mostrarCentros     = false
    @State private var centrosVisibles    : [PuntoReciclaje] = []
    @State private var centroSeleccionado : PuntoReciclaje?  = nil
    @State private var showCentroSheet    = false

    // ── NUEVO: Trip / bulk tracking ───────────────────────────────────────
    @State private var tripPins           : [FichaPin] = []   // confirmados en esta sesión
    @State private var showBulkPanel      = false
    @State private var showBulkSheet      = false

    private var currentPin: FichaPin? {
        guard !pins.isEmpty, selectedIndex < pins.count else { return nil }
        return pins[selectedIndex]
    }

    private var bulkResult: BulkValueCalculator.BulkResult {
        BulkValueCalculator.calcular(desde: tripPins)
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Mapa con fichas + centros de acopio ───────────────────────
            Map(position: $cameraPosition) {
                // Fichas disponibles
                ForEach(pins) { pin in
                    Annotation("", coordinate: pin.coordinate, anchor: .bottom) {
                        PinView(material: pin.material) {
                            if let idx = pins.firstIndex(where: { $0.id == pin.id }) {
                                selectedIndex = idx
                                showRouteCard = false; currentRoute = nil
                                showDetail    = true;  autoRead()
                            }
                        }
                    }
                }

                // Centros de acopio (capa toggleable)
                if mostrarCentros {
                    ForEach(centrosVisibles) { centro in
                        Annotation("", coordinate: centro.coordinate, anchor: .bottom) {
                            PuntoReciclajePin(
                                centro    : centro,
                                isSelected: centroSeleccionado?.id == centro.id
                            )
                            .onTapGesture {
                                centroSeleccionado = centro
                                showCentroSheet    = true
                            }
                        }
                    }
                }

                // Ruta calculada
                if let route = currentRoute {
                    MapPolyline(route.polyline)
                        .stroke(Color.nexoBrand,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea()

            // Top controls
            VStack { topControls; Spacer() }

            // Botón mi ubicación
            locationButton

            // Panel inferior
            if !pins.isEmpty {
                if showRouteCard { routePanel }
                else             { bottomPanel }
            }
        }
        .sheet(isPresented: $showDetail) {
            if let pin = currentPin {
                FichaRecolectorSheet(
                    pin        : pin,
                    onConfirm  : { iniciarRuta(pin: pin) },
                    onSiguiente: { siguiente() }
                )
                .presentationDetents([.medium, .large])
            }
        }
        // ── Sheet de centro de acopio ─────────────────────────────────────
        .sheet(isPresented: $showCentroSheet) {
            if let centro = centroSeleccionado {
                CentroAcopioSheet(centro: centro)
                    .presentationDetents([.medium])
            }
        }
        // ── Sheet de resumen bulk ─────────────────────────────────────────
        .sheet(isPresented: $showBulkSheet) {
            BulkSheet(result: bulkResult, centros: centrosVisibles) {
                showBulkSheet = false
                if let centro = centrosVisibles.first {
                    let item = MKMapItem(placemark: MKPlacemark(coordinate: centro.coordinate))
                    item.name = centro.nombre
                    item.openInMaps(launchOptions: [
                        MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
                    ])
                }
            }
            .presentationDetents([.large])
        }
        .onAppear {
            buildPins()
            cargarCentros()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if let first = pins.first { speech.read(first.material) }
            }
        }
        .onChange(of: listings)             { _ in buildPins() }
        .onChange(of: voiceCmd.lastCommand) { cmd in handleVoiceCommand(cmd) }
    }

    // MARK: - Top controls (pill fichas + toggle centros + bulk badge)

    private var topControls: some View {
        HStack(spacing: 8) {
            // Fichas count
            HStack(spacing: 8) {
                Circle().fill(isLoading ? Color.yellow : Color.nexoGreen).frame(width: 7, height: 7)
                Text(isLoading ? "Cargando…" : "\(pins.count) ficha\(pins.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .label))
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.07), radius: 8, y: 2)

            // Toggle centros de acopio
            Button {
                withAnimation(.spring(response: 0.3)) { mostrarCentros.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: mostrarCentros ? "building.2.fill" : "building.2")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Centros")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(mostrarCentros ? Color(hex: "1565C0") : Color(uiColor: .secondaryLabel))
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(
                    mostrarCentros ? Color(hex: "E3F2FD") : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
                    mostrarCentros ? Color(hex: "1565C0").opacity(0.3) : Color(uiColor: .separator),
                    lineWidth: mostrarCentros ? 1 : 0.5
                ))
                .shadow(color: .black.opacity(0.07), radius: 8, y: 2)
            }
            .accessibilityLabel(mostrarCentros ? "Ocultar centros de acopio" : "Mostrar centros de acopio")

            Spacer()

            // Badge trip actual (aparece cuando hay items confirmados)
            if !tripPins.isEmpty {
                Button {
                    showBulkSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "bag.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("\(tripPins.count)")
                            .font(.system(size: 12, weight: .black))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Color.nexoForest, in: RoundedRectangle(cornerRadius: 10))
                    .shadow(color: Color.nexoForest.opacity(0.3), radius: 8, y: 2)
                }
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Ver resumen de \(tripPins.count) materiales recolectados")
            }
        }
        .padding(.horizontal, Sp.lg).padding(.top, 56)
    }

    // MARK: - Botón ubicación

    private var locationButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.4)) {
                        cameraPosition = .userLocation(fallback: .automatic)
                    }
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.nexoBrand)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                }
                .padding(.trailing, Sp.lg)
                .padding(.bottom, showRouteCard ? 270 : 200)
                .accessibilityLabel("Centrar en mi ubicación")
            }
        }
    }

    // MARK: - Bottom panel normal

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            handle
            if let pin = currentPin {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(pin.material.accent.opacity(0.12))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: pin.material.icon)
                                .font(.system(size: 18, weight: .light))
                                .foregroundStyle(pin.material.accent)
                        }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(pin.material.displayName)
                            .font(.system(size: 16, weight: .semibold))
                        HStack(spacing: 4) {
                            Image(systemName: pin.material.route.icon).font(.system(size: 9))
                            Text(pin.material.route.rawValue).font(.system(size: 11, weight: .medium))
                            Text("·")
                            Text(pin.material.value).font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(hex: "7A5F00"))
                        }.foregroundStyle(pin.material.route.color)
                    }
                    Spacer()
                    Text("\(selectedIndex + 1)/\(pins.count)")
                        .font(.system(size: 11)).foregroundStyle(Color(uiColor: .secondaryLabel))
                }
                .padding(.horizontal, Sp.lg).padding(.bottom, 14)
                separator

                HStack(spacing: 8) {
                    Button {
                        voiceCmd.isListening ? voiceCmd.stopListening() : voiceCmd.startListening()
                    } label: {
                        RoundedRectangle(cornerRadius: Rd.md)
                            .fill(voiceCmd.isListening ? Color.nexoBrand : Color.nexoForest)
                            .frame(width: 52, height: 52)
                            .overlay {
                                Image(systemName: voiceCmd.isListening ? "waveform" : "mic")
                                    .font(.system(size: 16)).foregroundStyle(.white)
                            }
                    }.disabled(!voiceCmd.authorized)

                    recBtn(icon: speech.isSpeaking ? "speaker.slash" : "speaker.wave.2",
                           label: speech.isSpeaking ? "Detener" : "Escuchar", style: .secondary) {
                        speech.isSpeaking ? speech.stop() : speech.read(pin.material)
                    }
                    recBtn(icon: "arrow.right", label: "Siguiente", style: .secondary) { siguiente() }
                    recBtn(icon: isCalculatingRoute ? "ellipsis" : "location.fill",
                           label: "Recoger", style: .primary) {
                        iniciarRuta(pin: pin)
                    }.disabled(isCalculatingRoute)
                }
                .padding(.horizontal, Sp.lg).padding(.bottom, 28)
            }
        }
        .background(.regularMaterial)
        .overlay(alignment: .top) { separator }
    }

    // MARK: - Route panel

    private var routePanel: some View {
        VStack(spacing: 0) {
            handle
            if let pin = currentPin {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ruta calculada")
                            .font(.system(size: 10, weight: .semibold)).tracking(0.5)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                        Text(pin.material.displayName)
                            .font(.system(size: 18, weight: .bold)).tracking(-0.5)
                    }
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.3)) { showRouteCard = false; currentRoute = nil }
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                            .frame(width: 28, height: 28)
                            .background(Color(uiColor: .systemGray5), in: Circle())
                    }
                }
                .padding(.horizontal, Sp.lg).padding(.bottom, 12)

                if let route = currentRoute {
                    HStack(spacing: 10) {
                        routeMetric(icon: "figure.walk", value: formatDistance(route.distance),
                                    label: "Distancia", color: Color.nexoBrand)
                        routeMetric(icon: "clock", value: formatTime(route.expectedTravelTime),
                                    label: "Tiempo estimado", color: Color.nexoBrand)
                    }
                    .padding(.horizontal, Sp.lg).padding(.bottom, 14)
                }
                separator

                HStack(spacing: 10) {
                    Button {
                        let item = MKMapItem(placemark: MKPlacemark(coordinate: pin.coordinate))
                        item.name = pin.material.displayName
                        item.openInMaps(launchOptions: [
                            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
                        ])
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "map.fill").font(.system(size: 13, weight: .semibold))
                            Text("Abrir en Maps").font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Color.nexoBrand).frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color.nexoMint, in: RoundedRectangle(cornerRadius: Rd.lg))
                    }

                    Button { confirmarRecoleccion(pin: pin) } label: {
                        HStack(spacing: 7) {
                            if isConfirming { ProgressView().tint(.white).scaleEffect(0.8) }
                            else {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 13, weight: .semibold))
                                Text("Ya recogí").font(.system(size: 13, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color.nexoForest, in: RoundedRectangle(cornerRadius: Rd.lg))
                        .shadow(color: Color.nexoForest.opacity(0.2), radius: 8, y: 3)
                    }.disabled(isConfirming)
                }
                .padding(.horizontal, Sp.lg).padding(.bottom, 28)
            }
        }
        .background(.regularMaterial)
        .overlay(alignment: .top) { separator }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Helpers UI

    private var handle: some View {
        RoundedRectangle(cornerRadius: 2).fill(Color(uiColor: .systemGray4))
            .frame(width: 36, height: 4).padding(.top, 10).padding(.bottom, 14)
    }
    private var separator: some View {
        Rectangle().fill(Color(uiColor: .separator)).frame(height: 0.5).padding(.bottom, 12)
    }
    private func recBtn(icon: String, label: String, style: BtnStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 14, weight: style == .primary ? .semibold : .regular))
                Text(label).font(.system(size: 9, weight: .semibold)).tracking(0.2)
            }
            .foregroundStyle(style == .primary ? .white : Color.nexoBrand)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(style == .primary ? Color.nexoForest : Color.nexoMint,
                        in: RoundedRectangle(cornerRadius: Rd.md))
        }.accessibilityLabel(label)
    }
    enum BtnStyle { case primary, secondary }
    private func routeMetric(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 18, weight: .bold)).tracking(-0.5).foregroundStyle(Color(uiColor: .label))
                Text(label).font(.system(size: 10)).foregroundStyle(Color(uiColor: .secondaryLabel))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.md))
        .overlay(RoundedRectangle(cornerRadius: Rd.md).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
    }

    // MARK: - Lógica

    private func cargarCentros() {
        let base = CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332)
        centrosVisibles = CentroAcopio.cercanos(a: base, radioKm: 15)
    }

    private func iniciarRuta(pin: FichaPin) {
        guard !isCalculatingRoute else { return }
        isCalculatingRoute = true; showDetail = false; speech.stop()
        let req = MKDirections.Request()
        req.source = MKMapItem.forCurrentLocation()
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: pin.coordinate))
        req.transportType = .walking
        MKDirections(request: req).calculate { [self] response, _ in
            Task { @MainActor in
                isCalculatingRoute = false
                if let route = response?.routes.first {
                    currentRoute = route
                    let rect = route.polyline.boundingMapRect
                    let expanded = rect.insetBy(dx: -rect.size.width * 0.4, dy: -rect.size.height * 0.4)
                    withAnimation(.easeOut(duration: 0.6)) {
                        cameraPosition = .region(MKCoordinateRegion(expanded)); showRouteCard = true
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } else {
                    let item = MKMapItem(placemark: MKPlacemark(coordinate: pin.coordinate))
                    item.name = pin.material.displayName
                    item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
                }
            }
        }
    }

    private func confirmarRecoleccion(pin: FichaPin) {
        isConfirming = true; speech.stop()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Guardar en historial SwiftData
        let registro = RecoleccionRegistro(
            material: pin.material,
            lat     : pin.coordinate.latitude,
            lng     : pin.coordinate.longitude
        )
        context.insert(registro)

        // ── Agregar al trip actual para bulk value ────────────────────────
        withAnimation(.spring(response: 0.4)) { tripPins.append(pin) }

        if let listing = listings.first(where: { l in
            abs(l.lat - pin.coordinate.latitude) < 0.001 &&
            abs(l.lng - pin.coordinate.longitude) < 0.001
        }) {
            Task {
                await repo.markClaimed(listing)
                confirmedIDs.insert(listing.id)
                buildPins()
                withAnimation(.easeOut(duration: 0.3)) { showRouteCard = false; currentRoute = nil }
                isConfirming = false
            }
        } else {
            if let idx = pins.firstIndex(where: { $0.id == pin.id }) { pins.remove(at: idx) }
            selectedIndex = min(selectedIndex, max(0, pins.count - 1))
            withAnimation(.easeOut(duration: 0.3)) { showRouteCard = false; currentRoute = nil }
            isConfirming = false
        }
    }

    private func buildPins() {
        if listings.isEmpty { pins = mockPins() }
        else {
            pins = listings.filter { !confirmedIDs.contains($0.id) }.compactMap { listing in
                guard let mat = NEXOMaterial.from(supabaseMaterial: listing.material) else { return nil }
                return FichaPin(coordinate: CLLocationCoordinate2D(latitude: listing.lat, longitude: listing.lng), material: mat)
            }
        }
        if selectedIndex >= pins.count { selectedIndex = max(0, pins.count - 1) }
    }

    private func siguiente() {
        guard !pins.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.3)) { showRouteCard = false; currentRoute = nil }
        selectedIndex = (selectedIndex + 1) % pins.count
        if let pin = currentPin {
            speech.read(pin.material)
            withAnimation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: pin.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        }
    }
    private func autoRead() { if let pin = currentPin { speech.read(pin.material) } }

    private func handleVoiceCommand(_ cmd: VoiceCommandManager.Command) {
        switch cmd {
        case .siguiente: siguiente()
        case .confirmar: if let pin = currentPin { iniciarRuta(pin: pin) }
        case .ruta:
            if let pin = currentPin {
                let item = MKMapItem(placemark: MKPlacemark(coordinate: pin.coordinate))
                item.name = pin.material.displayName
                item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
            }
        case .ninguno: break
        }
    }
    private func formatDistance(_ m: CLLocationDistance) -> String {
        m < 1000 ? "\(Int(m)) m" : String(format: "%.1f km", m / 1000)
    }
    private func formatTime(_ s: TimeInterval) -> String {
        let mins = Int(s / 60)
        return mins < 60 ? "\(mins) min" : "\(mins / 60)h \(mins % 60)m"
    }
}

// MARK: - CentroAcopioSheet

struct CentroAcopioSheet: View {
    let centro: PuntoReciclaje
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2).fill(Color(uiColor: .systemGray4))
                .frame(width: 36, height: 4).padding(.top, Sp.md).padding(.bottom, 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 12).fill(centro.tipo.color.opacity(0.12))
                            .frame(width: 56, height: 56)
                            .overlay {
                                Image(systemName: centro.tipo.icon)
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundStyle(centro.tipo.color)
                            }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(centro.nombre).font(.system(size: 18, weight: .bold)).tracking(-0.5)
                            Text(centro.tipo.rawValue).font(.system(size: 12)).foregroundStyle(centro.tipo.color)
                        }
                        Spacer()
                    }

                    infoRow(icon: "clock", label: "Horario", value: centro.horario)
                    if let tel = centro.telefono { infoRow(icon: "phone", label: "Teléfono", value: tel) }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Acepta").font(.system(size: 11, weight: .semibold)).tracking(0.5)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                        FlowLayout(items: centro.materiales) { material in
                            Text(material).font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color(uiColor: .systemGray6), in: Capsule())
                        }
                    }

                    Button {
                        let item = MKMapItem(placemark: MKPlacemark(coordinate: centro.coordinate))
                        item.name = centro.nombre
                        item.openInMaps(launchOptions: [
                            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
                        ])
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "map.fill").font(.system(size: 13, weight: .semibold))
                            Text("Cómo llegar").font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 50)
                        .background(centro.tipo.color, in: RoundedRectangle(cornerRadius: Rd.lg))
                    }
                }
                .padding(.horizontal, Sp.lg).padding(.bottom, 32)
            }
        }
    }
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(Color(uiColor: .secondaryLabel)).frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 10, weight: .semibold)).tracking(0.5).foregroundStyle(Color(uiColor: .secondaryLabel))
                Text(value).font(.system(size: 14)).foregroundStyle(Color(uiColor: .label))
            }
        }
    }
}

// MARK: - BulkSheet — resumen completo del trip

struct BulkSheet: View {
    let result      : BulkValueCalculator.BulkResult
    let centros     : [PuntoReciclaje]
    let onIrACentro : () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    BulkValuePanel(result: result, onDescargar: onIrACentro)

                    if !centros.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Centros de acopio cercanos")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(uiColor: .label))
                            ForEach(centros.prefix(3)) { centro in
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 8).fill(centro.tipo.color.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                        .overlay {
                                            Image(systemName: centro.tipo.icon)
                                                .font(.system(size: 14, weight: .light))
                                                .foregroundStyle(centro.tipo.color)
                                        }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(centro.nombre).font(.system(size: 13, weight: .semibold))
                                        Text(centro.horario).font(.system(size: 11)).foregroundStyle(Color(uiColor: .secondaryLabel))
                                    }
                                    Spacer()
                                }
                                .padding(10)
                                .background(Color(uiColor: .systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: Rd.md))
                                .overlay(RoundedRectangle(cornerRadius: Rd.md).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
                            }
                        }
                    }
                }
                .padding(Sp.lg)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Tu ruta de hoy")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - FlowLayout helper

struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items  : Data
    let content: (Data.Element) -> Content
    var body: some View {
        var lines: [[Data.Element]] = [[]]
        for item in items { lines[lines.count - 1].append(item) }
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(lines.indices, id: \.self) { i in
                HStack(spacing: 6) {
                    ForEach(lines[i], id: \.self) { item in content(item) }
                }
            }
        }
    }
}

// MARK: - FichaRecolectorSheet
struct FichaRecolectorSheet: View {
    let pin: FichaPin; let onConfirm: () -> Void; let onSiguiente: () -> Void
    @StateObject private var speech = RecolectorSpeech()
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2).fill(Color(uiColor: .systemGray4))
                .frame(width: 36, height: 4).padding(.top, Sp.md)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 12).fill(pin.material.accent.opacity(0.12))
                            .frame(width: 56, height: 56)
                            .overlay { Image(systemName: pin.material.icon).font(.system(size: 22, weight: .light)).foregroundStyle(pin.material.accent) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pin.material.displayName).font(.system(size: 20, weight: .bold)).tracking(-0.8)
                            HStack(spacing: 4) {
                                Image(systemName: pin.material.route.icon).font(.system(size: 10))
                                Text(pin.material.route.rawValue).font(.system(size: 12, weight: .medium))
                            }.foregroundStyle(pin.material.route.color)
                        }
                        Spacer()
                    }.padding(Sp.lg)
                    Rectangle().fill(Color(uiColor: .separator)).frame(height: 0.5)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Preparación").font(.system(size: 10, weight: .semibold)).tracking(0.5).foregroundStyle(Color(uiColor: .secondaryLabel))
                        ForEach(Array(pin.material.instructions.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(i+1)").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(uiColor: .tertiaryLabel)).frame(width: 16)
                                Text(step).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }.padding(Sp.lg)
                    Rectangle().fill(Color(uiColor: .separator)).frame(height: 0.5)
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Valor estimado").font(.system(size: 10, weight: .semibold)).tracking(0.5).foregroundStyle(Color(uiColor: .secondaryLabel))
                            Text(pin.material.value).font(.system(size: 20, weight: .bold)).tracking(-0.5).foregroundStyle(Color(hex: "7A5F00"))
                        }
                        Spacer()
                        Rectangle().fill(Color.nexoAmber).frame(width: 4, height: 40).clipShape(RoundedRectangle(cornerRadius: 2))
                    }.padding(Sp.lg).background(Color(hex: "FFFCE8"))
                }
            }
            VStack(spacing: 8) {
                Button(action: onConfirm) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill").font(.system(size: 14, weight: .semibold))
                        Text("Ver ruta").font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color.nexoForest, in: RoundedRectangle(cornerRadius: Rd.lg))
                    .shadow(color: Color.nexoForest.opacity(0.2), radius: 8, y: 3)
                }
                HStack(spacing: 8) {
                    Button { speech.isSpeaking ? speech.stop() : speech.read(pin.material) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: speech.isSpeaking ? "speaker.slash" : "speaker.wave.2").font(.system(size: 13))
                            Text(speech.isSpeaking ? "Detener" : "Escuchar").font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(Color.nexoBrand).frame(maxWidth: .infinity).frame(height: 46)
                        .background(Color.nexoMint, in: RoundedRectangle(cornerRadius: Rd.lg))
                    }
                    Button(action: onSiguiente) {
                        HStack(spacing: 6) {
                            Text("Siguiente").font(.system(size: 13, weight: .medium))
                            Image(systemName: "arrow.right").font(.system(size: 12))
                        }
                        .foregroundStyle(Color.nexoBrand).frame(maxWidth: .infinity).frame(height: 46)
                        .background(Color.nexoMint, in: RoundedRectangle(cornerRadius: Rd.lg))
                    }
                }
            }.padding(.horizontal, Sp.lg).padding(.bottom, 32).padding(.top, 8)
        }
        .onAppear { speech.read(pin.material) }.onDisappear { speech.stop() }
    }
}

// MARK: - RecolectorSpeech
@MainActor final class RecolectorSpeech: NSObject, ObservableObject {
    @Published var isSpeaking = false
    private let synth = AVSpeechSynthesizer()
    override init() { super.init(); synth.delegate = self }
    func read(_ material: NEXOMaterial) {
        stop()
        let text = "Material: \(material.displayName). Ruta: \(material.route.rawValue). "
                 + material.instructions.joined(separator: ". ") + ". Valor: \(material.value)."
        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: "es-MX"); utt.rate = 0.44
        synth.speak(utt); isSpeaking = true
    }
    func stop() { synth.stopSpeaking(at: .immediate); isSpeaking = false }
}
extension RecolectorSpeech: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = false }
    }
}
extension Array { subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil } }

#Preview("Recolector") {
    RecolectorView(listings: [], isLoading: false).environmentObject(ListingsRepository())
}
